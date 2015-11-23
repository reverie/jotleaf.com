from collections import namedtuple
from django.conf import settings
from django.contrib.auth import get_user_model
from main.models import TextItem, ImageItem, Page, Membership, Item, EmbedItem, Follow, RejectedFollowSuggestion

FullUser = namedtuple('FullUser', 
        ['user_object', 'ip_address', 'session_id', 'window_id', 'extra_page_permissions'])

readonly_fields = frozenset(['id'])
hidden_fields = frozenset(['updated_at', 'creator_session_id', 'creator_ip'])
only_admin_writable_item_fields = frozenset(['link_to_url'])

INTERNAL_USERNAME = '@internal'

User = get_user_model()

class Affiliation:
    OWNER = 1
    MEMBER = 3
    NONE = 5

def request_can_view(request, page):
    # hacky shim
    # This should be a function of the User. Anonymous pages
    # should just never be set to readability=PRIVATE.
    from main.api2 import _make_fulluser
    full_user = _make_fulluser(request)
    return can_view_page(full_user, page)

def can_view_page(full_user, page):
    if full_user.user_object.username == INTERNAL_USERNAME:
        return True
    if page.published:
        return True
    affiliation = get_page_affiliation(full_user,page)
    return affiliation in (Affiliation.MEMBER, Affiliation.OWNER)

def get_all_fields(model):
    # get_attname adds '_id' onto foreign keys
    return set([f.get_attname() for f in model._meta.fields])

def _get_related(instance, related_name, model):
    """
    Returns dicts of all `model` objects attached to `instance`
    via the `related_name` ORM relation.
    """
    from helpers import object_to_dict
    related_objects = getattr(instance, related_name).all()
    fields = get_model_default_readable_fields(model)
    return [object_to_dict(o, fields) for o in related_objects]

def get_textitems(page_instance):
    return _get_related(page_instance, 'textitem_set', TextItem)

def get_embeditems(page_instance):
    return _get_related(page_instance, 'embeditem_set', EmbedItem)

def get_imageitems(page_instance):
    return _get_related(page_instance, 'imageitem_set', ImageItem)

def get_memberships(page_instance):
    return _get_related(page_instance, 'membership_set', Membership)

def get_owner(page_instance):
    from helpers import object_to_dict
    owner = page_instance.owner
    if owner is None:
        return None
    fields = get_model_default_readable_fields(User)
    return object_to_dict(owner, fields)

# This used to do more. Maybe later it will call methods? <:)
get_field_value = getattr

def get_page_from_apidata(data):
    if 'page' in data:
        return Page.objects.get(pk=data['page'])
    elif 'page_id' in data:
        return Page.objects.get(pk=data['page_id'])
    else:
        return None

def can_create(model, full_user, data):
    if model == Page:
        return full_user.user_object.is_authenticated()
    elif model == TextItem:
        page = get_page_from_apidata(data)
        if not page:
            return False
        if not can_view_page(full_user, page):
            return False
        return page.text_writability >= get_page_affiliation(full_user, page)
    elif model in [ImageItem, EmbedItem] :
        # Image items are for owners and members
        page = get_page_from_apidata(data)
        if not page:
            return False
        return page.image_writability >= get_page_affiliation(full_user, page)
    elif model == Membership:
        page = get_page_from_apidata(data)
        if not page:
            return False
        return is_page_owner(full_user, page)
    elif model in [Follow, RejectedFollowSuggestion]:
        return full_user.user_object.id == data['user_id']
    else:
        raise ValueError("Unsupported model")

def get_page_affiliation(full_user, page):
    u = full_user.user_object
    if u == page.owner or page.id in full_user.extra_page_permissions:
        return Affiliation.OWNER
    if u.is_authenticated() and Membership.objects.filter(page=page, user=u).exists():
        return Affiliation.MEMBER
    return Affiliation.NONE

def is_page_owner(full_user, instance):
    # Should be called "is page owner" (or, "can admin")
    if instance.owner == full_user.user_object:
        return True
    if instance.id in full_user.extra_page_permissions:
        return True
    return False

def can_edit_item(full_user, instance):
    if instance.page.owner == full_user.user_object:
        return True
    if instance.creator == full_user.user_object:
        # assert b/c expecting user_object to be User or AnonUser:
        assert instance.creator
        return True
    if instance.creator_session_id:
        if instance.creator_session_id == full_user.session_id:
            return True
    return False

