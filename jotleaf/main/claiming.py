PREFIX = 'claim-'

def make_claim_id_from_page_id(page_id):
    # Cookie names must be `str`!
    return str(PREFIX + page_id)

def make_claim_id(page):
    return make_claim_id_from_page_id(page.id)

def get_request_claimable_page_ids(request):
    result = []
    for k in request.COOKIES:
        if k.startswith(PREFIX):
            if request.get_signed_cookie(k, False):
                page_id = k.replace(PREFIX, '')
                result.append(page_id)
    return result

def has_permission(request, page_id):
    claimable = get_request_claimable_page_ids(request)
    return page_id in claimable

