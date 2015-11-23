import logging
import sys
from collections import defaultdict

from django.core.management.base import BaseCommand

from common.shortcuts import time_ago

logger = logging.getLogger('django.management')

class SendNotificationEmailCommand(BaseCommand):
    args = '<number_of_seconds_back_to_look>'

    def get_start(self, args):
        if not args:
            print "Must pass number of seconds as arguments."
            sys.exit(1)
        secs_back_to_look = int(args[0])
        return time_ago(seconds=secs_back_to_look)

    def get_base_instances(self, start):
        """The set of models that we may want to send e-mail notifications regarding."""
        return self.model.objects.filter(created_at__gte=start).select_related()

    def get_tracking_object_attributes(self, instance):
        """
        Given an instance of the model we're tracking, get the kwargs to 
        find or create the tracking object that indicates whether we've already
        processed this instance.
        """
        return {
            self.recipient_field: getattr(instance, self.recipient_field),
            self.other_field: getattr(instance, self.other_field)
        }

    def get_unprocessed_instances(self, start):
        """The subset of base_instances that we have not previously marked as complete."""
        instances = self.get_base_instances(start)
        unprocessed = []
        for i in instances:
            match_kwargs = self.get_tracking_object_attributes(i)
            if self.tracking_model.objects.filter(**match_kwargs).exists():
                logger.debug("Skipping duplicate notification for %s object %s" % (self.model, i.id))
            else:
                unprocessed.append(i)
        return unprocessed

    def group_by_recipient(self, instances):
        grouped_by_recipient = defaultdict(list)
        for i in instances:
            grouped_by_recipient[getattr(i, self.recipient_field)].append(i)
        return grouped_by_recipient

    def final_exclusion_filter(self, recipient, instance):
        """Whether to 'fake' sending the email for this instance."""
        return

    def process_grouped_instances(self, grouped_by_recipient):
        """
        Given a map from (recipient) -> (objects to process), 
        process (i.e. send email notifications for) all of the objects.
        """
        for recipient, instances in grouped_by_recipient.iteritems():
            for i in instances:
                assert recipient == getattr(i, self.recipient_field)
                match_kwargs = self.get_tracking_object_attributes(i)
                self.tracking_model.objects.create(**match_kwargs)
            instances = [i for i in instances if not self.final_exclusion_filter(recipient, i)]
            debug_log = lambda s: logger.debug(s % (self.model, recipient))
            if not instances:
                debug_log("Excluded all %s notifications for %s")
                return
            elif len(instances) == 1:
                debug_log("Sending single-%s email to %s")
                self.send_single_email(recipient, instances[0])
            else:
                debug_log("Sending multi-%s email to %s")
                self.send_bundled_email(recipient, instances)

    def handle(self, *args, **options):
        start = self.get_start(args)
        to_process = self.get_unprocessed_instances(start)
        grouped = self.group_by_recipient(to_process)
        self.process_grouped_instances(grouped)

