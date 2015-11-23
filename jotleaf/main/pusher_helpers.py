import logging
import functools

logger = logging.getLogger('django.request')

def make_pusher():
    from main.api2 import APIEncoder
    from pusher2 import Pusher
    from django.conf import settings
    return Pusher(
        settings.PUSHER_APP_ID,
        settings.PUSHER_KEY,
        settings.PUSHER_SECRET,
        encoder=APIEncoder
    )

def model_to_channel_name(channel_model, model_id):
    return 'private-' + channel_model + '-' + str(model_id)

def models_to_channel_names(channel_model, model_ids):
    return ["private-{}-{}".format(channel_model, str(id)) for id in model_ids]

def parse_channel_name(channel_name):
    return channel_name.split('-')

def try_pusher_send(channel_model, model_ids, event, data, socket_id=None):
    try:
    	pusher = make_pusher()
        # if we didn't receive a list, make it one 
        if isinstance(model_ids, (basestring, int)):
            model_ids = [model_ids]
        
        num_channels = len(model_ids)

        # Pusher supports pushing up to 100 channels at a time
        for i in xrange(0, num_channels, 100):
            model_ids_chunk = model_ids[i:i+100]
            channels = models_to_channel_names(channel_model, model_ids_chunk)
            pusher.trigger(channels, event, data, socket_id)
    except:
        # Ignore the error. We would rather save the object to the 
        # database and not send it out to clients in realtime than
        # fail at both.
        logger.error('Pusher send failed, evt: %s, model: %s, datalen: %d', event, channel_model+str(model_ids[0]), len(str(data)), exc_info=True)
   
try_pusher_page_send = functools.partial(try_pusher_send, 'page')
try_pusher_user_send = functools.partial(try_pusher_send, 'user')


def make_permission(channel_name, socket_id, args=None):
    pusher = make_pusher()
    return pusher.authenticate(socket_id, channel_name, args)
