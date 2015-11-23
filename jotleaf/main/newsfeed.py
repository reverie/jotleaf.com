from itertools import chain

from django.db.models import Q, F

from common.shortcuts import time_ago
from main.helpers import simple_read
from main.models import *
from main.views import other_user_to_js
from main.screenshots import get_latest_screenshots, get_latest_screenshot

def _nf_page_to_dict(page):
    creator = other_user_to_js(page.owner)
    screenshot = get_latest_screenshot(page)
    pageDct = {
        'id': page.id,
        'title': page.title,
        'short_url': page.short_url,
        'get_absolute_url': page.get_absolute_url(),
        'screenshot': screenshot,
        'creator_id': creator['id'],
        'creator_username': creator['username'],
    }
    return pageDct

def _nf_pages_to_dict(pages):
    screenshots = get_latest_screenshots(pages, include_private=True)
    pages_cache = dict()

    for page, screen in zip(pages, screenshots):
        creator = other_user_to_js(page.owner)
        pages_cache[page.id] = {
            'id': page.id,
            'title': page.title,
            'short_url': page.short_url,
            'get_absolute_url': page.get_absolute_url(),
            'screenshot': screen,
            'creator_id': creator['id'],
            'creator_username': creator['username'],
        }        
    return pages_cache

def _get_page_from_activity(instance):
    page = None
    if isinstance(instance, Item):
        page = instance.page
    elif isinstance(instance, Membership):
        page = instance.page
    elif isinstance(instance, Page):
        page = instance
    return page

def _get_user_from_activity(instance):
    user = None
    model = instance.__class__
    if issubclass(model, Item):
        user = instance.creator
    elif model == Membership:
        user = instance.page.owner
    elif model == Follow:
        user = instance.user
    elif model == Page:
        user = instance.owner
    return user

def _aggregate_activity(user, days=60):
	since_datetime = time_ago(days=days)

	memberships = Membership.objects.filter(created_at__gt=since_datetime, user=user).select_related('page', 'user', 'page__owner')
	follows = Follow.objects.filter(created_at__gt=since_datetime, target=user).select_related('user')

	textitems = TextItem.objects.exclude(creator=user).filter(
		Q(created_at__gt=since_datetime), 
		Q(page__owner=user) | Q(page__membership__user=user) |
		Q(page__published=True) & Q(creator__followers__user=user) & ~Q(page__owner=F('creator'))
		).select_related('page', 'page__owner', 'creator').distinct()
	
	imageitems = ImageItem.objects.exclude(creator=user).filter(
		Q(created_at__gt=since_datetime), 
		Q(page__owner=user) | Q(page__membership__user=user) |
		Q(page__published=True) & Q(creator__followers__user=user) & ~Q(page__owner=F('creator'))
		).select_related('page', 'page__owner', 'creator').distinct()

	embeditems = EmbedItem.objects.exclude(creator=user).filter(
		Q(created_at__gt=since_datetime), 
		Q(page__owner=user) | Q(page__membership__user=user) |
		Q(page__published=True) & Q(creator__followers__user=user) & ~Q(page__owner=F('creator'))
		).select_related('page', 'page__owner', 'creator').distinct()

	pages_published_by_following = Page.objects.filter(
		published_at__gt=since_datetime, owner__followers__user=user, published=True
	).select_related('owner')

	all_activity_last_n_days = sorted(
		chain(pages_published_by_following, memberships, textitems, imageitems, embeditems, follows), 
		key=lambda instance: instance.published_at if hasattr(instance, 'published_at') else instance.created_at,
		reverse=True
	)[:20]

	return all_activity_last_n_days

def _instance_to_news(activity, pages_cache=None):
	item_data = simple_read(activity)
	if isinstance(activity, Item):
		item_data['get_absolute_url'] = activity.get_absolute_url()

	# Figure out who the user is based on the activity type
	user = _get_user_from_activity(activity)
	page = _get_page_from_activity(activity)
	username = user.username if user else None
	timestamp = activity.published_at if hasattr(activity, 'published_at') else activity.created_at

	if page:
		if pages_cache:
			pageDct = pages_cache.get(page.id)
		else:
			pageDct = _nf_page_to_dict(page) 
	else:
		pageDct = None

	news = {
		'type': activity.SHORTNAME,
		'page': pageDct,
		'timestamp': timestamp,
		'data': item_data,
		'user': username,
	}
	return news


def get_newsfeed_for_user(user):
	""" 
	Dynamically construct and return the newsfeed for the user
	The newsfeed is made up of a reverse-chronologically ordered
	list of all the activities in the last N days.

	The activies include:
	- New memberships for the user
	- Another user follows user
	- New items on the user's pages inserted by others
	- New items inserted by others on pages user is a member of
	- Any user the user is following publishes a page 
	- Any user the user is following posts something on published pages
	"""
	
	last_n_days = 60

	recent_activity = _aggregate_activity(user, last_n_days)

	# construct a list of all the related pages to make a single batch redis call
	# to fetch the screenshots
	# iterating twice over activity is cheaper than N network roundtrips to redis
	pages = []
	for activity in recent_activity:
		page = _get_page_from_activity(activity)
		if page:
			pages.append(page)

	# fetches the screenshots and combines them with relative fields from page
	# to build the lightweight page dictionaries to send to the client
	pages_cache = _nf_pages_to_dict(pages)
	headline_news = [_instance_to_news(activity, pages_cache) for activity in recent_activity]
	
	return headline_news
