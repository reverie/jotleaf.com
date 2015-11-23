from django.conf.urls import patterns, include, url
from django.contrib import admin
from django.http import HttpResponseRedirect

from root_dir import root_dir

from main.forms import CustomAuthForm

def redirect(url):
    return lambda *args, **kwargs: HttpResponseRedirect(url)

SLUG_REGEX = r'[-a-zA-Z0-9_]+' # Copied from django.core.validators

admin.autodiscover()

urlpatterns = patterns('main.views',
    # Accounts
    url(r'^account/settings/$', 'spa_base', name='settings'),
    url(r'^account/settings/(.*)/$', 'spa_base'),

    url(r'^account/login_as/(.*)/$', 'login_as', name='login_as'),
    url(r'^account/login/$', 'spa_base', name='auth_login'),
    url(r'^account/logout/$', redirect('/')),
    url(r'^account/password/reset/$', 'spa_base', name='pwd_reset'),
    url(r'^account/password/reset/confirm/(?P<uidb36>[0-9A-Za-z]+)-(?P<token>.+)/$','spa_base', 
        name='pwd_reset_confirm'),
    url(r'^account/register/$', 'spa_base', name='registration_register'),

    (r'^account/', include('registration_backend.urls')),

    # Admin URLs
    (r'^admin-sostegno/stats/', 'stats'),
    (r'^admin-sostegno/preview-email/(.+)/', 'preview_email'),
    (r'^admin-sostegno/', include(admin.site.urls)),

    # Main website:
    url(r'^$', 'spa_base', name="index"),
    url(r'^new$', 'spa_base', name='quick_page'),
    url(r'^new/$', 'spa_base'),
    url(r'^home/$', 'spa_base', name='home'),
    url(r'^pages/$', 'spa_base', name='pages'),
    url(r'^500error-test/$', lambda request: None),

    # Misc website AJAX    
    url(r'^xhr/account/login/$', 'login', name='xhr_auth_login', 
        kwargs={'authentication_form':CustomAuthForm}),
    url(r'^xhr/account/register/$', 'register', name='xhr_registration'),
    (r'^xhr/get-page/$', 'xhr_get_page'), 
    (r'^xhr/get-user-pages/$', 'xhr_user_pages'), 
    url(r'^xhr/account/logout/$', 'logout', name='xhr_auth_logout'),
    url(r'^xhr/account/password/reset/confirm/(?P<uidb36>[0-9A-Za-z]+)-(?P<token>.+)/$','password_reset_confirm', 
        name='xhr_auth_password_reset_confirm'),
    url(r'^xhr/account/password/reset/$', 'password_reset', name='xhr_auth_password_reset'),
    url(r'^xhr/my-pages/$', 'my_pages'),
    url(r'^xhr/news-feed/$', 'xhr_get_newsfeed'),
    url(r'^xhr/claim-yes/$', 'xhr_claim_yes'),
    url(r'^xhr/claim-no/$', 'xhr_claim_no'),
    url(r'^xhr/get-claims/$', 'get_claims'),
    url(r'^xhr/new-page/$', 'new_page'),
    url(r'^xhr/quick-page/$', 'xhr_quick_page'),
    url(r'^xhr/autocomplete_username/$', 'autocomplete_username', name="autocomplete_username"),
    url(r'^xhr/unsubscribe/$', 'unsubscribe'),
    url(r'^xhr/get-follows/$', 'get_follows'),
    url(r'^xhr/get-suggested-follows/$', 'xhr_get_suggested_follows'),

    # Rendered "static" files
    url(r'^rendered/config\.js$', 'config_js'),

    # External hooks
    url(r'^pusher/auth$', 'pusher_auth'),
)

# New API
urlpatterns += patterns('main.api2',
    url(r'^api/v2/(?P<resource_name>[\w]+)/$', 'dispatch'),

    url(r'^api/v2/(?P<resource_name>[\w]+)/search/$', 'api_search'),

    url(r'^api/v2/(?P<resource_name>[\w]+)/(?P<pk>[\w]+)/$', 'dispatch'),
    url(r'^api/v2/(?P<resource_name>[\w]+)/(?P<pk>[\w]+)/(?P<method_name>[\w]+)/$', 'instance_method'),
)

# Ywot Transfer XHRs
urlpatterns += patterns('marketing.views',
    url(r'^mkt/ywot_transfer_check/$', 'ywot_transfer_check'),
    url(r'^mkt/ywot_transfer_response/$', 'ywot_transfer_response'),
)

# Static files
urlpatterns += patterns('',
    (r'^favicon\.ico$', redirect('/static/images/favicon.ico')),
    (r'^robots\.txt$', redirect('/static/robots.txt')),
)

# Useful when developing with DEBUG=False:
urlpatterns += patterns('',
    (r'^static/(?P<path>.*)$', 'django.views.static.serve',
        {'document_root': root_dir('static')})
    )

USERNAME_URL_REGEX = r'[0-9a-zA-Z_.-]+'

# Wildcards come last:
urlpatterns += patterns('main.views',
    url(r'^page/(?P<page_identifier>{})/$'.format(SLUG_REGEX), 'spa_base2', name='show_ownerless_page'),
    url(r'^(?P<username>{})/$'.format(USERNAME_URL_REGEX), 'spa_base', name="show_user"),
    url(r'^(?P<username>{})/(?P<page_identifier>{})/$'.format(USERNAME_URL_REGEX, SLUG_REGEX), 'spa_base2', name='show_user_page'),
    url(r'^(?P<username>{})/(?P<page_identifier>{})/item-.*$'.format(USERNAME_URL_REGEX, SLUG_REGEX), 'spa_base2'),
)

# Custom 404 -- don't use 404.html, just use spa_base.html
handler404 = 'main.views.spa_base'

