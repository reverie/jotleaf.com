import datetime
import pytz

def utc_now():
    return datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

def time_ago(**kwargs):
    return utc_now() - datetime.timedelta(**kwargs)

def dict_subset(d, field_names):
    return dict(
        (f, d[f]) 
        for f in field_names
        if f in d
    )

def date_breakdown(min_date, max_date, freq):
    """
    `freq` is one of 'd', 'w', 'm' for daily, weekly, monthly

    Returns a list of start_date, end_date pairs that cover the dates in question,
    meaning that every doc in the list falls into one of the date ranges,
    such that the inclusive span [start_date, end_date] is the `freq` time span.

    Note that doic.date is a datetime.date, not a datetime.datetime.
    """
    range_end = max_date
    if freq == 'd':
        range_start = range_end
    elif freq == 'w':
        range_start = range_end - datetime.timedelta(days=6)
    elif freq == 'm':
        range_start = datetime.date(range_end.year, range_end.month, 1)
    else:
        raise ValueError

    yield range_start, range_end

    while range_start > min_date:
        # update range_end and range start
        if freq == 'd':
            range_start = range_end = range_end - datetime.timedelta(days=1)
        elif freq == 'w':
            range_end -= datetime.timedelta(days=7)
            range_start -= datetime.timedelta(days=7)
        else: # freq == 'm'
            range_end = range_start - datetime.timedelta(days=1)
            range_start = datetime.date(range_end.year, range_end.month, 1)
        yield range_start, range_end



