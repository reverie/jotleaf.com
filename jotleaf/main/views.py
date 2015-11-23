import functools
import json

from django.conf import settings

from django.contrib.auth.decorators import login_required
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import AuthenticationForm, PasswordResetForm, SetPasswordForm
from django.contrib.auth.tokens import default_token_generator
from django.core.urlresolvers import reverse
from django.http import HttpResponseRedirect, Http404, HttpResponse
from django.shortcuts import get_object_or_404
from django.views.decorators.csrf import csrf_exempt

from common.shortcuts import time_ago
from common.views import req_render_to_response, json as json_view
from main.models import Page, PageView, TextItem, ImageItem, EmbedItem, Item, Membership, Follow, CustomUser as User

@json_view
def login(request, authentication_form=AuthenticationForm):
    """
    AJAX login authentication
    """
    if request.method == 'GET':
        return _new_api_403()
        
    from django.contrib.auth import login as auth_login

    form = authentication_form(data=request.POST)
    if form.is_valid():
        user = form.get_user()
        auth_login(request, user)
        return {
            'authenticated':True, 
            'user': your_user_to_js(user),
            'follows': follows_to_js(user),
        }
    else:
        response_data = {
            'authenticated': False,
            'errors': form.errors
        }
        return response_data



@json_view
def register(request):
    """
    AJAX user registration
    """
    from registration_backend.backend import JotleafBackend
    backend = JotleafBackend()
    if request.method == 'GET':
        return _new_api_403()
    data = request.POST.copy()
    if not backend.registration_allowed(request):
        return {
            'registration_successful': False, 
            'errors': {
                '__all__': "Registration not allowed."
            }, 
        }
    form_class = backend.get_form_class(request)
    form = form_class(data=data)
    if not form.is_valid():
        return {
            'registration_successful': False, 
            'errors': form.errors, 
        }
    new_user = backend.register(request, **form.cleaned_data)
    return {
        'registration_successful': True, 
        'errors': None, 
        'user': your_user_to_js(new_user),
        'follows': []
    }

@json_view
def logout(request):
    """
    Logs out the user and displays 'You are logged out' message.
    """
    if request.method == 'GET':
        return _new_api_403()
    from django.contrib.auth import logout as auth_logout
    auth_logout(request)

@json_view
def password_reset(request, 
                   template_name='registration/password_reset_form.html',
                   email_template_name='registration/password_reset_email.html',
                   subject_template_name='registration/password_reset_subject.txt',
                   password_reset_form=PasswordResetForm,
                   token_generator=default_token_generator):
    if request.method == 'GET':
        return _new_api_403()   

    form = password_reset_form(request.POST)

    responseData = {}
    if form.is_valid():
        opts = {
            'use_https': request.is_secure(),
            'token_generator': token_generator,
            'from_email': None,
            'email_template_name': email_template_name,
            'subject_template_name': subject_template_name,
            'request': request,
        }
        form.save(**opts)
        responseData['success'] = True
    else:
        responseData['success'] = False
        responseData['data'] = form.errors

    return responseData

@json_view
def password_reset_confirm(request, uidb36=None, token=None,
                           token_generator=default_token_generator,
                           set_password_form=SetPasswordForm,
                           current_app=None, extra_context=None):
    """
    View that checks the hash in a password reset link and presents a
    form for entering a new password.
    """

    if request.method == 'GET':
        return _new_api_403()
    assert uidb36 is not None and token is not None # checked by URLconf
   
    responseData = {}
    responseData['success'] = False
    from django.utils.http import base36_to_int
    try:
        uid_int = base36_to_int(uidb36)
        user = get_user_model().objects.get(id=uid_int)
    except (ValueError, get_user_model().DoesNotExist):
        user = None
        responseData['data'] = { '__all__': "User does not exist!"}

    if user is not None and token_generator.check_token(user, token):
        form = set_password_form(user, request.POST)
        if form.is_valid():
            form.save()
            responseData['success'] = True
        else:
            responseData['data'] = form.errors
    else:
        responseData['data'] = { '__all__': "This generated link is not valid!"}

    return responseData

def spa_base(request, *args, **kwargs):
    return req_render_to_response(request, 'spa_base.html')

spa_base2 = spa_base # todo: kill

def _base_make_page(page_kwargs):
    # all page creation should finally go through here
    from main.screenshots import enqueue_page_screenshot_request
    page = Page.objects.create(**page_kwargs)
    enqueue_page_screenshot_request(page)
    return page

