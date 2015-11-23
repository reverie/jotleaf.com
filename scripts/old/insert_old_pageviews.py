def process_row(row):
    from main.models import Page, PageView
    import datetime
    FAKE_DATE = datetime.date(2012, 12, 1)
    path, views = row[:2]
    print "Trying", path
    parts = filter(None, path.split('/'))
    if len(parts) != 2:
        print "URL mismatch"
        return
    part1, part2 = parts
    try:
        page = Page.objects.all_with_deleted().get(id=part2)
    except Page.DoesNotExist:
        try:
            page = Page.objects.all_with_deleted().get(owner__username__iexact=part1, short_url=part2)
        except (Page.DoesNotExist, Page.MultipleObjectsReturned):
            print "Couldn't find page"
            return
    print "Creating", views, "pageview objects"
    if page.pageview_set.filter(created_at=FAKE_DATE).exists():
        print "...just kidding, already processed"
        return
    for i in range(int(views)):
        pv = PageView.objects.create(
           user = None,
           page = page,
           ip_address = '0.0.0.0')
        pv.created_at = FAKE_DATE
        pv.save()
        assert pv.created_at == FAKE_DATE

def get_csv():
    import csv, requests
    from StringIO import StringIO
    print "Fetching data...."
    url = 'http://andrewbadr.com/files/old_pageviews.csv'
    data = requests.get(url).text
    print "...got data."
    return csv.reader(StringIO(data))

reader = get_csv()
for row in reader:
    process_row(row)

