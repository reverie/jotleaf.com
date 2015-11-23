from django.contrib import messages

from registration.backends.simple import SimpleBackend

from django import forms
from django.utils.translation import ugettext_lazy as _
from registration.forms import attrs_dict

USERNAME_REGEX = r'[a-zA-Z][0-9a-zA-Z_.-]+'
FULL_USERNAME_REGEX = '^' + USERNAME_REGEX + '$'

_URL_PREFIXES = None

from django.contrib.auth import get_user_model
User = get_user_model()

def get_url_prefixes():
    """
    Returns the set of URL prefixes our app uses. Used by
    registration to forbid usernames that conflict with
    site URLs, so that jotleaf.com/<username> always works.
    """
    global _URL_PREFIXES
    if _URL_PREFIXES is not None:
        return _URL_PREFIXES
    import re
    from django.conf import settings
    from django.core.urlresolvers import get_resolver
    also_banned = frozenset(['undefined', 'humans.txt'])
    resolver = get_resolver(settings.ROOT_URLCONF)
    prefixes = set()
    for pattern in resolver.url_patterns:
        base = pattern._regex.split('/')[0]
        base = base.lstrip('^').rstrip('$')
        base = base.replace('\\', '')
        if not re.match(r'[\w.-]+$', base):
            # This is a regex -- ignore it
            continue
        prefixes.add(base)
    _URL_PREFIXES = frozenset(prefixes.union(also_banned))
    return _URL_PREFIXES

### Largely copied from registration.forms.RegistrationForm
class MyRegistrationForm(forms.Form):
    username = forms.RegexField(
        regex=FULL_USERNAME_REGEX,
        min_length=3,
        max_length=30,
        widget=forms.TextInput(attrs=attrs_dict),
        label=_("Username"),
        error_messages={
            'invalid': _("Username may contain only letters, numbers and the ./-/_ characters.")
        }
    )
    email = forms.EmailField(
        widget=forms.TextInput(attrs=dict(attrs_dict, maxlength=75)),
        label=_("E-mail")
    )
    password = forms.CharField(
        widget=forms.PasswordInput(attrs=attrs_dict, render_value=False),
        label=_("Password")
    )

    def clean_username(self):
        """
        Check that the username doesn't conflict with a URL prefix.
        """
        username = self.cleaned_data['username']
        exists_msg = _("A user with that username already exists.")
        if username.lower() in get_url_prefixes():
            raise forms.ValidationError(exists_msg)
        if User.objects.filter(username__iexact=username).exists():
            raise forms.ValidationError(exists_msg)
        else:
            return username


class JotleafBackend(SimpleBackend):
    def register(self, request, **kwargs):
        #from marketing.email_marketing import subscribe_user
        # Translate to built-in backend's expectation of 2 passwords:
        kwargs['password1'] = kwargs['password2'] = kwargs['password']
        new_user = super(JotleafBackend, self).register(request, **kwargs)
        #subscribe_user(new_user)
        return new_user

    def post_registration_redirect(self, request, user):
        messages.success(request, "Success! You're now logged in as %s" % user.username)
        return ('home', (), {})

    def get_form_class(self, request):
        return MyRegistrationForm