def _make_page(request, title):
    page_kwargs = {
        'owner': request.user,
        'title': title,
        'short_url': Page.get_available_short_url(request.user, title)
    }
    return _base_make_page(page_kwargs)

def _make_quick_page(request):
    page_kwargs = {
        'title': 'Quick Page',
        'creator_session_id': request.session.session_key,
        'creator_ip': request.META['REMOTE_ADDR']
    }
    if request.user.is_authenticated():
        page_kwargs['owner'] = request.user
    return _base_make_page(page_kwargs)

@json_view
def new_page(request):
    from main.models import TITLE_MAX_LENGTH
    # todo: error msg on title length instead?
    title = request.POST['title'][:TITLE_MAX_LENGTH]
    if request.user.is_authenticated():
        page = _make_page(request, title)
        return _new_api_success({
            'id': page.id,
            'title': page.title,
            'short_url': page.short_url,
            'get_absolute_url': page.get_absolute_url(),
            })
    else:
        return  _new_api_403()

def _lastinserted_to_js(item):
    if item is None:
        return
    return {
        'creator_id': item.creator_id,
        'get_absolute_url': item.get_absolute_url(),
        'content': item.content,
        'updated_at': item.updated_at,
    }

def _base_page_to_dict(page):
    return {
        'id': page.id,
        'title': page.title,
        'short_url': page.short_url,
        'get_absolute_url': page.get_absolute_url(),
        # todo: something more efficient than all these last_inserted calls
        'last_inserted': _lastinserted_to_js(page.last_inserted()),
    }

def pages_to_full_dicts(pages, include_private_screenshots=False):
    """Given Page objects, returns dicts with everything the client needs."""
    from main.pageviews import get_counts
    from main.screenshots import get_latest_screenshots
    page_dicts = map(_base_page_to_dict, pages)
    counts = get_counts(pages)
    for dct, count in zip(page_dicts, counts):
        dct['view_count'] = count
    screenshots = get_latest_screenshots(pages, include_private=include_private_screenshots)
    for page, dct, screen in zip(pages, page_dicts, screenshots):
        dct['screenshot'] = screen
    return page_dicts

@json_view
def my_pages(request):
    if request.user.is_authenticated():
        pages = request.user.page_set.all()
        pages = pages_to_full_dicts(pages, include_private_screenshots=True)
        return _new_api_success(pages)
    else:
        return _new_api_403()


def other_user_to_js(u):
    return {attr: getattr(u, attr, None)
        for attr in ['id', 'username', 'bio']}

def your_user_to_js(u):
    # Use *only* for the authenticated user!
    # TODO: DRY with permissions.py
    return {attr: getattr(u, attr, None)
        for attr in ['id', 'username', 'bio', 'email', 'email_on_new_follower', 'email_on_new_membership', 'wants_tutorial']}

def follows_to_js(user):
    if not user.is_authenticated():
        return []
    follows = user.friends.all()
    return [{
        'id': f.id,
        'user_id': f.user_id,
        'target_id': f.target_id,
    } for f in follows]

def _new_api_err(code):
    return {
        'success': False,
        'data': None,   
        'status_code': code,
    }

def _new_api_success(data):
    return {
        'success': True,
        'data': data,
        'status_code': 200,
    }

_new_api_403 = functools.partial(_new_api_err, 403)
_new_api_404 = functools.partial(_new_api_err, 404)
_new_api_500 = functools.partial(_new_api_err, 500)

def _get_page_by_identifier(username, page_identifier):
    u = get_object_or_404(get_user_model(), username__iexact=username)
    try:
       return Page.objects.get(owner=u, id=page_identifier)
    except Page.DoesNotExist:
        return get_object_or_404(Page, owner=u, short_url__iexact=page_identifier)

@json_view
def xhr_get_page(request):
    # NB for now we are tracking the PageView here, but when the client starts
    # using cached Page objects, we need to find another way to make sure
    # they get created.

    if request.method != 'POST':
        return _new_api_403()
    from main import permissions, pageviews
    from main.api2 import APIEncoder
    from main.helpers import simple_read
    if 'page_id' in request.POST:
        page_id = request.POST['page_id']
        try:
            page = Page.objects.get(id=page_id)
        except Page.DoesNotExist:
            return _new_api_404()
    else:
        username = request.POST['username']
        page_identifier = request.POST['page_identifier']
        try:
            page = _get_page_by_identifier(username, page_identifier)
        except Http404:
            return _new_api_404()
    if not permissions.request_can_view(request, page):
        return _new_api_403()
    PageView.objects.create(
        user = request.user if request.user.is_authenticated() else None,
        page = page,
        ip_address = request.META['REMOTE_ADDR'],
        sessionid = request.session.session_key,
    )
    pageviews.increment_count(page)
    response = {
        'page': simple_read(page),
        'textitems': permissions.get_textitems(page),
        'imageitems': permissions.get_imageitems(page),
        'embeditems': permissions.get_embeditems(page),
        'memberships': permissions.get_memberships(page),
        'owner': permissions.get_owner(page),
    }
    # fixme: 
    response = json.loads(json.dumps(response, cls=APIEncoder))
    return _new_api_success(response)

