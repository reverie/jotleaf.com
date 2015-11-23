from django import template
from django.template.defaultfilters import stringfilter
from django.template.loader import render_to_string
from main import claiming
from main.models import Page

register = template.Library()

def get_claimable_pages(request):
    if not request.user.is_authenticated():
        return []
    page_ids = claiming.get_request_claimable_page_ids(request)
    if not page_ids:
        return []
    # Note: we may have already claimed some of the pages we have tokens for, so len(page_ids) might not == len(pages)
    return Page.objects.filter(id__in=page_ids, owner__isnull=True)

@register.simple_tag(takes_context=True)
def claim_notifications(context):
    pages = get_claimable_pages(context['request'])
    if not pages:
        return ''
    return render_to_string('claim_notifications.html', {
        'pages': pages
    })

@register.simple_tag()
def user_link(owner):
    from django.core.urlresolvers import reverse
    return """<a href="{url}">{username}</a>""".format(
        url = reverse('show_user', args=[owner.username]),
        username = owner.username
    )


# From http://stackoverflow.com/questions/6481788/format-of-timesince-filter
@register.filter
@stringfilter
def upto(value, delimiter=','):
    return value.split(delimiter)[0]
upto.is_safe = True
    

# Modified from http://djangosnippets.org/snippets/1518/
from django.conf import settings
from django.template.defaulttags import URLNode, url

ABS_BASE = "%s://%s" % (
        settings.PREFERRED_PROTOCOL, 
        settings.PREFERRED_HOST)

def make_path_absolute(path):
    import urlparse
    return urlparse.urljoin(ABS_BASE, path)

class AbsoluteURLNode(URLNode):
    def render(self, context):
        path = super(AbsoluteURLNode, self).render(context)
        return make_path_absolute(path)

@register.tag
def abs_url(parser, token, node_cls=AbsoluteURLNode):
    """Just like {% url %} but creates an absolute URL."""
    node_instance = url(parser, token)
    return node_cls(
        view_name=node_instance.view_name,
        args=node_instance.args,
        kwargs=node_instance.kwargs,
        asvar=node_instance.asvar
    )

@register.simple_tag
def abs_static(static_path):
    return make_path_absolute(settings.STATIC_URL + static_path)
