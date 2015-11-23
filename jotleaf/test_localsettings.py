from root_dir import root_dir

DEBUG = True

LOG_DIRECTORY = root_dir('..', 'dev_logs')

EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'
EMAIL_PORT = 1025

YWOT_HOST = 'localhost:8001'

PUSHER_APP_ID = '...'
PUSHER_KEY = '...'
PUSHER_SECRET = '...'
MIXPANEL_ID = "..."

STATIC_URL = '/static/'

SENTRY_DSN = None

