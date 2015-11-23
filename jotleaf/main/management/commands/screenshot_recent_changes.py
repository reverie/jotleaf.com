import datetime

from django.core.management.base import BaseCommand

from main.models import Page
from main.screenshots import enqueue_page_screenshot_request

class Command(BaseCommand):
    help = 'Enqueues a request to create a new screenshot for every page that has been updated in the last ten minutes.'

    def handle(self, *args, **options):
        now = datetime.datetime.now()
        ten_minutes_ago = now - datetime.timedelta(minutes=10)
        pages_to_screenshot = set()
        recent_updated_pages = Page.objects.filter(updated_at__gte=ten_minutes_ago)
        pages_to_screenshot |= set(recent_updated_pages)

        # TODO: better solution
        # TODO: add embed items when available
        for item_type in ['textitem', 'imageitem']:
            filter_name = "%s__updated_at__gte" % item_type
            filter_kwargs = {filter_name: ten_minutes_ago}
            recently_updated = Page.objects.filter(**filter_kwargs)
            pages_to_screenshot |= set(recently_updated)

        for page in pages_to_screenshot:
            print "Enqueing request for", page.id
            enqueue_page_screenshot_request(page)

        print "-"*80
        print "Enqueued", len(pages_to_screenshot), "requests total."

