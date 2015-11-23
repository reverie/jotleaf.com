import itertools
from functools import partial

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.core.urlresolvers import reverse
from django.db import models
from common.shortcuts import utc_now
from common.models import BaseModel, ModelMixins

class Choices(object):
    """
    Takes a list of (int value, str shortname, str description)
    """
    def __init__(self, choices_list):
        self.choices = []
        for value, shortname, description in choices_list:
            self.choices.append((value, description))
            setattr(self, shortname, value)

# Integer values aligned with XMPP affiliation values
PERMISSIONS_CHOICES = Choices([
    (1, 'OWNER', 'Only me'),
    (3, 'MEMBER', 'Only members'),
    (5, 'PUBLIC', 'Anyone')
])

# TODO: DRY with TutorialView
DEFAULT_FG_COLOR = '#000'
DEFAULT_PAGE_BG_COLOR = '#F5EDE1'
DEFAULT_TEXT_BG_COLOR = ''
DEFAULT_BG_TEXTURE = 'light_wool_midalpha.png'
DEFAULT_FONT_SIZE = 24

PageStyleCharField = partial(models.CharField, max_length=32, blank=True)
BGTextureField = partial(PageStyleCharField, max_length=1024) # Big enough to hold URLs
ColorField = partial(PageStyleCharField, default=DEFAULT_FG_COLOR)
BGColorField = partial(PageStyleCharField, default=DEFAULT_TEXT_BG_COLOR)
FontSizeField = partial(models.PositiveIntegerField, blank=True, null=True, default=DEFAULT_FONT_SIZE)
PermissionsField = partial(models.IntegerField, choices=PERMISSIONS_CHOICES.choices)

TITLE_MAX_LENGTH = 100

class Page(BaseModel):
    SHORTNAME = 'page'
    # Creator info
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, blank=True, null=True)
    creator_session_id = models.CharField(max_length=32, blank=True, null=True)
    creator_ip = models.IPAddressField(blank=True, null=True)

    # Permissions
    #  - A published page is viewable by everyone, and listed on your profile
    #  - An unpublished page is only viewable by members, and is not listed on your profile
    published = models.BooleanField(default=False)
    published_at = models.DateTimeField(db_index=True, null=True) # time *first* published
    text_writability = PermissionsField(default=PERMISSIONS_CHOICES.MEMBER)
    image_writability = PermissionsField(default=PERMISSIONS_CHOICES.MEMBER)

    # Title & URL
    title = models.CharField(max_length=TITLE_MAX_LENGTH)
    short_url = models.SlugField(blank=True, null=True)

    # Background. Precedence: function > texture > color
    bg_color = PageStyleCharField(default=DEFAULT_PAGE_BG_COLOR)
    bg_texture = BGTextureField(default=DEFAULT_BG_TEXTURE)
    bg_fn = PageStyleCharField()

    # TextItem/Comment Appearance Defaults
    default_textitem_color = ColorField()
    default_textitem_bg_color = BGColorField()
    default_textitem_font_size = FontSizeField()
    default_textitem_font = PageStyleCharField(default='Arial')
    default_textitem_bg_texture = BGTextureField()

    # Different style for admins:
    use_custom_admin_style = models.BooleanField(default=False)
    admin_textitem_color = ColorField()
    admin_textitem_bg_color = BGColorField()
    admin_textitem_font_size = FontSizeField()
    admin_textitem_bg_texture = BGTextureField()
    admin_textitem_font = PageStyleCharField()

    def __unicode__(self):
        return self.title + " owned by " + unicode(self.owner_id)

    def get_absolute_url(self):
        kwargs = {
            'page_identifier': self.short_url or self.id
        }
        if self.owner:
            view_name = 'show_user_page'
            kwargs['username'] = self.owner.username
        else:
            view_name = 'show_ownerless_page'
        return reverse(view_name, kwargs=kwargs)

    @classmethod
    def get_available_short_url(cls, owner, new_title):
        from django.template.defaultfilters import slugify
        base = slugify(new_title)
        taken_slugs = cls.objects.filter(owner=owner, short_url__startswith=base)
        taken_slugs = set(taken_slugs.values_list('short_url', flat=True))
        if not taken_slugs:
            return base
        for i in itertools.count(1):
            suffix = ('-%d' if base else '%d') % i
            base = base[:50-len(suffix)]
            attempt = base + suffix
            if attempt not in taken_slugs:
                return attempt

    def clear(self):
        from main.models import TextItem, ImageItem, EmbedItem
        from main.api2 import send_batch_item_deletion       
        item_ghosts = []
        for item in self.textitem_set.all():
            item_ghosts.append({'original_id': item.id, 'type': item.SHORTNAME})
        for item in self.imageitem_set.all():
            item_ghosts.append({'original_id': item.id, 'type': item.SHORTNAME})
        for item in self.embeditem_set.all():
            item_ghosts.append({'original_id': item.id, 'type': item.SHORTNAME})

        TextItem.objects.filter(page=self).delete()
        ImageItem.objects.filter(page=self).delete()
        EmbedItem.objects.filter(page=self).delete()

        send_batch_item_deletion(self, item_ghosts)
    
    def save(self, *args, **kwargs):
        if self.pk:
            old_instance = Page.objects.get(pk=self.pk)
            if self.published:
                if not old_instance.published_at and not old_instance.published:
                    self.published_at = utc_now()
        super(Page, self).save(*args, **kwargs) # Call the "real" save() method.
  

    def view_count(self):
        from main.pageviews import get_count
        return get_count(self)

    def last_inserted(self):
        items = TextItem.objects.filter(page=self).order_by('-updated_at')
        last_inserted = None
        if items:
            last_inserted = items[0]
        return last_inserted


