import logging
import json

from django.conf import settings
from django.contrib.sites.models import Site

from main.redis_helpers import try_redis_call

logger = logging.getLogger('django.request')
current_site = Site.objects.get_current()

JOBS_KEY = 'jobs' # coupled with jl-screenshots app
DEFAULT_SCREENSHOT = settings.STATIC_URL + 'images/screenshot/screenshot_placeholder.png'
PRIVATE_SCREENSHOT = settings.STATIC_URL + 'images/screenshot/private.png'

def get_key(page):
    # coupled with Node app non-DRY
    return "page:%s:screenshot" % page.id

def enqueue_page_screenshot_request(page):
    url = 'http://{hostname}{path}'.format(
        hostname=current_site.domain,
        path=page.get_absolute_url()
    )
    job = {
        'pageId': page.id,
        'url': url,
    }
    job_json = json.dumps(job)
    logger.info("Enqueueing job %s" % job_json)
    try_redis_call('rpush', JOBS_KEY, job_json)

def get_latest_screenshots(pages, include_private=False):
    # doesn't check s3 for the latest screenshot when none is found
    #   - that should be done in an offline process
    if not pages:
        return []
    keys = map(get_key, pages)
    latest = try_redis_call('mget', *keys, default=[None]*len(pages))
    final_result = []
    for page, screen in zip(pages, latest):
        if include_private or page.published:
            final_result.append(screen or DEFAULT_SCREENSHOT)
        else:
            final_result.append(PRIVATE_SCREENSHOT)
    return final_result

def get_latest_screenshot(page, include_private=False):
    if not page:
        return None
    key = get_key(page)
    latest = try_redis_call('get', key, default=None)
    final_result = []
    if include_private or page.published:
        final_result = latest or DEFAULT_SCREENSHOT
    else:
        final_result = PRIVATE_SCREENSHOT
    return final_result

