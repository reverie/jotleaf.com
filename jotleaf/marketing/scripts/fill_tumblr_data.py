"""
Given a CSV file of referers exported from Google Analytics,
fills in as much TumblrLead data as possible.

Example usage:
$ python marketing/scripts/fill_tumblr_data.py marketing/data/ywot_tumblr_referers_20120714-20120813.csv 
"""

import csv
import datetime
import re
import requests
import sys

from marketing.models import TumblrLead

def insert_tumblr_leads(csv_filename):
    f = open(csv_filename)
    reader = csv.reader(f)
    rows = list(reader)
    for row in rows:
        hostname = row[0]
        hostname = hostname.lower()
        if not hostname.endswith('.tumblr.com'):
            continue
        tumblr_user = hostname.split('.')[0]
        refer_count_str = row[1]
        refers = int(refer_count_str.replace(',', ''))
        tl, new = TumblrLead.objects.get_or_create(tumblr_user=tumblr_user, defaults={
            'ywot_refers': refers
        })
        if new:
            print "Created TumblrLead for", tumblr_user

def scrape_tumblr_pages():
    for tl in TumblrLead.objects.filter(time_last_scraped__isnull=True):
        tl.time_last_scraped = datetime.datetime.now()
        url = 'http://{}.tumblr.com'.format(tl.tumblr_user)
        try:
            r = requests.get(url)
        except:
            print "Could not connect to", url
            continue
        if r.status_code == 404:
            print "Tumblr at", url, "seems to have disappeared"
            tl.save()
            continue
        elif r.status_code != 200:
            import pdb; pdb.set_trace()
        worlds = re.findall('http://(?:www\.)?yourworldoftext.com/([\w]+)', r.content, re.I)
        if worlds:
            tl.ywot_link_present = True
            if len(worlds) > 1:
                print "Tumblr {} had more than one link: {}".format(url, worlds)
            tl.ywot_world_name = worlds[0]
        else:
            tl.ywot_link_present = False
            # Don't both overwriting ywot_world_name if it was present

        tl.save()
        print "Scraped", url, "found world:", tl.ywot_world_name

def main():
    csv_filename = sys.argv[1]
    insert_tumblr_leads(csv_filename)
    scrape_tumblr_pages()

if __name__ == '__main__':
    main()
