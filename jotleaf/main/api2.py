import json
from functools import partial

from django.contrib.auth import get_user_model
from django.core.serializers.json import DjangoJSONEncoder
from django.http import HttpResponse
from django.db.models import Model
from django.shortcuts import get_object_or_404

from common.shortcuts import dict_subset
from common.views import response_403, DateJSONEncoder
from main import permissions
from main import pusher_helpers
from main.helpers import simple_read, object_to_dict
from main.models import Page, TextItem, Membership, ImageItem, EmbedItem, Item, Follow, RejectedFollowSuggestion
from main.views import other_user_to_js
from main.newsfeed import _instance_to_news

_registry = {}

HttpJsonResponse = partial(HttpResponse, mimetype='application/json')

User = get_user_model()

def add_model(model):
    name = model.__name__.lower()
    assert name not in _registry
    _registry[name] = model

def add_models(*models):
    for m in models:
        add_model(m)

class APIException(Exception):
    def __init__(self, msg, errors=None):
        Exception.__init__(self, msg)
        self.errors = errors

class APIEncoder(DateJSONEncoder):
    def default(self, o):
        from django.db.models.query import QuerySet
        if isinstance(o, Model):
            return o.id
        if isinstance(o, QuerySet):
            return list(o)
        return super(APIEncoder, self).default(o)

def serialize_object(obj, field_names):
    dct = object_to_dict(obj, field_names)
    return json.dumps(dct, cls=APIEncoder)

def create(model, full_user, data):
    createable_fields = permissions.get_createable_fields(model, full_user, data)
    if createable_fields is None:
        return (response_403(), None)
    filtered_data = dict_subset(data, createable_fields)
    m = model(**filtered_data)
    permissions.final_data_validation(model, m)
    try:
        permissions.add_custom_create_data(model, full_user, data, m)
    except APIException as e:
        response = HttpJsonResponse(serialize_object(e, ('errors', 'message')), status=500)
        return (response, None)

    m.save()
    # Send back `id` so client knows it
    fields = permissions.post_create_response_fields(model)
    response = HttpJsonResponse(serialize_object(m, fields))
    return (response, m)

def read(model, full_user, instance):
    fields = permissions.get_readable_fields(model, full_user, instance)
    if fields is None:
        return (response_403(), None)
    return (HttpJsonResponse(serialize_object(instance, fields)), None)

def update(model, full_user, instance, data):
    updateable_fields = permissions.get_updateable_fields(model, full_user, instance)
    if updateable_fields is None:
        return (response_403(), None)
    filtered_data = dict_subset(data, updateable_fields)
    for f_name, f_val in filtered_data.items():
        assert permissions.validate_field(model, f_name, f_val)
        setattr(instance, f_name, f_val)
    instance.save()
    return (HttpResponse(''), instance)

def delete(model, full_user, instance):
    if not permissions.can_delete(model, full_user, instance):
        return (response_403(), None)
    instance.delete()
    return (HttpResponse(''), instance)

def get_resource_model(resource_name):
    return _registry[resource_name]

def _get_extra_page_permissions(request):
    """
    Returns a list of Page-IDs that this user has authority
    to edit based on claim-<page-id> cookies set by going
    to jotleaf.com/new while unauthenticated.
    """
    from main import claiming
    return claiming.get_request_claimable_page_ids(request)

def make_internal_signature(data):
    from hashlib import sha1
    from django.conf import settings
    return sha1(data + settings.SECRET_KEY).hexdigest()

def within_five_minutes(d1, d2):
    from common.views import convert_to_utc
    d1 = convert_to_utc(d1)
    d2 = convert_to_utc(d2)
    if d1 > d2:
        diff = d1 - d2
    else:
        diff = d2 - d1
    return (diff.days == 0) and (diff.seconds < 5*60)

def _make_fulluser(request, meta_data={}):
    import dateutil.parser
    from common.shortcuts import utc_now
    from main.permissions import FullUser, INTERNAL_USERNAME
    user_agent = request.META.get('HTTP_USER_AGENT', '')
    if user_agent.startswith('Jotleaf-Internal'):
        _, timestamp, signature = user_agent.split('|')
        dt = dateutil.parser.parse(timestamp)
        sig_is_recent = within_five_minutes(dt, utc_now())
        sig_matches = (signature == make_internal_signature(timestamp))
        if sig_is_recent and sig_matches:
            request.user = User.objects.get_or_create(username=INTERNAL_USERNAME)[0]
    return FullUser(
        request.user, 
        request.META['REMOTE_ADDR'], 
        request.session.session_key,
        meta_data.get('window_id'),
        _get_extra_page_permissions(request)
    )