@json_view
def xhr_get_suggested_follows(request):
    if not request.user.is_authenticated():
        return _new_api_403()
    else:
        user = request.user
        suggested_users_to_follow = get_suggested_users_to_follow(user)
        return _new_api_success(suggested_users_to_follow)

def get_suggested_users_to_follow(user):
    """ 
    Dynamically retrieve all the users that this user should follow, based on:
    1. Users whose pages user has written on
    2. Users who have written on user's pages
    3. Users who follow user
    4. Static list of users to follow
    Minus
    1. Users user is already following
    2. Users who have been explicitly rejected by user
    """
    from django.db.models import Q
    from itertools import chain

    users_who_wrote_on_my_pages = User.objects.filter(Q(textitem__page__owner=user)).distinct()
    users_who_pages_i_wrote_on = User.objects.filter(Q(page__textitem__creator=user)).distinct()
    users_follow_me = User.objects.filter(Q(friends__target=user)).distinct()
    suggested_users = User.objects.filter(Q(username__in=settings.SUGGESTED_USERS)).distinct()

    users_to_follow = set(
        chain(
            users_who_wrote_on_my_pages, 
            users_who_pages_i_wrote_on, 
            users_follow_me, 
            suggested_users
        )
    )

    users_not_to_follow = set(User.objects.filter(
        Q(id=user.id) |
        Q(rejected__user=user) |
        Q(followers__user=user)
    ))

    users_to_follow -= users_not_to_follow

    return [other_user_to_js(user) for user in users_to_follow][0:8]




@json_view
def xhr_get_newsfeed(request):
    if not request.user.is_authenticated():
        return _new_api_403()
    else:
        from main.newsfeed import get_newsfeed_for_user
        user = request.user
        headline_news = get_newsfeed_for_user(user)
        return _new_api_success(headline_news)

def _do_login_as(request, as_username):
    from django.contrib.auth import load_backend
    from django.contrib.auth import login as django_login
    user = get_user_model().objects.get(username__iexact=as_username)
    if not hasattr(user, 'backend'):
        for backend in settings.AUTHENTICATION_BACKENDS:
            if user == load_backend(backend).get_user(user.pk):
                user.backend = backend
                break
    assert hasattr(user, 'backend')
    django_login(request, user)

def login_as(request, as_username):
      """
      Sign in a user without requiring credentials (using ``login`` from
      ``django.contrib.auth``, first finding a matching backend).

      From http://www.djangosnippets.org/snippets/1547/
      """ 
      if not request.user.is_superuser:
          return HttpResponseRedirect(reverse('auth_login'))
      _do_login_as(request, as_username)
      return HttpResponseRedirect('/')


def xhr_quick_page(request):
    from common.views import json_response
    from main import claiming
    page = _make_quick_page(request)
    response = json_response(_new_api_success({"pageUrl": page.get_absolute_url()}))
    if not request.user.is_authenticated():
        claim_id = claiming.make_claim_id(page)
        response.set_signed_cookie(claim_id, '1')
    return response


@json_view
def xhr_user_pages(request):
    """
    All the published pages owned by request.POST['user_id'].
    """
    user_id = request.POST['user_id']
    user = get_object_or_404(get_user_model(), id=user_id)
    listed_pages = user.listed_pages()
    return pages_to_full_dicts(listed_pages)

@json_view
def xhr_claim_yes(request):
    from main import claiming
    page_id = request.POST['page_id']
    if not claiming.has_permission(request, page_id):
        return {
            'success': False,
            'msg': "You don't have access to that page anymore."
        }
    try:
        p = Page.objects.get(id=page_id)
    except Page.DoesNotExist:
        return {
            'success': False,
            'msg': "That page has been deleted."
        }
    if not request.user.is_authenticated():
        return {
            'success': False,
            'new_auth_state': None,
            'msg': "You must login to claim that page.",
        }
    p.owner = request.user
    p.save()
    return {
        'success': True,
        'msg': "Page added to your account.",
    }

