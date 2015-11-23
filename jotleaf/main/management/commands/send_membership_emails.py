from main.emails import send_member_email, send_multimember_email
from main.management.helpers import SendNotificationEmailCommand
from main.models import Membership, SentMemberEmail

class Command(SendNotificationEmailCommand):
    help = 'Send emails to everyone who has been added to a page.'

    model = Membership
    tracking_model = SentMemberEmail
    recipient_field = 'user'
    other_field = 'page'

    send_single_email = staticmethod(send_member_email)
    send_bundled_email = staticmethod(send_multimember_email)

    def final_exclusion_filter(self, recipient, membership):
        assert recipient == membership.user
        if not recipient.email_on_new_membership:
            return True
        if recipient.id == membership.page.owner_id:
            return True



