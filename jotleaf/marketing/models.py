from django.conf import settings
from django.db import models

from common.models import BaseModel

class TumblrLead(BaseModel):
    tumblr_user = models.CharField(max_length=100, unique=True)
    ywot_refers = models.PositiveIntegerField(blank=True, null=True)
    time_last_scraped = models.DateTimeField(blank=True, null=True)
    ywot_link_present = models.NullBooleanField()
    ywot_world_name = models.CharField(max_length=100)
    ywot_username = models.CharField(max_length=100)
    email_address = models.CharField(max_length=100)
    time_emailed = models.DateTimeField(blank=True, null=True)


class YwotTransfer(BaseModel):
    ywot_username = models.CharField(max_length=100, unique=True)
    ywot_password = models.CharField(max_length=128, blank=True)
    ywot_email = models.EmailField(blank=True)
    # If we check a signature against the YWOT server, 
    # and it's valid, store it so we don't have to check again
    valid_signature = models.CharField(max_length=100)

    # Accepted, Rejected, or Neither?
    transfer_status = models.NullBooleanField()
    # If they go through with the transfer:
    local_acct = models.ForeignKey(settings.AUTH_USER_MODEL, blank=True, null=True)

class FollowupEmail(BaseModel):
    """
    Tracks emails sent to users
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL)
    subject_template = models.CharField(max_length=200)
    body_template = models.CharField(max_length=200)
    email_json = models.TextField()
