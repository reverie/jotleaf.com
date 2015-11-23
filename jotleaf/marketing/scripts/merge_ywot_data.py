"""
Given a JSON file of (worldname, ywot_username, email_address)
tuples, merges this data into the existing TumblrLead models
based on the worldname field.

$ python marketing/scripts/merge_ywot_data.py marketing/data/relevant_ywot_accounts.json 

To generate this JSON file:
 1. Get the list of missing data:
# >>> leads = TumblrLead.objects.exclude(ywot_world_name='').filter(ywot_username='')
# >>> print json.dumps([l.ywot_world_name for l in leads])
 2. Copy that list into a Django shell open on the YWOT server
 3. json.dumps([(w.name, w.owner.username, w.owner.email) for w in World.objects.filter(name__iexact__in=name_list)])

"""

import json
import sys

from marketing.models import TumblrLead

def load_and_merge_data(json_filename):
    json_data = open(json_filename).read()
    data = json.loads(json_data)
    for worldname, ywot_username, email_address in data:
        tls = TumblrLead.objects.filter(ywot_world_name__iexact=worldname)
        for tl in tls:
            tl.ywot_username = ywot_username or ''
            tl.email_address = email_address or ''
            tl.save()
            print "Set username", ywot_username, "and email", email_address, "on", tl.tumblr_user

def main():
    json_filename = sys.argv[1]
    load_and_merge_data(json_filename)

if __name__ == '__main__':
    main()
