import os
import dj_database_url
from root_dir import root_dir

PROJECT_NAME = 'jotleaf'
DOMAIN = 'jotleaf.com'
PREFERRED_PROTOCOL = 'http'
PREFERRED_HOST = 'www.' + DOMAIN

ALLOWED_HOSTS = [DOMAIN, '.'+ DOMAIN]

DEBUG = False
TEMPLATE_DEBUG = DEBUG

#ADMINS = (
# ...
#)

MANAGERS = ADMINS

_default_database_url = "postgres://{0}:foo@localhost/{0}".format(PROJECT_NAME)
DATABASES = {'default': dj_database_url.config(default=_default_database_url)}

USE_TZ = True
TIME_ZONE = 'UTC'

LANGUAGE_CODE = 'en-us'

SITE_ID = 1

USE_I18N = True

USE_L10N = True

MEDIA_ROOT = ''

MEDIA_URL = ''

LOGIN_URL = '/account/login/'

STATIC_ROOT = root_dir('..', 'static')

STATICFILES_DIRS = (
    root_dir('static'),
)

AUTH_USER_MODEL = 'main.CustomUser'

AWS_ACCESS_KEY_ID = 'your-aws-key' 
AWS_SECRET_ACCESS_KEY = 'your-aws-secret' 
AWS_STORAGE_BUCKET_NAME = 'jotleaf'

STATIC_URL = 'http://s3.amazonaws.com/{}/'.format(AWS_STORAGE_BUCKET_NAME)

STATICFILES_FINDERS = (
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
#    'django.contrib.staticfiles.finders.DefaultStorageFinder',
)

STATICFILES_STORAGE = 'storages.backends.s3boto.S3BotoStorage'


#
# Core config
#

SECRET_KEY = 'yoursecretkey'

TEMPLATE_LOADERS = (
    'django.template.loaders.filesystem.Loader',
    'django.template.loaders.app_directories.Loader',
#     'django.template.loaders.eggs.Loader',
)

MIDDLEWARE_CLASSES = (
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.middleware.transaction.TransactionMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'main.middleware.AlwaysHaveSessionAndCSRF',
)

AUTHENTICATION_BACKENDS = (
    'auth_backend.EmailOrUsernameModelBackend',
    'django.contrib.auth.backends.ModelBackend'
)

ROOT_URLCONF = '%s.urls' % PROJECT_NAME

TEMPLATE_DIRS = (
    root_dir('templates'),
)

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.admin',
    'gunicorn',
    'south',
    'raven.contrib.django',
    'storages',
    'registration',
    'main',
    'marketing'
)

TEMPLATE_CONTEXT_PROCESSORS = [
    "django.contrib.auth.context_processors.auth",
    "django.core.context_processors.debug",
    "django.core.context_processors.i18n",
    "django.core.context_processors.media",
    "django.core.context_processors.static",
    "django.core.context_processors.request",
    "django.contrib.messages.context_processors.messages",
    "common.context.settings"
]

# Email
DEFAULT_FROM_EMAIL = SERVER_EMAIL = '"Jotleaf" <hello@%s>' % DOMAIN
EMAIL_USE_TLS = True

# Mandrill Email
EMAIL_HOST = 'smtp.mandrillapp.com'
EMAIL_HOST_USER = 'your-email-user'
EMAIL_HOST_PASSWORD = 'your-email-password'
EMAIL_PORT = 587


# Registration
ACCOUNT_ACTIVATION_DAYS = 3
LOGIN_REDIRECT_URL = '/'

# APIs -- Production values. Put dev values in localsettings.py or stagesettings.py
FACEBOOK_API_KEY = ''
FACEBOOK_SECRET_KEY = ''
TWITTER_CONSUMER_KEY = ''
TWITTER_CONSUMER_SECRET = ''
MAILCHIMP_API_KEY = '...'
MIXPANEL_ID = "..."
PUSHER_APP_ID = '...'
PUSHER_KEY = '...'
PUSHER_SECRET = '...'
YWOT_HOST = 'www.yourworldoftext.com'
FILEPICKER_KEY = '...'
EMBEDLY_KEY = '...'

ALLOWED_EMBEDLY_PROVIDERS = ['youtube', 'bandcamp', 'soundcloud', 'vimeo']

SUGGESTED_USERS = ['lanadandan', 'kurtz', 'JoeAranda']

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '%(levelname)s %(asctime)s %(module)s %(message)s'
        },
    },
    'filters': {
         'require_debug_false': {
             '()': 'django.utils.log.RequireDebugFalse'
         }
     },
    'handlers': {
        'mail_admins': {
            'level': 'ERROR',
            'filters': ['require_debug_false'],
            'class': 'django.utils.log.AdminEmailHandler'
        },
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose'
        },
    },
    'loggers': {
        'django': {
            'level': 'DEBUG',
            'handlers': ['console'],
            'propagate': True,
        },
        'django.request': {
            'level': 'ERROR',
            'handlers': ['mail_admins'],
            'propagate': True,
        },
        'marketing.email_marketing': {
            'handlers': ['mail_admins'],
            'level': 'ERROR',
            'propagate': True,
        }
    }
}

LOG_DIRECTORY = root_dir('/project/%s/log/' % PROJECT_NAME)

TASTYPIE_FULL_DEBUG = True

SENTRY_DSN = '...'

# Caching -- see 
# https://devcenter.heroku.com/articles/memcachier#django
# and https://github.com/rdegges/django-heroku-memcacheify
from memcacheify import memcacheify
CACHES = memcacheify()

# Prevent project cache collisions
CACHE_MIDDLEWARE_KEY_PREFIX = PROJECT_NAME + ':'

REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/')

IS_PRODUCTION = 'JOTLEAF_PRODUCTION_MODE' in os.environ

try:
    from stagesettings import *
except ImportError:
    pass

try:
    from localsettings import *
except ImportError:
    pass


