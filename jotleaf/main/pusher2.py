import httplib, time, sys, hmac
import json
from hashlib import md5, sha256

host    = 'api.pusherapp.com'
port    = 80
app_id  = None
key     = None
secret  = None

class Pusher(object):
    def __init__(self, app_id=None, key=None, secret=None, host=None, port=None, encoder=None):
        _globals = globals()
        self.app_id = app_id or _globals['app_id']
        self.key = key or _globals['key']
        self.secret = secret or _globals['secret']
        self.host = host or _globals['host']
        self.port = port or _globals['port']
        self.path = '/apps/%s/events' % (app_id)
        self.encoder = encoder or json.JSONEncoder

    def build_signed_query(self, json_data):
        body_md5 = md5(json_data).hexdigest()
        query_string = "auth_key={}&auth_timestamp={}&auth_version=1.0&body_md5={}".format(
            self.key, 
            int(time.time()), 
            body_md5
        )
        string_to_sign = "POST\n{}\n{}".format(
            self.path, 
            query_string
        )
        signature = hmac.new(self.secret, string_to_sign, sha256).hexdigest()
        signed_query = "{}&auth_signature={}".format(
            query_string, 
            signature
        )
        return signed_query

    def send_request(self, signed_path, data_string):
        http = httplib.HTTPConnection(self.host, self.port)
        http.request('POST', signed_path, data_string, {'Content-Type': 'application/json'})
        return http.getresponse()

    def trigger(self, channels, event, data={}, socket_id=None):
        data = json.dumps(data, cls=self.encoder)
        body = {
            'name': event,
            'data': data,
            'channels': channels,
            'socket_id': socket_id
        }
        json_data = json.dumps(body)
        query_string = self.build_signed_query(json_data)

        signed_path = "{}?{}".format(self.path, query_string)
        response = self.send_request(signed_path, json_data)
        status = response.status
        if status == 200:
            return True
        elif status == 401:
            raise AuthenticationError
        elif status == 404:
            raise NotFoundError
        elif status == 413:
            raise MaxDataLengthExceededError
        else:
            body = response.read()
            raise Exception("Unexpected return status %s: %s" % (status, body))

    def authenticate(self, socket_id, channel_name, custom_data=None):
        if not socket_id:
          raise Exception("Invalid socket_id")

        if custom_data:
            custom_data = json.dumps(custom_data)

        auth = self.authentication_string(socket_id, channel_name, custom_data)
        response_dct = {'auth': auth}

        if custom_data:
            response_dct['channel_data'] = custom_data

        return response_dct

    def authentication_string(self, socket_id, channel_name, custom_string=None):
        tokens = [socket_id, channel_name]

        if custom_string:
            tokens.append(custom_string)

        string_to_sign = ":".join(tokens)
        signature = hmac.new(self.secret, string_to_sign, sha256).hexdigest()

        return ":".join((self.key, signature))

class AuthenticationError(Exception):
    pass

class NotFoundError(Exception):
    pass

class MaxDataLengthExceededError(Exception):
    pass