def _add_embedly_data(instance):
    import json
    from embedly import Embedly
    from main.api2 import APIException
    # for security, we can't let the client set embedly_data
    assert instance.original_url
    assert not instance.embedly_data
    client = Embedly(settings.EMBEDLY_KEY)
    obj = client.oembed(instance.original_url, 
        autoplay=False,
        maxwidth=600,
        # Fix overlay issues with flash under chrome/linux:
        wmode='transparent'
    )
    if obj.invalid:
        raise APIException('The submitted link is invalid')
    elif obj.type is 'error':
        raise APIException('Embedly error', obj.error_code)
    elif not obj.html:
        raise APIException('No embed html received')
    else:
        assert obj.provider_name.lower() in settings.ALLOWED_EMBEDLY_PROVIDERS
        instance.width = obj.width
        instance.height = obj.height
        instance.embedly_data = json.dumps(dict(obj))

def add_custom_create_data(model, full_user, data, instance):
    is_item = issubclass(model, Item)
    if is_item:
        if full_user.user_object.is_authenticated():
            instance.creator = full_user.user_object
        instance.creator_window_id = full_user.window_id
    if is_item or (model == Page):
        instance.creator_ip = full_user.ip_address
        instance.creator_session_id = full_user.session_id
    if model == EmbedItem:
        _add_embedly_data(instance)

def post_create_response_fields(model):
    fields = ['id']
    if issubclass(model, Item):
        fields.append('creator_window_id')
    if model == EmbedItem:
        fields.extend(['height', 'width', 'embedly_data'])
    return fields

def model_readonly_fields(model):
    if issubclass(model, Item):
        return frozenset(['behavior', 'inputs', 'creator_id', 'creator', 'creator_window_id', 'embedly_data'])
    elif model == Page:
        return frozenset(['published_at'])  
    elif model == User:
        return frozenset(['username', 'email'])
    return frozenset()

def model_writeonce_fields(model):
    if model in (TextItem, ImageItem, EmbedItem):
        return frozenset(['page', 'page_id'])
    return frozenset()

def get_model_default_readable_fields(model):
    """
    The set of fields on this model that anyone can read,
    i.e. doesn't depend on the user.
    """
    if model == User:
        return set(['id', 'username', 'bio'])
    fields = get_all_fields(model)
    fields -= hidden_fields
    return fields

def validate_field(model, field_name, field_val):
    if model == Page and field_name == 'bg_texture':
        if '/' not in field_val:
            return True
        return field_val.startswith('https://www.filepicker.io/api/file/')
    return True

def can_delete(model, full_user, instance):
    if model in (TextItem, ImageItem, EmbedItem):
        return can_edit_item(full_user, instance)
    elif model == Page:
        return is_page_owner(full_user, instance)
    elif model == Membership:
        return is_page_owner(full_user, instance.page)
    elif model == Follow:
        return full_user.user_object == instance.user
    return False

# get_*_fields methods return None if the operation
# is not permitted, or else the subset of field names
# which should be applied. Only called by top-level
# API entry points.

def get_readable_fields(model, full_user, instance):
    default = get_model_default_readable_fields(model)
    if model == Page:
        if not can_view_page(full_user, instance):
            return None
        return default
    elif model in (Membership, Follow):
        # Everyone can see these
        return default
    elif issubclass(model, Item):
        if not can_view_page(full_user, instance.page):
            return None
        return default
    elif model == User:
        if full_user.user_object == instance:
            return default.union(set(['email_on_new_follower', 'email_on_new_membership', 'email', 'wants_tutorial']))
        else:
            return default

def get_createable_fields(model, full_user, data):
    if not can_create(model, full_user, data):
        return None
    fields = get_all_fields(model)
    fields -= readonly_fields
    fields -= model_readonly_fields(model)
    fields -= hidden_fields
    if issubclass(model, Item):
        page = get_page_from_apidata(data)
        affil = get_page_affiliation(full_user, page)
        if affil != Affiliation.OWNER:
            fields -= only_admin_writable_item_fields
    return fields

def get_updateable_fields(model, full_user, instance):
    if model == Page:
        if not is_page_owner(full_user, instance):
            return None
    elif model in (TextItem, ImageItem, EmbedItem):
        if not can_edit_item(full_user, instance):
            return None
    elif model == User:
        if full_user.user_object != instance:
            return None
    else:
        raise ValueError("Unsupported model")
    fields = get_all_fields(model)
    fields -= readonly_fields
    fields -= model_writeonce_fields(model)
    fields -= model_readonly_fields(model)
    fields -= hidden_fields
    if issubclass(model, Item):
        page = instance.page
        affil = get_page_affiliation(full_user, page)
        if affil != Affiliation.OWNER:
            fields -= only_admin_writable_item_fields
    return fields

def is_allowed_search(model, field_name, match_type):
    # rename to can_search?
    if model == User:
        return field_name == 'username' and match_type == 'iexact'
    elif model == Membership:
        return field_name == 'page_id' and match_type == 'exact'

def can_execute_method(model, full_user, instance, method_name):
    if not is_page_owner(full_user, instance):
        return False
    return (model, method_name) == (Page, 'clear')

def final_data_validation(model, instance):
    if model == Follow:
        assert instance.user_id != instance.target_id

