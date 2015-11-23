from main.emails import send_follow_email, send_multifollow_email
from main.management.helpers import SendNotificationEmailCommand
from main.models import Follow, SentFollowEmail

class Command(SendNotificationEmailCommand):
    help = 'Send emails to everyone who has a new follower.'

    model = Follow
    tracking_model = SentFollowEmail
    recipient_field = 'target'
    other_field = 'user'

    send_single_email = staticmethod(send_follow_email)
    send_bundled_email = staticmethod(send_multifollow_email)

    def final_exclusion_filter(self, recipient, follow):
        assert recipient == follow.target
        if not recipient.email_on_new_follower:
            return True
