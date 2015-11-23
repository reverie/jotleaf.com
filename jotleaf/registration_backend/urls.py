"""
Copied from registration.backends.simple.urls 
"""

from django.conf.urls import patterns, url, include

from registration.views import register

MY_BACKEND = 'registration_backend.backend.JotleafBackend'

urlpatterns = patterns('',
   url(
       r'^register/$',
       register,
       {'backend': MY_BACKEND},
       name='registration_register'
   ),
   (r'', include('registration.auth_urls')),
)



