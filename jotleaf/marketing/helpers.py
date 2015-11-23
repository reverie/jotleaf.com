import datetime
import json
from smtplib import SMTPException

from django.core.mail import send_mail
from django.template.loader import render_to_string

from common.shortcuts import utc_now
from marketing.models import FollowupEmail

from django.contrib.auth import get_user_model
User = get_user_model()

def send_marketing_email(user, subject_template, body_template):
    context = {
        'sender_name': 'Andrew',
        'username': user.username,
    }
    subject = render_to_string(subject_template, context).strip()
    body = render_to_string(body_template, context).strip()
    assert '{' not in subject
    assert '{' not in body
    from_email = '"Andrew" <andrew@jotleaf.com>'
    to_email = user.email
    try:
        send_mail(subject, body, from_email, [to_email])
    except SMTPException:
        # todo: log
        return False
    FollowupEmail.objects.create(
        user=user,
        subject_template=subject_template,
        body_template=body_template,
        email_json = json.dumps({
            'from_email': from_email,
            'to_email': to_email,
            'subject': subject,
            'body': body,
        })
    )
    return True


def send_multi(users, subject_template, body_template):
    sent = []
    didnt_send = []
    failed = []
    for u in users:
        if FollowupEmail.objects.filter(user=u).exists():
            didnt_send.append(u)
        else:
            success = send_marketing_email(u, subject_template, body_template)
            if success:
                sent.append(u)
            else:
                failed.append(u)
    return sent, didnt_send, failed

def get_top_pages(since, count=10):
    """The top `count` most-viewed pages since `since`."""
    from django.db.models import Count
    from main.models import PageView
    pageviews = PageView.objects.filter(created_at__gte=since)
    pv_by_page = pageviews.values('page').annotate(pcount=Count('page'))
    return pv_by_page.order_by('-pcount')[:count]

def _get_first_by(base_object, related_name, order_field, reverse=False):
    ordering = ('-' if reverse else '') + order_field
    try:
        instance = getattr(base_object, related_name).order_by(ordering)[0]
        return getattr(instance, order_field)
    except IndexError:
        return None

def get_long_creating_users():
    """
    The 20 users who have the longest (first-creation-date, last-creation-date) intervals.
    Performs O(n) queries, where n is the number of registered users.
    """
    import heapq
    user_intervals = {}
    for u in User.objects.all():
        # TODO: embeds (& generalize)
        first_ti = _get_first_by(u, 'textitem_set', 'created_at')
        first_ii = _get_first_by(u, 'imageitem_set', 'created_at')
        if not (first_ti or first_ii):
            continue
        first = min(first_ti, first_ii)
        last_ti = _get_first_by(u, 'textitem_set', 'created_at', True)
        last_ii = _get_first_by(u, 'imageitem_set', 'created_at', True)
        last = min(last_ti, last_ii)
        active_range = last - first
        user_intervals[u] = active_range
    return heapq.nlargest(20, user_intervals, key=lambda k: user_intervals[k])

def get_long_viewing_users():
    """
    The 20 users who have the longest (first-viewing-date, last-viewing-date) intervals.
    Performs O(n) queries, where n is the number of registered users.
    """
    import heapq
    user_intervals = {}
    for u in User.objects.all():
        first = _get_first_by(u, 'pageview_set', 'created_at')
        if not first:
            continue
        last = _get_first_by(u, 'pageview_set', 'created_at', True)
        active_range = last - first
        user_intervals[u] = active_range
    return heapq.nlargest(20, user_intervals, key=lambda k: user_intervals[k])


def get_active_users(now=None):
    """Returns the number of registered users who have viewed a page in the past two weeks."""
    if now is None:
        now = utc_now()
    two_weeks_ago = now - datetime.timedelta(days=14)
    return User.objects.filter(pageview__created_at__gte=two_weeks_ago).distinct().count()
