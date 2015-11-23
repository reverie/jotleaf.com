from django.db import models

from uuidfield import UUIDField

class ModelMixins(object):
    def really_absolute_url(self):
        from main.templatetags.main_tags import make_path_absolute
        return make_path_absolute(self.get_absolute_url())

class BaseModel(models.Model, ModelMixins):
    id = UUIDField(primary_key=True, auto=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True, db_index=True)

    class Meta:
        abstract = True