def dispatch(request, resource_name, pk=None):
    # Set up -- pick method, get common arguments
    method = {
        'POST': create,
        'GET': read,
        'PUT': update,
        'PATCH': update,
        'DELETE': delete
    }[request.method]
    if method == read:
        data = {}
    else:
        data = json.loads(request.body)
    model_data = data.get('model')
    # All methods with side-effects should
    # include request.body with 'meta' field.
    meta_data = data.get('meta', {})
    model = get_resource_model(resource_name)
    full_user = _make_fulluser(request, meta_data)
    args = [model, full_user]

    was_published = False
    deleted_id = None

    # Everything but 'create' acts on an instance
    if method != create:
        instance = get_object_or_404(model, pk=pk)
         # Need to detect published trigger    
        if isinstance(instance, Page):
            was_published = instance.published
        args.append(instance)
    else:
        assert pk is None

    # Read & pass model data for 'create' and 'update'
    if method in [create, update]:
        args.append(model_data)
    else:
        assert not model_data

    # Keep the id in case of deletion
    if method == delete:
        deleted_id = instance.id

    # Perform action, get result, and maybe send to pusher
    (http_response, instance) = method(*args)
    if method == read:
        # no Pusher update on GET, or error responses
        return http_response
    if http_response.status_code != 200:
        # The method errored -- don't send an update
        return http_response
   
    if model in (TextItem, ImageItem, EmbedItem, Follow, Membership):
        send_newsfeed_activity(instance, deleted_id)
    elif model == Page and instance.owner:
        if not was_published and instance.published:
            send_newsfeed_activity(instance, deleted_id)
        elif was_published and not instance.published:
            send_newsfeed_activity(instance, instance.id)

    if not isinstance(instance, Item):
        if isinstance(instance, Page):
            if method == delete:
                send_page_deletion(deleted_id)
            elif method == update:
                send_page_update(instance, meta_data.get('socket_id'))
        return http_response

    # Ok, we're doing a Pusher update
    if method == delete:
        send_item_deletion(instance, deleted_id)
    elif method == create:
        send_item_creation(instance, meta_data.get('socket_id'), full_user)
    else:
        assert method == update
        send_item_update(instance, meta_data.get('socket_id'), full_user)

    # Pusher update sent. Return response to this client.
    return http_response

def send_item_deletion(item, deleted_item_id):
    """Send item deletion notification through Pusher."""
    pusher_event = 'item-delete'
    dct = {'id': deleted_item_id, 'type': item.SHORTNAME}
    pusher_helpers.try_pusher_page_send(item.page_id, pusher_event, dct)

def send_batch_item_deletion(page, item_ghosts):
    """
    Send batch item deletion notification through Pusher.
    itemGhosts are dictionaries containing deleted item ids and item types
    """
    pusher_event = 'multi-event'
    multi_event_data = []
    for item_ghost in item_ghosts:
        dct = {'id': item_ghost['original_id'], 'type': item_ghost['type']}
        multi_event_data.append({'type': 'item-delete', 'data': dct})
    pusher_helpers.try_pusher_page_send(page.id, pusher_event, multi_event_data)

def get_user_identifier(full_user, pageId):
    from hashlib import md5
    if full_user.user_object.is_authenticated():
        user_id = md5(str(full_user.user_object.id)+pageId).hexdigest()
    elif full_user.session_id:
        user_id = md5(full_user.session_id).hexdigest()
    else:
        window_id = full_user.window_id or ''
        user_id = md5(window_id).hexdigest()
    return user_id   


def send_item_create_or_update(item, event_name, socket_id, full_user):
    """Send item create/update notification through Pusher."""

    model = item.__class__
    pusher_fields = permissions.get_model_default_readable_fields(model)
    modelDct = object_to_dict(item, pusher_fields)

    dct = {}
    # Client JS needs 'type' field
    dct['type'] = item.SHORTNAME
    
    # Lets keep a copy of the id at top level
    dct['id'] = item.id
    dct['creator_identifier'] = get_user_identifier(full_user, item.page_id) 
    if item.creator_id:
        creator = User.objects.get(id=item.creator_id)
        dct['creator_username'] = creator.username
    else:
        dct['creator_username'] = None 

    dct['model_data'] = modelDct
    pusher_helpers.try_pusher_page_send(
        item.page_id, event_name, dct, socket_id)

