from django.db.models import get_models, get_app
from django.contrib import admin
from django.contrib.admin.sites import AlreadyRegistered

# from http://djangosnippets.org/snippets/2066/
def autoregister(*app_list):
    for app_name in app_list:
        app_models = get_app(app_name)
        for model in get_models(app_models):
            try:
                admin.site.register(model)
            except AlreadyRegistered:
                pass

autoregister('main')



# from http://stackoverflow.com/questions/2270537/how-to-customize-the-auth-user-admin-page-in-django-crud
from django.contrib.auth.admin import UserAdmin


from django.contrib.auth import get_user_model

UserAdmin.list_display = ['username', 'email', 'date_joined', 'is_active', 'is_staff']
UserAdmin.ordering = ['-date_joined']

admin.site.unregister(get_user_model())
admin.site.register(get_user_model(), UserAdmin)

