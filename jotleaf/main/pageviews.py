import logging

from main.redis_helpers import redis_connection

logger = logging.getLogger('django.request')

def get_key(page):
    return "page:%s:views" % page.id

def set_count(page):
    from main.models import PageView
    key = get_key(page)
    count = PageView.objects.filter(page=page).count()
    redis_connection.set(key, count)
    return count

def increment_count(page):
    key = get_key(page)
    if redis_connection.exists(key):
        redis_connection.incr(key)
    else:
        set_count(page)

def get_count(page):
    key = get_key(page)
    val = redis_connection.get(key)
    if val is None:
        val = set_count(page)
    return int(val)

def get_counts(pages):
    # todo: make this more efficient at some point
    if not pages:
        return []
    return map(get_count, pages)