def send_item_creation(item, socket_id, full_user):
    send_item_create_or_update(item, 'item-add', socket_id, full_user)

def send_item_update(item, socket_id, full_user):
    send_item_create_or_update(item, 'item-update', socket_id, full_user)

def send_page_update(page, socket_id):
    """Send page create/update notification through Pusher."""
    model = page.__class__
    pusher_fields = permissions.get_model_default_readable_fields(model)
    dct = object_to_dict(page, pusher_fields)

    pusher_helpers.try_pusher_page_send(
        page.id, 'page-update', dct, socket_id)

def send_page_deletion(deleted_page_id):
    """Send page deletion notification through Pusher."""
    pusher_event = 'page-delete'
    dct = {'id': deleted_page_id}
    pusher_helpers.try_pusher_page_send(deleted_page_id, pusher_event, dct)

def _get_users_to_inform(activity):
    users_to_inform = []

    if isinstance(activity, Follow):
        users_to_inform.append(activity.target.id)
    elif isinstance(activity, Membership):
        users_to_inform.append(activity.user.id)
    elif isinstance(activity, Page):
        followers = User.objects.filter(friends__target=activity.owner)
        users_to_inform.extend([follower.id for follower in followers])
    elif isinstance(activity, Item):
        page = activity.page
        owner_id = None
        # page owner
        if page.owner:
            owner_id = page.owner.id
            users_to_inform.append(owner_id)
        
        # all members of page
        members = User.objects.filter(membership__page=page)
        users_to_inform.extend([member.id for member in members])

        item_creator = activity.creator
        # all followers of creator if item on a published page not owned by creator
        if item_creator and page.published:
            if owner_id != item_creator.id:
                followers = User.objects.filter(friends__target=item_creator)
                users_to_inform.extend([follower.id for follower in followers])

    return users_to_inform


def send_newsfeed_activity(activity, deleted_id):
    """ Convert the instance to a news feed listing and propagate to 
    interested users' newsfeeds"""

    news_dct = _instance_to_news(activity)
    
    activity_type = news_dct['type']
    if deleted_id:
        activity_type = 'delete'
        news_dct['data']['id'] = deleted_id

    event_type = "nf-{}".format(activity_type)
    
    users_to_inform = _get_users_to_inform(activity)
    pusher_helpers.try_pusher_user_send(users_to_inform, event_type, news_dct)

def api_search(request, resource_name):
    if request.method != 'POST':
        return response_403()
        
    # Setup
    model = get_resource_model(resource_name)
    data = json.loads(request.body)
    search_params = data['search_params']
    #meta_data = data.get('meta', {})
    #full_user = _make_fulluser(request, meta_data)

    # Validate search params
    # search_params must be a list of [field_name, match_type, value] tuples.
    # for example, 'username', 'iexact', 'bobRoss'
    for field_name, match_type, value in search_params:
        if not permissions.is_allowed_search(model, field_name, match_type):
            return response_403()

    # Execute search 
    kwargs = {field_name + '__' + match_type: value
            for field_name, match_type, value in search_params}
    qs = model.objects.filter(**kwargs)

    # Build and return result
    fields = permissions.get_model_default_readable_fields(model)
    result_data = [object_to_dict(m, fields) for m in qs]
    return HttpJsonResponse(json.dumps(result_data, cls=APIEncoder))

def instance_method(request, resource_name, pk, method_name):
    assert request.method == 'POST'
    data = json.loads(request.body)
    meta_data = data.get('meta', {})
    model = get_resource_model(resource_name)
    full_user = _make_fulluser(request, meta_data)
    instance = get_object_or_404(model, pk=pk)
    if not permissions.can_execute_method(model, full_user, instance, method_name):
        return response_403()
    result = getattr(instance, method_name)()
    return HttpJsonResponse(json.dumps(result, cls=APIEncoder))
    
# Register models in API
add_models(Page, TextItem, Membership, ImageItem, EmbedItem, Follow, RejectedFollowSuggestion)
_registry['user'] = User
