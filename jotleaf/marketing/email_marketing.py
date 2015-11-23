from mailsnake import MailSnake
from mailsnake.exceptions import *
import settings
import logging

ms = MailSnake(settings.MAILCHIMP_API_KEY)

lists = ms.lists()

logger = logging.getLogger(__name__)


def subscribe_user(user):
    try:
        ms.listSubscribe(
            id=lists['data'][0]['id'],
            email_address=user.email,
            merge_vars={
                'USERNAME': user.username,
                'FNAME': user.first_name or '',
                'LNAME': user.last_name or '',
                },
            update_existing=True,
            double_optin=False,
            send_welcome=False,
        )
    except MailSnakeException:
        logger.warn('MailChimp listSubscribe call failed for user %s' % user.email, exc_info=True)
