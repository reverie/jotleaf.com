import os

from django import template
from django.conf import settings

register = template.Library()

if settings.IS_PRODUCTION:
    # name JOTLEAF_RELEASE_TAG coupled w/fabfile.py
    RELEASE_TAG = os.environ['JOTLEAF_RELEASE_TAG']
    JS_HASH = os.environ['JOTLEAF_JS_HASH']

# NB Doesn't do any actual script compilation. That's done separately in `processor`

class CompiledScriptsNode(template.Node):
    def __init__(self, compilation_name, nodes):
        self.compilation_name = compilation_name
        self.nodes = nodes

    def render(self, context):
        if settings.IS_PRODUCTION:
            src = "{}{}_{}.js".format(
                    settings.STATIC_URL, self.compilation_name, JS_HASH)
            return '<script type="text/javascript" src="{}"></script>'.format(src)
        else:
            return self.nodes.render(context)

@register.tag
def scripts_to_compile(parser, token):
    compilation_name = token.split_contents()[1]
    nodes = parser.parse(['end_scripts_to_compile'])
    parser.delete_first_token()
    return CompiledScriptsNode(compilation_name, nodes)

@register.simple_tag
def release_tag():
    if settings.IS_PRODUCTION:
        return RELEASE_TAG
    else:
        return 'dev'
