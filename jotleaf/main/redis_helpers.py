import logging
from redis import StrictRedis

from django.conf import settings

logger = logging.getLogger('django.request')
redis_connection = StrictRedis.from_url(settings.REDIS_URL)

def try_redis_call(method_name, *args, **kwargs):
    method = getattr(redis_connection, method_name)
    default = kwargs.pop('default', None)
    assert not kwargs
    try:
        return method(*args)
    except:
        # Ignore the error. Redis is just a cache, so if it's down or
        # something we'd rather continue than fail the whole request.
        params = "%s, %s" % (method_name, str(args))
        logger.error('Redis call failed: %s' % params, exc_info=True)
        return default
