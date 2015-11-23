from root_dir import root_dir

DEBUG = True

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3', 
        'NAME': root_dir('dev.sqlite'),
        'USER': '',
        'PASSWORD': '',
        'HOST': '',
        'PORT': '',
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.dummy.DummyCache',
    }
}

LOG_DIRECTORY = root_dir('..', 'dev_logs')

EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'

YWOT_HOST = 'localhost:8001'

PUSHER_APP_ID = '27671'
PUSHER_KEY = '...'
PUSHER_SECRET = '...'
MIXPANEL_ID = "..."

STATIC_URL = '/static/'

SENTRY_DSN = None
