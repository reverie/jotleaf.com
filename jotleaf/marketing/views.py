import json
import requests

from django.conf import settings
from django.contrib import messages

from common.views import json as json_view

from marketing.models import YwotTransfer

from django.contrib.auth import get_user_model
User = get_user_model()


YWOT_CHECK_URL = "http://{}/connect/check/".format(settings.YWOT_HOST)


@json_view
def ywot_transfer_check(request):
    """
    Returns
    {
        transfer_status: true/false/null
    }

    where true means it's already been accepted,
    null means the user hasn't decided yet
    false means the user already rejected the idea.
    """
    username = request.POST['username']
    sig = request.POST['sig']
    if User.objects.filter(username__iexact=username).exists():
        # User with this username has already been created,
        # nothing we can do anyway
        return
    try:
        yt = YwotTransfer.objects.get(ywot_username__iexact=username)
    except YwotTransfer.DoesNotExist:

        r = requests.post(YWOT_CHECK_URL, data={
            'username': username,
            'sig': sig
        })
        assert r.status_code == 200
        result = json.loads(r.content)
        yt = YwotTransfer.objects.create(
            ywot_username = result['username'],
            ywot_password = result['password'],
            ywot_email = result['email'],
            valid_signature = sig
        )
    return {'transfer_status': yt.transfer_status}

@json_view
def ywot_transfer_response(request):
    from main.views import _do_login_as
    username = request.POST['username']
    sig = request.POST['sig']
    response = request.POST['response']
    yt = YwotTransfer.objects.get(ywot_username__iexact=username, valid_signature=sig)

    if response == 'no':
        yt.transfer_status = False
        yt.save()
        return {}

    assert response == 'yes'
    yt.transfer_status = True

    if yt.local_acct or User.objects.filter(username__iexact=username).exists():
        # Account already exists. Just pretend we did something, but don't
        # log them in. Otherwise someone could make a corresponding YWOT account
        # to hijack a Jotleaf account.
        yt.save()
        messages.success(request, "Success! You can now log in as '%s'." % username)
        return {
            'success': True
        }

    u = User.objects.create(
        username = username, 
        password = yt.ywot_password,
        email = yt.ywot_email
    )
    yt.local_acct = u
    yt.save()
    _do_login_as(request, username)
    messages.success(request, "Success! You're now logged in as '%s'." % username)
    return {
        'success': True
    }
