from django.contrib.auth import get_user_model
from django.core.validators import email_re

User = get_user_model()

# Courtesy of http://justcramer.com/2008/08/23/logging-in-with-email-addresses-in-django/
class EmailOrUsernameModelBackend(object):
    def authenticate(self, username=None, password=None):
        if email_re.search(username):
            kwargs = {'email': username}
        else:
            kwargs = {'username__iexact': username}
        try:
            user = User.objects.get(**kwargs)
            if user.check_password(password):
                return user
        except User.MultipleObjectsReturned:
            raise User.MultipleObjectsReturned('Multple users registered with the same email!')
        except User.DoesNotExist:
            return None

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
