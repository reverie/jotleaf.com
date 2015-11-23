from django.core.management.base import BaseCommand

from main.models import Page
from main.screenshots import enqueue_page_screenshot_request

class Command(BaseCommand):
    help = 'Enqueues a request to create a new screenshot for every single Page.'

    def handle(self, *args, **options):
        for p in Page.objects.all():
            try:
                enqueue_page_screenshot_request(p)
            except:
                # Some pages don't have URLs because the owner username is too short and 
                # doesn't match the reverse-url regex. Really need a better solution here.
                pass
    