class Item(BaseModel):
    page = models.ForeignKey(Page)

    # Creator info:
    creator = models.ForeignKey(settings.AUTH_USER_MODEL, null=True)
    creator_window_id = models.CharField(max_length=32, blank=True, null=True)
    creator_session_id = models.CharField(max_length=32, blank=True, null=True)
    creator_ip = models.IPAddressField(blank=True, null=True)

    # Positioning
    x = models.IntegerField()
    y = models.IntegerField()
    # null h/w means auto-determined based on type + content
    height = models.IntegerField(null=True, blank=True)
    width = models.IntegerField(null=True, blank=True)

    # Border styles
    border_color = models.CharField(max_length=32, blank=True)
    border_width = models.PositiveIntegerField(blank=True, null=True)
    border_radius = models.PositiveIntegerField(blank=True, null=True)

    def __unicode__(self):
        cls = self.__class__.__name__
        s = cls
        s += " at (%s, %s)" % (self.x , self.y)
        if self.page_id:
            s += " on page " + unicode(self.page_id)
        return s

    def get_absolute_url(self):
        page = Page.objects.get(id=self.page_id)
        pageUrl = page.get_absolute_url()
        url = "{page_url}item-{id}/".format(page_url=pageUrl, id=self.id)
        return url

    class Meta:
        abstract = True


class TextItem(Item):
    SHORTNAME = 'text'

    content = models.TextField(blank=True)
    editable = models.BooleanField(default=False)
    link_to_url = models.TextField(blank=True)

    # Appearance
    color = models.CharField(max_length=32, blank=True)
    bg_color = models.CharField(max_length=32, blank=True)
    bg_texture = models.CharField(max_length=32, blank=True)
    font_size = models.PositiveIntegerField(blank=True, null=True)
    font = PageStyleCharField()

class ImageItem(Item):
    SHORTNAME = 'image'

    src = models.CharField(max_length=1000)
    link_to_url = models.TextField(blank=True)

class EmbedItem(Item):
    SHORTNAME = 'embed'

    original_url = models.TextField(blank=True)
    embedly_data = models.TextField(blank=True)

class Membership(BaseModel):
    SHORTNAME = 'membership'
    # M2M field for page membership. Making it a model because I'm sure we'll
    # want more attributes later. -ab
    page = models.ForeignKey(Page)
    user = models.ForeignKey(settings.AUTH_USER_MODEL)

    class Meta:
        unique_together = [['page', 'user']]

class PageView(BaseModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True)
    page = models.ForeignKey(Page)
    ip_address = models.IPAddressField()
    sessionid = models.CharField(max_length=32, blank=True, null=True)

class CustomUser(AbstractUser, ModelMixins):
    bio = models.TextField(blank=True)
    email_on_new_follower = models.BooleanField(default=True)
    email_on_new_membership = models.BooleanField(default=True)
    wants_tutorial = models.BooleanField(default=True)

    def get_absolute_url(self):
        return reverse('show_user', args=[self.username])

    def listed_pages(self):
        return self.page_set.filter(published=True)

    def sample_pages(self):
        return self.listed_pages().order_by('-published_at')[:3]

    def delete_user(self):
        # TODO: delete this?
        import string
        from django.utils.crypto import get_random_string
        for p in self.page_set.all():
            p.delete()
        new_username = 'deleted_' + get_random_string(16, string.lowercase) + '_' + self.username
        self.username = new_username
        self.email = 'andrewbadr.etc+jotleaf_deleted@gmail.com'
        self.set_unusable_password()
        self.save()

    @classmethod
    def get_user(cls, username):
        cls.objects.get(username__iexact=username)

    @classmethod
    def delete_username(cls, username):
        cls.delete_user(cls.get_user(username))

    class Meta:
        db_table = 'auth_user'

class Follow(BaseModel):
    SHORTNAME = 'follow'
    user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='friends')
    target = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='followers')

    class Meta:
        unique_together = [['user', 'target']]

    def __unicode__(self):
        return "{} follows {}".format(self.user_id, self.target_id)

class SentFollowEmail(BaseModel):
    """
    Keeps track of which e-mail notifications we have sent out
    pertaining to Follow actions.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='+')
    target = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='+')

    class Meta:
        unique_together = [['user', 'target']]

class RejectedFollowSuggestion(BaseModel):
    """
    Keeps track of which suggested follows have been rejected by a user
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='rejects')
    target = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='rejected')

    class Meta:
        unique_together = [['user', 'target']]

class SentMemberEmail(BaseModel):
    """
    Keeps track of which e-mail notifications we have sent out
    pertaining to adding users as members of a page.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='+')
    page = models.ForeignKey(Page, related_name='+')

    class Meta:
        unique_together = [['user', 'page']]

