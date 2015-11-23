"""Helpers relating to views."""

import pytz
import json as py_json # ugh
from datetime import datetime

from django.core.serializers.json import DjangoJSONEncoder

def convert_to_utc(date):
    from django.utils import timezone
    if timezone.is_naive(date):
        # meant to be Django's TIME_ZONE
        current = timezone.get_current_timezone()
        date = date.replace(tzinfo=current)
    assert timezone.is_aware(date)
    return pytz.utc.normalize(date)

def date_to_javascript(date):
    # Returns in ISO 8601 with UTC timezone
    date = convert_to_utc(date)
    return date.isoformat()

class DateJSONEncoder(DjangoJSONEncoder):
    def default(self, o):
        if isinstance(o, datetime):
            return date_to_javascript(o)
        return super(DateJSONEncoder, self).default(o)

def json_response(obj):
    """Makes JSON HttpResponse out of obj."""
    from django.http import HttpResponse
    return HttpResponse(py_json.dumps(obj, cls=DateJSONEncoder), mimetype='application/javascript')

def json(f):
    """Decorator for views that return JSON."""
    from functools import wraps
    from django.http import HttpResponse
    @wraps(f)
    def json_view(*args, **kwargs):
        result = f(*args, **kwargs)
        if isinstance(result, HttpResponse):
            return result
        return json_response(result)
    return json_view

def req_render_to_response(request, template, context=None):
    """render_to_response with request context"""
    from django.shortcuts import render_to_response
    from django.template import RequestContext
    context = context or {}
    rc = RequestContext(request, context)
    return render_to_response(template, context_instance=rc)

def response_403(content='Permission denied'):
    from django.http import HttpResponseForbidden
    return HttpResponseForbidden(content)

def get_post_action(post):
    actions = [key for key in post.keys() if key.startswith('submit_')]
    if not actions:
        return None
    if len(actions) != 1:
        raise ValueError('get_post_action got post with multiple actions')
    return actions[0].split('_', 1)[1]