def xhr_claim_no(request):
    from main import claiming
    from common.views import json_response
    page_id = request.POST['page_id']
    response = json_response({'success': True})
    response.delete_cookie(claiming.make_claim_id_from_page_id(page_id))
    return response

def get_user_presence_id(request, page):    
    from hashlib import md5
    if request.user.is_authenticated():
        user_id = md5(str(request.user.id)+str(page.id)).hexdigest()
    elif request.session.session_key:
        user_id = md5(request.session.session_key).hexdigest()
    else:
        socket_id = request.POST['socket_id']
        user_id = md5(socket_id).hexdigest()
    return user_id   

@csrf_exempt
def pusher_auth(request):
    from common.views import response_403, json_response
    from main import permissions
    from main import pusher_helpers
    channel_name = request.POST['channel_name']
    tokens = pusher_helpers.parse_channel_name(channel_name)
    if len(tokens) < 3:
        return response_403()
    channel_type, channel_model, model_id = tokens
    socket_id = request.POST['socket_id']
    args = None
    if channel_model == 'page':
        page = get_object_or_404(Page, id=model_id)
        if not permissions.request_can_view(request, page):
            return response_403()
        if channel_type == 'presence':
            user_id = get_user_presence_id(request, page)
            args = dict(user_id=user_id)
    elif channel_model == 'user':
        user_id = int(model_id)
        user = request.user
        if not (user.is_authenticated() and user.id == user_id):
            return response_403()    
    token = pusher_helpers.make_permission(channel_name, socket_id, args)
    return json_response(token)

def config_js(request):
    js = json.dumps({
        'PUSHER_KEY': settings.PUSHER_KEY,
        'STATIC_URL': settings.STATIC_URL,
        'FILEPICKER_KEY': settings.FILEPICKER_KEY,
        'USER': your_user_to_js(request.user),
        'FOLLOWS': follows_to_js(request.user),
    })
    return HttpResponse("window.JL_CONFIG=" + js + ";",
            mimetype="text/javascript")

@json_view
def autocomplete_username(request):
    term = request.GET['term']
    # TODO: add a SQL index for this:
    users = (get_user_model().objects
        .filter(username__istartswith=term)
        .extra(select={'lower_name': 'lower(username)'})
        .order_by('lower_name'))[:10]
    return [dict(id=u.id, name=u.username) for u in users]

@login_required
def stats(request):
    from marketing.helpers import get_top_pages
    if not request.user.is_superuser:
        raise Http404
    one_week_ago = time_ago(days=7)
    most_viewed = get_top_pages(one_week_ago)
    lines = ['Most Viewed Pages Since %s' % one_week_ago]
    for dct in most_viewed:
        page = Page.objects.get(id=dct['page'])
        if page.owner_id:
            owner_email = page.owner.email
        else:
            owner_email = None
        lines.append("%d\t%s\t%s\t%s" % (dct['pcount'], owner_email, page.get_absolute_url(), page.title))
    return HttpResponse('\n'.join(lines), content_type="text/plain")

@json_view
def get_claims(request):
    from main.templatetags.main_tags import get_claimable_pages
    pages = get_claimable_pages(request)
    result = []
    for p in pages:
        result.append({
            'id': p.id,
            'get_absolute_url': p.get_absolute_url(),
            'title': p.title,
        })
    return result

def preview_email(request, email_name):
    from main.emails import preview_email
    return HttpResponse(preview_email(email_name))


@json_view
def unsubscribe(request):
    from django.core.signing import Signer
    from urllib2 import unquote
    token = unquote(request.POST['token'])
    signer = Signer()
    action = signer.unsign(token)
    uid, _, _, _ = action.split('|')
    u = User.objects.get(id=uid)
    email_type = request.POST['emailType']
    if email_type == 'follow':
        u.email_on_new_follower = False
    elif email_type == 'member':
        u.email_on_new_membership = False
    else:
        raise ValueError("Unknown unsubscribe email type %s" % email_type)
    u.save()
    return True


@json_view
def get_follows(request):
    from main.api2 import simple_read
    user_id = request.POST['user_id']
    follows = (Follow.objects.filter(user=user_id) | Follow.objects.filter(target=user_id)).select_related()
    users = set()
    for f in follows:
        users.add(f.user)
        users.add(f.target)
    models = {}
    models['follow'] = map(simple_read, follows)
    models['user'] = [simple_read(u) for u in users]
    return models
