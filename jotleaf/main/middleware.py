from django.middleware.csrf import get_token

class AlwaysHaveSessionAndCSRF(object):
    def process_request(self, request):
        get_token(request)
        return

    def process_response(self, request, response):
        if hasattr(request, 'session') and not request.session.session_key:
            request.session.modified = True
        return response
