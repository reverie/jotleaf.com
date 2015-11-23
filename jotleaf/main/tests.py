import datetime
import json
import functools
import pdb
import sys
from urlparse import urlparse

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from django.core.urlresolvers import reverse
from django.test import TestCase
from django.test import LiveServerTestCase
from django.test.client import FakePayload

from selenium.webdriver import ActionChains
from selenium.webdriver.firefox.webdriver import WebDriver
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.common.keys import Keys

from common.shortcuts import utc_now, time_ago
from main.models import Page, TextItem, ImageItem, EmbedItem, Membership, Follow

User = get_user_model()

EMAIL = 'andrew+testsuite@jotleaf.com'

def debug_on(*exceptions):
    # From http://stackoverflow.com/questions/4398967/python-unit-testing-automatically-running-the-debugger-when-a-test-fails
    if not exceptions:
        exceptions = (AssertionError, )
    def decorator(f):
        @functools.wraps(f)
        def wrapper(*args, **kwargs):
            try:
                return f(*args, **kwargs)
            except exceptions:
                pdb.post_mortem(sys.exc_info()[2])
        return wrapper
    return decorator


def get_url_path(url):
    return urlparse(url).path

class FrontPage(TestCase):
    def test_frontpage(self):
        """
        Frontpage works unauthenticated and does not print to stdout.
        """
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)

class UserTrackingMixin(object):
    # note: must come first in parent list, b/c unittest.TestCase.__init__
    # doesn't call super()
    def __init__(self, *args, **kwargs):
        super(UserTrackingMixin, self).__init__(*args, **kwargs)
        self.users = {}
        self.passwords = {}

    def create_user(self, username, password):
        self.passwords[username] = password
        new_user = User.objects.create_user(username, email=username+EMAIL, password=password)
        self.users[username] = new_user
        return new_user


class JLTest(UserTrackingMixin, TestCase):
    def login(self, user):
        self.assertTrue(self.client.login(username=user.username, password=self.passwords[user.username]))

class APITest(JLTest):
    WINDOW_ID = '12345'
    SOCKET_ID = '54321'

    def setUp(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.user = self.create_user('user1', 'user1pass')
        self.user2 = self.create_user('user2', 'user2pass')
        self.user3 = self.create_user('user3', 'user3pass')

        self.user.is_active = True
        self.user.save()
        self.page = Page.objects.create(
            owner=self.user,
            title='Some Test Page',
            published=True,
            text_writability=PC.MEMBER,
            image_writability=PC.MEMBER,
        )
        self.page2 = Page.objects.create(
            owner=self.user,
            title='Once Upon a Time',
            published=True,
            text_writability=PC.MEMBER,
            image_writability=PC.MEMBER,
        )

        Membership.objects.create(page=self.page, user=self.user3)

        # First key is the page writability property
        # Second key is the user affiliation to the page
        # The value is the canCreate() value
        self.writabilityPermissions = {
            PC.OWNER: {
                AFF.OWNER: True,
                AFF.MEMBER: False,
                AFF.NONE:  False,
            },
            PC.MEMBER: {
                AFF.OWNER: True,
                AFF.MEMBER: True,
                AFF.NONE:  False,
            },
            PC.PUBLIC: {
                AFF.OWNER: True,
                AFF.MEMBER: True,
                AFF.NONE:  True,
            }
        }

    def setup_item_writes(self):
        import string
        from random import choice
        path = '/api/v2/textitem/'
        args = dict(
            editable=False,
            expandDir='y',
            selectable=True,
            x=100,
            y=200,
            width=300,
            height=400,
            page_id=self.page.id
        )
        content = ''.join([choice(string.lowercase) for i in range(50)])
        args['content'] = content
        return path, args

    def setup_imageitem_writes(self):
        path = '/api/v2/imageitem/'
        args = dict(
            x=500,
            y=600,
            src='http://dummyimage.com/60x40/000/fff.jpg',
            page_id=self.page.id
        )
        return path, args

    def setup_embeditem_writes(self):
        path = '/api/v2/embeditem/'
        args = dict(
            x=200,
            y=300,
            original_url='http://www.youtube.com/watch?v=9bZkp7q19f0',
            page_id=self.page.id
        )
        return path, args

    def _can_insert_textitem(self, page, user=None):
        path, args = self.setup_item_writes()
        if user:
            self.login(user)
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(TextItem.objects.count(), 1)
        ti = TextItem.objects.get()
        self.assertEqual(ti.creator, user)
        self.assertEqual(ti.content, args['content'])
        return True

    def _can_insert_imageitem(self, page, user=None):
        path, args = self.setup_imageitem_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(ImageItem.objects.count(), 1)
        ii = ImageItem.objects.get()
        self.assertEqual(ii.creator, user)
        self.assertEqual(ii.src, args['src'])
        return True

    def _can_insert_embeditem(self, page, user=None):
        path, args = self.setup_embeditem_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(EmbedItem.objects.count(), 1)
        ei = EmbedItem.objects.get()
        self.assertEqual(ei.creator, user)
        self.assertEqual(ei.original_url, args['original_url'])
        return True

    def _cannot_insert_textitem(self, page, user=None):
        path, args = self.setup_item_writes()
        if user:
            self.login(user)
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(TextItem.objects.count(), 0)
        return True

    def _cannot_insert_imageitem(self, page, user=None):
        path, args = self.setup_imageitem_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(ImageItem.objects.count(), 0)
        return True     

    def _cannot_insert_embeditem(self, page, user=None):
        path, args = self.setup_embeditem_writes()
        if user:
            self.login(user)
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(EmbedItem.objects.count(), 0)
        return True

    def _make_custom_api_request(self, path, args, method):
        full_args = {
            'meta': {
                'window_id': self.WINDOW_ID,
                'socket_id': self.SOCKET_ID
            },
        }
        full_args.update(args)
        body = json.dumps(full_args)
        kwargs = {
            'content_type': 'application/json',
            'wsgi.input':FakePayload(body), 
            'CONTENT_LENGTH':len(body)
        }
        return getattr(self.client, method)(path, **kwargs)

    def _make_api_request(self, path, args, method):
        # This method came first, now it's a thin wrapper
        # around the generalized _make_custom...
        # Should probably be renamed.
        return self._make_custom_api_request(
                path, 
                {'model': args},
                method)

    def make_api_post(self, path, args):
        return self._make_api_request(path, args, 'post')

    def make_api_put(self, path, args):
        return self._make_api_request(path, args, 'put')

    def make_api_delete(self, path):
        return self._make_api_request(path, {}, 'delete')

    def test_page_reads(self):
        # Set up request
        path = "/api/v2/page/%s/" % self.page.id
        request = [path, {'format': 'json'}]

        # Test unauthenticated
        response = self.client.get(*request)
        self.assertEqual(response.status_code, 200)
        json.loads(response.content)

        # Test authenticated
        self.login(self.user)
        response = self.client.get(*request)
        self.assertEqual(response.status_code, 200)
        json.loads(response.content)

    def test_internal_viewer(self):
        from main.api2 import make_internal_signature

        # Set up client and page permissions
        path = "/api/v2/page/%s/" % self.page.id
        request = [path, {'format': 'json'}]
        self.page.published = False
        self.page.save()

        # Set up internal viewer
        now = utc_now()
        timestamp = now.isoformat()
        real_signature = make_internal_signature(timestamp)
        old_timestamp = (now - datetime.timedelta(days=1)).isoformat()
        old_signature = make_internal_signature(old_timestamp)
        user_agent_fmt = "Jotleaf-Internal|%s|%s"
        good_user_agent = user_agent_fmt % (timestamp, real_signature)
        old_user_agent  = user_agent_fmt % (old_timestamp, old_signature)
        bad_user_agent = user_agent_fmt % (timestamp, "someBadSignature")

        # Test w/good user agent
        headers = {'HTTP_USER_AGENT': good_user_agent}
        response = self.client.get(*request, **headers)
        self.assertEqual(response.status_code, 200)
        json.loads(response.content)

        # Test w/old user agent
        headers = {'HTTP_USER_AGENT': old_user_agent}
        response = self.client.get(*request, **headers)
        self.assertEqual(response.status_code, 403)

        # Test w/bad user-agent
        headers = {'HTTP_USER_AGENT': bad_user_agent}
        response = self.client.get(*request, **headers)
        self.assertEqual(response.status_code, 403)


    def test_creator_fields(self):
        self.login(self.user)

        # Test on a page
        path = "/api/v2/page/%s/" % self.page.id
        response = self.client.get(path)
        self.assertEqual(response.status_code, 200)
        result = json.loads(response.content)
        self.assertNotIn('creator_session_id', result)
        self.assertNotIn('creator_ip', result)

        # Make an item
        path, args = self.setup_item_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200)
        ti = TextItem.objects.get()

        # Fetch the item
        path = '/api/v2/textitem/%s/' % ti.id
        response = self.client.get(path)
        self.assertEqual(response.status_code, 200)
        result = json.loads(response.content)

        # Check for hidden fields
        self.assertEqual(result['creator_id'], self.user.id)
        self.assertEqual(result['creator_window_id'], self.WINDOW_ID)
        self.assertNotIn('creator_session_id', result)
        self.assertNotIn('creator_ip', result)

    def test_unauthenticated_textitem_member_writability(self):
        path, args = self.setup_item_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(TextItem.objects.count(), 0)

    def test_unauthenticated_textitem_public_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        self.page.text_writability = PC.PUBLIC
        self.page.save()
        self.assertTrue(self._can_insert_textitem(self.page))

    def test_link_to_url(self):
        path, args = self.setup_item_writes()
        self.login(self.user)
        URL = 'http://www.google.com/'
        args['link_to_url'] = URL
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(TextItem.objects.count(), 1)
        ti = TextItem.objects.get()
        self.assertEqual(ti.link_to_url, URL)

    def test_nonadmin_link_to_url(self):
        from main.models import PERMISSIONS_CHOICES as PC
        path, args = self.setup_item_writes()
        self.page.text_writability = PC.PUBLIC
        self.page.save()
        URL = 'http://www.google.com/'
        args['link_to_url'] = URL
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(TextItem.objects.count(), 1)
        ti = TextItem.objects.get()
        self.assertEqual(ti.link_to_url, '')

    def _get_user_with_affiliation(self, affiliation, authenticated=True):
        from main.permissions import Affiliation as AFF
        user = self.user
        if affiliation == AFF.OWNER:
            user = self.user
        elif affiliation == AFF.MEMBER:
            user = self.user3
            if authenticated:
                self.login(user) 
        else:
            user = None

        return user


    def _test_writability_with_affiliation(self, itemtype, writability_val, affiliation, authenticated=True):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        if itemtype == 'embed':
            writability_property = 'image_writability'
        else:
            writability_property = "{}_writability".format(itemtype)

        if writability_property and hasattr(self.page, writability_property):
            setattr(self.page, writability_property, writability_val)

        self.page.save()
        user = self._get_user_with_affiliation(affiliation, authenticated)
        expected = self.writabilityPermissions[writability_val][affiliation]
        negation = "" if expected else "not" 
        assertion_method = "_can{}_insert_{}item".format(negation, itemtype)
        actual = getattr(self, assertion_method)(self.page, user)
        self.assertTrue(actual)
        return True



    def test_authenticated_textitem(self):
        self.assertTrue(self._can_insert_textitem(self.page, self.user))

    def test_unaffiliated_unauthenticated_textitem_public_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("text", PC.PUBLIC, AFF.NONE))

    def test_unaffiliated_unauthenticated_textitem_member_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("text", PC.MEMBER, AFF.NONE))

    def test_unaffiliated_unauthenticated_textitem_owner_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("text", PC.OWNER, AFF.NONE))

    def test_member_authenticated_textitem_public_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("text", PC.PUBLIC, AFF.MEMBER))

    def test_member_authenticated_textitem_member_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("text", PC.MEMBER, AFF.MEMBER))

    def test_member_authenticated_textitem_owner_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("text", PC.OWNER, AFF.MEMBER))

    def test_unaffiliated_unauthenticated_imageitem_public_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("image", PC.PUBLIC, AFF.NONE))

    def test_unaffiliated_unauthenticated_imageitem_member_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("image", PC.MEMBER, AFF.NONE))

    def test_unaffiliated_unauthenticated_imageitem_owner_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("image", PC.OWNER, AFF.NONE))

    def test_member_authenticated_imageitem_public_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("image", PC.PUBLIC, AFF.MEMBER))

    def test_member_authenticated_imageitem_member_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("image", PC.MEMBER, AFF.MEMBER))

    def test_member_authenticated_imageitem_owner_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("image", PC.OWNER, AFF.MEMBER))

    def test_unaffiliated_unauthenticated_embeditem_public_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("embed", PC.PUBLIC, AFF.NONE))

    def test_unaffiliated_unauthenticated_embeditem_member_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("embed", PC.MEMBER, AFF.NONE))

    def test_unaffiliated_unauthenticated_embeditem_owner_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("embed", PC.OWNER, AFF.NONE))

    def test_member_authenticated_embeditem_public_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("embed", PC.PUBLIC, AFF.MEMBER))

    def test_member_authenticated_embeditem_member_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("embed", PC.MEMBER, AFF.MEMBER))

    def test_member_authenticated_embeditem_owner_writability(self):
        from main.models import PERMISSIONS_CHOICES as PC
        from main.permissions import Affiliation as AFF
        self.assertTrue(self._test_writability_with_affiliation("embed", PC.OWNER, AFF.MEMBER))

    def test_member_unauthenticated_imageitem(self):
        # Make page private
        from main.models import PERMISSIONS_CHOICES as PC
        self.page.published = False
        self.page.text_writability = PC.MEMBER
        self.page.save()

        # Give user2 access
        Membership.objects.create(page=self.page, user=self.user2)

        # Make sure user2 cannot add images on the private page if not logged in
        path, args = self.setup_imageitem_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(ImageItem.objects.count(), 0)

    def test_unauthenticated_imageitem(self):
        path, args = self.setup_imageitem_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(ImageItem.objects.count(), 0)

    def test_authenticated_textitem_restricted_vals(self):
        path, args = self.setup_item_writes()
        self.login(self.user)
        args['id'] = "c"*32
        args['created_at'] = "2012-07-30T13:45:48.151746"
        args['updated_at'] = "2012-07-30T13:45:48.151746"
        args['behavior'] = 'function(){alert("fail");}'
        args['inputs'] = '["foo"]'
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(TextItem.objects.count(), 1)
        ti = TextItem.objects.get()
        self.assertNotEqual(ti.id, args['id'])
        self.assertNotEqual(ti.created_at.isoformat(), args['created_at'])
        self.assertNotEqual(ti.updated_at.isoformat(), args['updated_at'])

    def test_assign_page_owner(self):
        self.login(self.user)
        path = '/api/v2/page/%s/' % self.page.id
        args = {
            'owner': {'id': self.user2.id}
        }
        response = self.make_api_put(path, args)
        page = Page.objects.get(id=self.page.id)
        self.assertEqual(page.owner_id, self.user.id) # Make sure we can't assign it to a different user

    def test_assign_item_page(self):
        self.login(self.user)

        # Make an item
        path, args = self.setup_item_writes()
        response = self.make_api_post(path, args)
        self.assertEqual(response.status_code, 200, "Couldn't create TextItem")
        ti = TextItem.objects.get()

        # Reassign the item's page
        path = '/api/v2/textitem/%s/' % ti.id
        args = {
            'page_id': {'id': self.page2.id}
        }
        response = self.make_api_put(path, args)
        self.assertEqual(response.status_code, 200, "Couldn't edit TextItem")

        # Make sure it wasn't changed
        ti = TextItem.objects.get(id=ti.id)
        self.assertEqual(ti.page_id, self.page.id)

    def test_cant_copy_page(self):
        # There was an issue where you could copy the attributes of
        # someone else's page if you knew its id. This test is to
        # make sure that's not possible.

        self.login(self.user)

        uid = self.user.id

        # Test POST
        path = '/api/v2/page/'
        args = {
            'id': self.page.id,
            'owner_id': uid,
            'owner': {'id': uid}
        }
        response = self.make_api_post(path, args)
        self.assertEqual(Page.objects.filter(title=self.page.title).count(), 1)

        # Test PUT
        path = '/api/v2/page/%s/' % self.page.id
        args = {
            'id': self.page2.id, # N.B. page2
        }
        response = self.make_api_put(path, args)
        p1 = Page.objects.get(id = self.page.id)
        p2 = Page.objects.get(id = self.page2.id)
        self.assertNotEqual(p1.title, p2.title)

    def _try_search(self, search_params):
        path = '/api/v2/user/search/'
        data = {
            'search_params': search_params
        }
        return self._make_custom_api_request(path, data, 'post')

    def test_good_search(self):
        response = self._try_search(
                [['username', 'iexact', self.user.username.upper()]])
        self.assertEqual(response.status_code, 200)
        user_data = json.loads(response.content)
        self.assertEqual(len(user_data), 1)
        user = user_data[0]
        self.assertEqual(user['id'], self.user.id)

    def test_bad_search(self):
        response = self._try_search(
                [['username', 'id', self.user.id]])
        self.assertEqual(response.status_code, 403)
        self.assertNotIn(str(self.user.id), response.content)

    def test_get_page_affiliation_anon(self):
        from main.permissions import FullUser, get_page_affiliation, Affiliation
        anon_fu = FullUser(
            AnonymousUser(),
            '1.2.3.4',
            'some_session_key',
            'some_window_id',
            set(),
        )
        affil = get_page_affiliation(anon_fu, self.page)
        self.assertEqual(affil, Affiliation.NONE)
  
    def test_get_page_affiliation_lazyuser(self):
        """
        Test for when the 'user' field is a SimpleLazyObject, as would
        be gotten from request.user.
        """
        from django.utils.functional import SimpleLazyObject
        from main.permissions import FullUser, get_page_affiliation, Affiliation

        # Authenticated case
        auth_fu = FullUser(
            SimpleLazyObject(lambda: self.user),
            '1.2.3.4',
            'some_session_key',
            'some_window_id',
            set(),
        )
        affil = get_page_affiliation(auth_fu, self.page)
        self.assertEqual(affil, Affiliation.OWNER)

        # Anon case
        anon_fu = FullUser(
            SimpleLazyObject(lambda: AnonymousUser()),
            '1.2.3.4',
            'some_session_key',
            'some_window_id',
            set(),
        )
        affil = get_page_affiliation(anon_fu, self.page)
        self.assertEqual(affil, Affiliation.NONE)

    def test_page_deletion(self):
        orig_num_pages = Page.objects.count()
        path = '/api/v2/page/%s/' % self.page.id
        self.login(self.user)
        response = self.make_api_delete(path)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Page.objects.count(), orig_num_pages - 1)

    def test_newsfeed_contents(self):
        Follow.objects.create(user=self.user, target=self.user2)
        p1 = Page.objects.create(owner=self.user3, published=False)
        p2 = Page.objects.create(owner=self.user3, published=False)
        p3 = Page.objects.create(owner=self.user3, published=True)
        Membership.objects.create(user=self.user, page=p1)
        Membership.objects.create(user=self.user2, page=p1)
        Membership.objects.create(user=self.user2, page=p2)
        for i, p in enumerate([p1, p2, p3]):
            TextItem.objects.create(x=0, y=0, creator=self.user2, page=p,
                    content=str(i)*5 )
        self.login(self.user)
        path = '/xhr/news-feed/'
        response = self.client.get(path)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(json.loads(response.content)['success'])

        # You see news about an unpublished page that you're a member of
        self.assertTrue('00000' in response.content)

        # But not if you *aren't* a member
        self.assertFalse('11111' in response.content)

        # You see news about a published page
        self.assertTrue('22222' in response.content)

class WebsiteTest(JLTest):
    def setUp(self):
        self.USERNAME, self.PASSWORD = 'bobross', 'rosspass'
        self.user = self.create_user(self.USERNAME, password=self.PASSWORD)
        self.user.is_active = True
        self.user.save()
        self.user2 = self.create_user('bono', password='only2b')

    def test_multi_membership_page_listing(self):
        from main.models import PERMISSIONS_CHOICES as PC

        # This was throwing an exception, DatabaseError with
        # "more than one row returned by a subquery used as an expression".
        # Reconfiguring ORM use to fix it.
        # NB does not fail on sqlite, only postgres viewer = self.user
        viewer = self.user
        owner = self.user2
        p1 = Page.objects.create(
                owner=owner,
                title='Foo')
        p2 = Page.objects.create(
                owner=owner,
                title='Quick Page')
        Membership.objects.create(
            page=p1,
            user=viewer)
        Membership.objects.create(
            page=p2,
            user=viewer)
        self.login(self.user)
        r = self.client.get(reverse('show_user', args=[owner.username]))
        self.assertEqual(r.status_code, 200)

class JLSeleniumTest(UserTrackingMixin, LiveServerTestCase):
    # Abstract helper for selenium classes
    @classmethod
    def setUpClass(cls):
        cls.selenium = WebDriver()
        cls.actions = ActionChains(cls.selenium)
        super(JLSeleniumTest, cls).setUpClass()

    @classmethod
    def tearDownClass(cls):
        cls.selenium.quit()
        super(JLSeleniumTest, cls).tearDownClass()

    def setUp(self):
        self.USERNAME, self.PASSWORD = 'bobross', 'rosspass'
        
        self.user = User.objects.create_user(self.USERNAME, email=EMAIL, password=self.PASSWORD)
        self.user.is_active = True
        self.user.save()
        user = self.create_user('user1', 'user1pass')
        user.is_active = True
        user.save()
        self.selenium.delete_all_cookies()
        self.selenium.implicitly_wait(1)

        # Hacky: clear actions chain between tests.
        # Better: create and attach a new ActionChain instance instead?
        self.actions._actions = []

        # Navigate to a blank page. This ensures that when a test navigates somewhere and
        # then looks for an element, it isn't finding that element on a previously-loaded
        # page that just hasn't been unloaded yet.
        self.selenium.get('about:blank')
        self._wait_for_none('body')
        
    def navigate_to_path(self, path):
        self.selenium.get('%s%s' % (self.live_server_url, path))

    def navigate_to_urlpattern(self, pattern_name, args=None, kwargs=None):
        path = reverse(pattern_name, args=args, kwargs=kwargs)
        self.navigate_to_path(path)

    def get_current_url_path(self):
        return get_url_path(self.selenium.current_url)

    def _set_input_value(self, name, value):
        _input = self.selenium.find_element_by_name(name)
        _input.send_keys(value)
        return _input

    def _find(self, selector):
        # Just a shortcut
        return self.selenium.find_elements_by_css_selector(selector)

    def _find_visible(self, selector):
        elements = self.selenium.find_elements_by_css_selector(selector)
        return [e for e in elements if e.is_displayed()]

    def _get_js_val(self, val_str):
        return self.selenium.execute_script("return " + val_str)

    def _get_one(self, selector):
        matches = self._find(selector)
        self.assertEqual(len(matches), 1)
        return matches[0]

    def _find_with_text(self, selector, text):
        """
        Returns the elements matching `selector` with
        strip()ped text equal to `text`.
        """
        stripped = text.strip()
        elements = self.selenium.find_elements_by_css_selector(selector)
        return [e for e in elements if e.text.strip() == stripped]

    def _find_one_with_text(self, selector, text):
        matches = self._find_with_text(selector, text)
        self.assertEqual(len(matches), 1)
        return matches[0]

    def _num_visible(self, selector):
        return len(self._find_visible(selector))

    def _wait_for(self, selector):
        WebDriverWait(self.selenium, 10).until(
            lambda driver: self._num_visible(selector)
        )

    def _wait_and_get_one(self, selector):
        self._wait_for(selector)
        return self._get_one(selector)

    def _wait_for_any(self, selectors):
        WebDriverWait(self.selenium, 10).until(
            lambda driver: any(self._num_visible(s) for s in selectors)
        )

    def _wait_for_none(self, selectors):
        WebDriverWait(self.selenium, 10).until(
            lambda driver: not any(self._num_visible(s) for s in selectors)
        )

    def login(self, user=None):
        if (user is None) or user.username == self.USERNAME:
            username = self.USERNAME
            password = self.PASSWORD
        else:
            username = user.username
            password = self.passwords[username]

        self.selenium.get(self.live_server_url)
        self.assertTrue(self.client.login(username=username, password=password))
        self.selenium.add_cookie({
            'name': 'sessionid',
            'value': self.client.cookies['sessionid'].value
        })

    def _make_quick_page(self):
        self.navigate_to_path('/new')
        self._wait_for_any(['.page-view'])

    def _make_and_navigate_to_page(self):
        page = Page.objects.create(owner=self.user)
        # make it older, so that the menu doesn't auto-open
        page.created_at = time_ago(days=1)
        page.save()
        page_url = page.get_absolute_url()
        self.selenium.get('%s%s' % (self.live_server_url, page_url))
        return page

    def _drag(self, item, move_x=-200, move_y=-200):
        self.actions.move_to_element(item).click_and_hold()
        self.actions.move_by_offset(move_x, move_y).release()
        self.actions.perform()
        self.actions._actions = []


class MainWebsiteSelenium(JLSeleniumTest):
    def test_pages_page_options(self):
        self.login()
        Page.objects.create(owner=self.user)
        self.navigate_to_urlpattern('pages')
        self._wait_for_any(['body.pages'])
        opt_btn = self._get_one('.options-button')
        opt_btn.click()
        self._get_one('.page_options')

    def test_pages_page_listing(self):
        self.login()
        self.navigate_to_urlpattern('pages')
        self.assertEqual(self._num_visible('div.msg'), 1)
        self.assertEqual(self._num_visible('div.page-listing'), 0)
        page_title = 'Some Test Page'
        self.page = Page.objects.create(
            owner=self.user,
            title=page_title)
        self.selenium.refresh()
        self.assertEqual(self._num_visible('div.msg'), 0)
        self.assertEqual(self._num_visible('div.page-listing'), 1)
        self.assertEqual(self._num_visible('div.page-title'), 1)
        title = self._get_one('div.page-title')
        self.assertEqual(title.text, page_title)

    def test_create_page(self):
        self.login()
        self.navigate_to_urlpattern('home')
        page_title = 'Yet Another Page Title!'
        create_page_input = self._get_one('.title-input')
        create_page_input.send_keys(page_title, Keys.RETURN)
        WebDriverWait(self.selenium, 10).until(
            # Wait for page to be created
            lambda driver: (Page.objects.count() and
            Page.objects.order_by('-created_at')[0].title == page_title)
        )
        page = Page.objects.order_by('-created_at')[0]
        target_path = page.get_absolute_url()
        self.assertEqual(target_path, self.get_current_url_path())
        # Hackish way of making sure the JS loaded:
        self.selenium.find_element_by_class_name('tilingcanvas-canvas')

    def try_login(self, username, password):
        self.navigate_to_urlpattern('auth_login')
        self._set_input_value('username', username)
        self._set_input_value('password', password).submit()
        self._wait_for_any(['body.home', 'ul.errors'])

    def test_login_logout(self):
        home_url_path = reverse('home')

        # Unsuccessful login
        self.try_login(self.USERNAME, 'NOT THE PASSWORD')
        self.navigate_to_urlpattern('home')
        self.assertNotEqual(self.get_current_url_path(), home_url_path)

        # Successful login
        self.try_login(self.USERNAME, self.PASSWORD)
        self.navigate_to_urlpattern('home')
        self.assertEqual(self.get_current_url_path(), home_url_path)

        # Logout
        self._get_one('.auth-dropdown .dropdown-toggle').click()
        self._get_one('.authorized-logout').click()
        self.navigate_to_urlpattern('home')
        self.assertNotEqual(self.get_current_url_path(), home_url_path)

    def _submit_register_form(self, username, password, email):
        self._set_input_value('username', username)
        self._set_input_value('password', password)
        self._set_input_value('email', email).submit()
        self._wait_for_any(['body.home', 'ul.errors'])

    def _test_register(self, urlpattern):
        self.navigate_to_urlpattern(urlpattern)
        self._submit_register_form('test_username', 'some_fine_password', EMAIL)
        self.assertEqual(self.get_current_url_path(), reverse('home'))
        self._find_one_with_text('.messages', 'Congratulations, you have successfully registered!')

    def test_register_from_registration(self):
        self._test_register('registration_register')

    def test_register_from_index(self):
        self._test_register('index')

    def test_registration_errors(self):
        self.navigate_to_urlpattern('index')
        self._submit_register_form('dd', '', 'd')
        for error in [
            'Ensure this value has at least 3 characters (it has 2).',
            'This field is required.',
            'Enter a valid email address.'
            ]:
            self._find_one_with_text('li.error-message', error)

    def test_password_reset(self):
        from django.core import mail
        del mail.outbox[:]
        self.navigate_to_urlpattern('pwd_reset')
        self._set_input_value('email', EMAIL).submit()
        self._wait_for_any(['.landing-page'])
        self.assertTrue(len(mail.outbox) > 0)
        body = mail.outbox[0].body
        self.assertTrue(len(body) > 0)
        import re
        
        pathMatch = re.search("/account/password/reset/confirm/[^/]+/", body)
        self.assertTrue(pathMatch)
        path = pathMatch.group()
        
        self.navigate_to_path(path)
        self._wait_for_any(['.password_reset_confirm'])

        NEWPASS = 'fablooey'
        self._set_input_value('new_password1', NEWPASS)
        self._set_input_value('new_password2', NEWPASS).submit()
        self._wait_for_any(['.landing-page'])
        self.assertFalse(self.client.login(username=self.USERNAME, password=self.PASSWORD))
        self.assertTrue(self.client.login(username=self.USERNAME, password=NEWPASS))

    def test_quick_page(self):
        self._make_quick_page()
        p = Page.objects.get()
        new_path = self.get_current_url_path()
        self.assertEqual(new_path, p.get_absolute_url())

    def test_publish_button(self):
        p = Page.objects.create(owner=self.user)
        get_page_published = lambda: Page.objects.get(id=p.id).published
        self.assertFalse(get_page_published())
        self.login()
        self.navigate_to_urlpattern('pages')
        self._wait_for_any(['body.pages'])
        opt_btn = self._get_one('.options-button')
        opt_btn.click()
        self._get_one('button.published').click()
        WebDriverWait(self.selenium, 10).until(lambda driver: get_page_published())

class LeafViewerSelenium(JLSeleniumTest):
    def _do_insertion_click(self):
        self._get_one('.tilingcanvas-canvas').click()

    def _do_insertion_entry(self, page, text):
        canvas = self._get_one('.tilingcanvas-canvas')
        content = self._get_one('.item.selected .content')
        WebDriverWait(self.selenium, 10).until(
                # Wait for element to exist and receive keys. Confirm that it
                # gets them. Slightly hacky.
                lambda driver: content.send_keys(text) or (text in
                    content.text))

        # Selenium on dev (Mac) machines, as of this writing, doesn't support
        # native events. So canvas.click() would be sufficient to "click out" of
        # the text item being inserted. The Circle CI machines are Ubuntu, which
        # do support native events, so canvas.click() doesn't actually trigger
        # on the canvas element, it triggers on whatever element is the topmost.
        # (Selenium defaults to the middle of an an element for click events.)
        # So on Circle CI, this second click causes the textitem being inserted
        # to enter "selected" mode. However, the presence of native event
        # support allows us to use ActionChains/move_by_offset, which don't work
        # on the dev platform. So the action will always be triggered on the
        # canvas element on Mac, and on Linux we're moving sufficiently far off
        # of the textitem.  Alternatively, we could just send Keys.ESCAPE to the
        # content element. (Maybe this should be a separate test.)
        move_x = content.size['width']
        move_y = content.size['height']
        self.actions.move_to_element(canvas).move_by_offset(move_x, move_y).click()
        self.actions.perform()
        self.actions._actions = []
        WebDriverWait(self.selenium, 10).until(lambda driver: page.textitem_set.exists())

    def _test_insert_textitem(self, page, text):
        orig_num_textitems = page.textitem_set.count()
        path = page.get_absolute_url()
        self.selenium.get('%s%s' % (self.live_server_url, path))
        self.assertEqual(page.textitem_set.count(), orig_num_textitems)
        self._do_insertion_click()
        self.assertEqual(page.textitem_set.count(), orig_num_textitems)
        self._do_insertion_entry(page, text)
        self.assertEqual(page.textitem_set.count(), orig_num_textitems + 1)
        ti = page.textitem_set.latest('created_at')
        self.assertEqual(ti.content, text)

    def _get_center_coordinates(self):
        return self.selenium.execute_script('return router._view._pageView.surface.getCenter()')    

    def _get_item_center_coordinates(self, item):
        getItemCenterScript = """
            var item = router._view._pageView.model.items.get(arguments[0]);
            return router._view._pageView.mapElementToCoordinates(item);
        """
        return self.selenium.execute_script(getItemCenterScript, *[item.id])    

    def _get_absolute_item_url(self, item):
        return "{0}item-{1}/".format(item.page.get_absolute_url(),item.id)

    def _is_item_centered(self, item):
        canvas_center = self._get_center_coordinates()
        item_center = self._get_item_center_coordinates(item)
        return canvas_center == item_center

    def _scroll_to_coords(self, x, y):
        self.selenium.execute_script('router._view._pageView.surface.initScrollToCoords(arguments[0],arguments[1]);',*[x, y])

    def test_youtube_link_conversion(self):
        from main.models import PERMISSIONS_CHOICES as PC
        page = Page.objects.create(
            owner=self.user,
            published=True,
            text_writability = PC.PUBLIC,
            image_writability = PC.PUBLIC
        )
        YOUTUBE_URL = 'http://www.youtube.com/watch?v=9bZkp7q19f0'
        self._test_insert_textitem(page, YOUTUBE_URL)
        popup_yes = self._get_one('.confirmation.popup .yes')
        self.assertTrue(popup_yes.is_displayed())
        self.assertEqual(1, page.textitem_set.count())
        self.assertEqual(0, page.embeditem_set.count())
        popup_yes.click()
        self._wait_for_any(['.item.embeditem'])
        self.assertEqual(0, page.textitem_set.count())
        self.assertEqual(1, page.embeditem_set.count())


    def test_direct_item_url(self):
        page = Page.objects.create(published=True)
        newitem = TextItem.objects.create(
            page=page,
            x=100,
            y=100,
            content='I am here')
        path_to_item = self._get_absolute_item_url(newitem)
        self.selenium.get('%s%s' % (self.live_server_url, path_to_item))
        
        is_centered = self._is_item_centered(newitem)
       
        self.assertTrue(is_centered)

    def _wait_until_done_scrolling(self):
        scroller = 'router._view._pageView.surface._scroller'
        has_scroller = self._get_js_val(scroller)
        self.assertTrue(has_scroller)
        scroller_done = scroller + '.done'
        WebDriverWait(self.selenium, 10).until(
                lambda driver: self._get_js_val(scroller_done))

    def test_direct_then_internal_item_link(self):
        page = Page.objects.create(published=True)
        target_item = TextItem.objects.create(
            page=page,
            x=-100,
            y=-100,
            content='I am there')

        path_to_target = self._get_absolute_item_url(target_item)
        absolute_target_url = '%s%s' % (self.live_server_url, path_to_target)
        TextItem.objects.create(
            page=page,
            x=100,
            y=100,
            content='I am here',
            link_to_url=absolute_target_url
        )

        self.selenium.get('%s%s' % (self.live_server_url, path_to_target))

        self.assertTrue(self._is_item_centered(target_item))
        self._scroll_to_coords(0, 0)
        self._wait_until_done_scrolling()
        
        self.assertEqual(self._get_center_coordinates(), [0, 0])
        self._get_one('.link-to-url').click()
        self._wait_until_done_scrolling()
        
        self.assertTrue(self._is_item_centered(target_item))
        # make sure url hasn't changed
        self.assertEqual(path_to_target, self.get_current_url_path()) 

    def test_item_link_in_page(self):
        page = Page.objects.create(published=True)
        target_item = TextItem.objects.create(
            page=page,
            x=-100,
            y=-100,
            content='I am there')

        path_to_target = self._get_absolute_item_url(target_item)
        absolute_target_url = '%s%s' % (self.live_server_url, path_to_target)
        TextItem.objects.create(
            page=page,
            x=100,
            y=100,
            content='I am here',
            link_to_url=absolute_target_url)

        page_url = page.get_absolute_url()
        self.selenium.get('%s%s' % (self.live_server_url, page_url))

        # Are we centered before clicking item link?
        coords = self._get_center_coordinates()
        self.assertEqual(coords, [0, 0])
        self._get_one('.link-to-url').click()
        # Leave some time to scroll
        self._wait_until_done_scrolling()

        self.assertTrue(self._is_item_centered(target_item))
        # make sure url hasn't changed
        self.assertEqual(page_url, self.get_current_url_path())

    def test_owner_writing(self):
        self.login()
        page = Page.objects.create(owner=self.user)
        self._test_insert_textitem(page, 'lorem ipsum')

    def test_guest_writing(self):
        """
        Makes sure that anon users can write on a page owned by someone else,
        when that permission is set.
        """
        from main.models import PERMISSIONS_CHOICES as PC
        page = Page.objects.create(
            owner=self.user,
            published=True,
            text_writability = PC.PUBLIC
        )
        self._test_insert_textitem(page, 'lorem ipsum')

    def test_delete_button(self):
        self.login()
        page = Page.objects.create(owner=self.user)
        TextItem.objects.create(
            page=page,
            content='You suck!',
            x = 0,
            y = 0
        )
        path = page.get_absolute_url() + '#admin'
        self.selenium.get('%s%s' % (self.live_server_url, path))
        self.assertEqual(page.textitem_set.count(), 1)
        content = self.selenium.find_element_by_class_name('content')
        content.click()
        deletebtn = self.selenium.find_element_by_class_name('delete-btn')
        deletebtn.click()
        self._wait_for_none(['.item'])
        self.assertFalse(self.selenium.find_elements_by_class_name('item'))
        WebDriverWait(self.selenium, 10).until(lambda driver: not page.textitem_set.exists())

    def test_options_menu_autoopen(self):
        """
        Tests that the options menu auto-opens for brand new
        pages, when you're admin and there are no items.
        """
        self.login()
        page = Page.objects.create(owner=self.user)
        path = page.get_absolute_url()
        self.selenium.get('%s%s' % (self.live_server_url, path))
        dropdown_menu_btn = self._get_one('.page-options-dropdown .dropdown-toggle')
        show_opts_btn = self._get_one('.options-btn')
        options_menu = self._get_one('.pageOptions')
        self.assertTrue(dropdown_menu_btn.is_displayed())
        self.assertFalse(show_opts_btn.is_displayed())
        self.assertTrue(options_menu.is_displayed())

    def test_options_menu(self):
        # Set up page
        self.login()
        page = Page.objects.create(owner=self.user)
        # make it older, so that the menu doesn't auto-open
        page.created_at = time_ago(days=1)
        page.save()
        path = page.get_absolute_url()
        self.selenium.get('%s%s' % (self.live_server_url, path))

        # Get elements, test initial visibility
        dropdown_menu_btn = self._get_one('.page-options-dropdown .dropdown-toggle')
        show_opts_btn = self._get_one('.options-btn')
        options_menu = self._get_one('.pageOptions')
        self.assertTrue(dropdown_menu_btn.is_displayed())
        self.assertFalse(show_opts_btn.is_displayed())
        self.assertFalse(options_menu.is_displayed())

        # Show dropdown menu
        dropdown_menu_btn.click()
        self.assertTrue(dropdown_menu_btn.is_displayed())
        self.assertTrue(show_opts_btn.is_displayed())
        self.assertFalse(options_menu.is_displayed())

        # Show options menu
        show_opts_btn.click()
        self.assertTrue(dropdown_menu_btn.is_displayed())
        self.assertFalse(show_opts_btn.is_displayed()) # menu got hidden
        self.assertTrue(options_menu.is_displayed())

        # Close options menu with close button
        close_btn = self.selenium.find_element_by_xpath("//div[@class='optionsPanel pageOptions']/button[@class='bootstrap-close']")
        close_btn.click()
        WebDriverWait(self.selenium, 10).until(
                lambda driver: not options_menu.is_displayed())

    def test_anon_page_admin(self):
        """
        Makes sure that the creator of an anonymous page (i.e. quick page) can
        set the admin options for that page, and that these options are
        correctly propagated to other users.
        """
        self._make_quick_page()

        dropdown_menu_btn = self._get_one('.dropdown-toggle')
        show_opts_btn = self._get_one('.options-btn')
        options_menu = self._get_one('.pageOptions')

        self.assertTrue(dropdown_menu_btn.is_displayed())
        dropdown_menu_btn.click()
        self.assertTrue(show_opts_btn.is_displayed())

        # Something weird related to auto-open options menu.
        # Maybe this conditional will fix it? <:)
        if not options_menu.is_displayed():
            show_opts_btn.click()
            self.assertTrue(options_menu.is_displayed())

        settings_btn = self._find_one_with_text('li.tabs-tab', 'Settings')
        self.assertTrue(settings_btn.is_displayed())
        settings_btn.click()

        title_input = self._get_one('input.title')
        title_input.clear()
        TITLE = 'A Title Most Titular'
        title_input.send_keys(TITLE)

        # Make it published, so that our anon viewer can access it
        published_input = self._get_one('.published')
        published_input.click()

        # TODO: better solution. need to wait for autosave
        # This may have to wait for request-queuing in the Backbone model.
        import time; time.sleep(1) 

        # Now pretend we're someone else
        self.selenium.delete_all_cookies()
        self.selenium.refresh()
        for cookie in self.selenium.get_cookies():
            self.assertFalse(cookie['name'].startswith('claim'))

        # make sure we aren't admins
        self.assertFalse(self._find('.dropdown-toggle')) 

        # check that we got the new title
        self.assertEqual(self.selenium.title, TITLE)

    def test_renderMandatory_on_scroll(self):
        # this test will break but continue to pass if arrow-key navigation changes
        # or the minimum radius of rendered tiles is increased.
        from selenium.webdriver.common.keys import Keys
        self._make_quick_page()
        body = self._get_one('body')
        for i in range(100):
            body.send_keys(Keys.RIGHT)
        # NB Selenium's WebElement.is_displayed() doesn't work for checking
        # whether something is visible on the screen. jQuery's :visible selector
        # doesn't work either, because the tiles do take up room in the DOM.


        # based on http://stackoverflow.com/questions/487073/check-if-element-is-visible-after-scrolling
        # modified to work relative to a scrolling inner element
        # modified to return true if any part of the element is visible
        # modified to only work with absolutely-positioned elements...
        # yes, it was tested to fail when the renderMT-on-move calls
        # were commentd-out.
        isScrolledIntoView = """
            var parentElement = $(arguments[0]);
            var innerElement = $(arguments[1]);

            var docViewTop = parentElement.scrollTop();
            var docViewBottom = docViewTop + parentElement.height();

            var docViewLeft = parentElement.scrollLeft();
            var docViewRight = docViewLeft + parentElement.width();

            var elemTop = parseInt(innerElement.css('top'));
            var elemBottom = elemTop + innerElement.height();

            var elemLeft = parseInt(innerElement.css('left'));
            var elemRight = elemLeft + innerElement.width();

            var hasVerticalVisible = (((elemBottom < docViewBottom) && (elemBottom > docViewTop)) || ((elemTop < docViewBottom) && (elemTop > docViewTop)));

            var hasHorizontalVisible = (((elemRight < docViewRight) && (elemRight > docViewLeft)) || ((elemLeft < docViewRight) && (elemLeft > docViewLeft)));

            return hasVerticalVisible && hasHorizontalVisible;
            """
        tiles = self._find('.tilingcanvas-tile')
        canvas = self._get_one('.tilingcanvas-canvas')
        any_visible = any(self.selenium.execute_script(isScrolledIntoView, *[canvas, t]) for t in tiles)
        self.assertTrue(any_visible)

    def test_tutorial(self):
        self._make_quick_page()
        page = Page.objects.get()
        tutorial = self._get_one('.tutorial')
        # Set font size to be small, otherwise selenium scrolls around with long
        # URL entry and gets confused
        sizeinput = self._find_visible('input[type=number]')[0]
        sizeinput.clear()
        sizeinput.send_keys(10)

        def checkboxStatus():
            checkbox = self._get_one('.tutorial .checkbox')
            return checkbox.get_attribute('checked')

        def nextStep():
            tutorial.find_elements_by_css_selector('.next-step')[0].click()

        # Step 1 -- insert text item
        self.assertFalse(checkboxStatus())
        self._do_insertion_click()
        self._do_insertion_entry(page, "Hello, world!")
        self.assertTrue(checkboxStatus())

        # Step 2 -- scroll
        nextStep()
        self.assertFalse(checkboxStatus())
        self.actions._actions = [] # hax
        item = self._get_one('.item')
        self._drag(item)
        self.assertTrue(checkboxStatus())

        # Step 3 -- change bg color
        nextStep()
        self.assertFalse(checkboxStatus())
        self.actions._actions = [] # hax
        bgInput = self._find_visible('.colorPickerInput')[0]
        bgInput.clear()
        bgInput.send_keys('red')
        item.click()
        self.assertTrue(checkboxStatus())

        # Step 4 -- add image
        nextStep()
        self._get_one('.tilingcanvas-canvas').click() # deselect ?? need better solution
        self.actions._actions = [] # hax
        self.assertFalse(checkboxStatus())
        self.assertEqual(page.imageitem_set.count(), 0)
        url = 'https://s3.amazonaws.com/jotleaf-bno/brandnewotter.jpg'
        self._do_insertion_click()
        self._do_insertion_entry(page, url)
        popup_yes = self._get_one('.confirmation.popup .yes')
        popup_yes.click()
        self._wait_for('.item.imageitem')
        self.assertTrue(checkboxStatus())
        WebDriverWait(self.selenium, 10).until(lambda d: page.imageitem_set.count() == 1)

        # Step 5 -- item style
        nextStep()
        self.actions._actions = [] # hax
        self.assertFalse(checkboxStatus())
        self._get_one('.page-options-dropdown .dropdown-toggle').click() 
        self._get_one('.item-options-btn').click()
        self._wait_for('.itemEditor')

        def selection_successful(_driver):
            self._get_one('.item.textitem').click()
            return self._num_visible('.textOptions')

        WebDriverWait(self.selenium, 10).until(selection_successful)
        color = self._find_visible('.colorPickerInput')[0]
        color.clear()
        color.send_keys('blue')
        self.assertTrue(checkboxStatus())

        # Step 6
        nextStep()
        self.actions._actions = [] # hax
        self.assertFalse(checkboxStatus())
        self._get_one('.tilingcanvas-canvas').click() # deselect ?? need better solution
        self.actions._actions = [] # hax
        self.assertEqual(page.embeditem_set.count(), 0)
        url = 'http://www.youtube.com/watch?v=epUk3T2Kfno'
        self._do_insertion_click()
        self._do_insertion_entry(page, url)
        popup_yes = self._get_one('.confirmation.popup .yes')
        popup_yes.click()
        self._wait_for('.item.embeditem')
        self.assertTrue(checkboxStatus())
        WebDriverWait(self.selenium, 10).until(lambda d: page.embeditem_set.count() == 1)

    def test_dragging(self):
        # Set up page and item
        self.login()
        page = self._make_and_navigate_to_page()
        self._do_insertion_click()
        self._do_insertion_entry(page, "Hello, world!")
        self._get_one('.item.textitem').click()
        WebDriverWait(self.selenium, 10).until(lambda d: page.textitem_set.count() == 1)
        item = page.textitem_set.get()

        # Test that dragging sets new position in db
        orig_x, orig_y = item.x, item.y
        grip = self._get_one('.grip')
        self._drag(grip)
        WebDriverWait(self.selenium, 10).until(lambda d: (
            page.textitem_set.get().x != orig_x and
            page.textitem_set.get().y != orig_y
        ))
        canvas = self._get_one('.tilingcanvas-canvas')
        canvas.click()

        # Test to sure drag handle goes away:
        self._wait_for_none(['.grip'])

    def test_admin_colors(self):
        T1 = 'Foo'
        T2 = 'Bar'
        self.login()
        p = Page.objects.create(owner=self.user, published=True)
        TextItem.objects.create(x=-100, y=-100, font_size=10, content=T1, page=p)
        self.navigate_to_path(p.get_absolute_url())
        self._wait_for_any(['.page-view'])
        self._do_insertion_click()
        self._do_insertion_entry(p, T2)
        dropdown_menu_btn = self._get_one('.page-options-dropdown .dropdown-toggle')
        show_opts_btn = self._get_one('.options-btn')
        options_menu = self._get_one('.pageOptions')
        if not options_menu.is_displayed(): # ?
            dropdown_menu_btn.click()
            show_opts_btn.click()
            self.assertTrue(options_menu.is_displayed())
        admin_style_label = self._find_one_with_text('label', 'Distinguish your text')
        admin_style_input = admin_style_label.find_elements_by_css_selector('input')[0]
        self.assertFalse(admin_style_input.get_attribute('checked'))
        admin_style_input.click()
        self.assertTrue(admin_style_input.get_attribute('checked'))
        pickers = self._find_visible('.colorPickerInput')
        self.assertEqual(len(pickers), 5) # test our understanding
        admin_color_picker = pickers[-2]
        admin_color_picker.clear()
        admin_color_picker.send_keys('red')
        self._find_visible('label')[0].click() # just click out somewhere to trigger change

        self.assertEqual(self._get_js_val("$('.item .content').length"), 2)
        # Ordering is arbitraryish
        self.assertEqual(
            self._get_js_val("$('.item .content:first').css('color')"),
            'rgb(0, 0, 0)'
        )
        self.assertEqual(
            self._get_js_val("$('.item .content:last').css('color')"),
            'rgb(255, 0, 0)'
        )

    def test_pusher_receive(self):
        self.login()
        p = self._make_and_navigate_to_page()
        p.published = True
        p.text_writability = 5 # Public :|
        p.save()
        self.assertFalse(self._find_visible('.item .content'))

        # Create textitem through API
        # TODO: DRY with APITest
        path = '/api/v2/textitem/'
        full_args = {
            'meta': {
                'window_id': '12345',
                'socket_id': '54321'
            },
            'model': {
                'x': 0,
                'y': 0,
                'page_id': p.id,
                'content': 'foo',
            }
        }
        body = json.dumps(full_args)
        kwargs = {
            'content_type': 'application/json',
            'wsgi.input': FakePayload(body), 
            'CONTENT_LENGTH': len(body)
        }
        response = self.client.post(path, **kwargs)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(self._get_one('.item .content'))

class ReadabilityTest(JLSeleniumTest):
    def setUp(self):
        super(ReadabilityTest, self).setUp()
        self.user2 = self.create_user('user2', password='pass2')
        self.page = Page.objects.create(
            owner=self.user,
            title='Some Test Page',
            published=True,
        )

    def _can_see_on_userpage(self, page, user=None):
        assert page.owner, "There is no user page for anon pages"
        self.client.logout()
        if user:
            self.login(user)
        self.navigate_to_urlpattern('show_user', args=[page.owner.username])
        self._wait_for_any(['.page-list']) # We've loaded the page listing...
        self._wait_for_none(['.msg']) # And we're not waiting for its *contents* to load
        matches = self._find_with_text('.page-title', self.page.title)
        if not matches:
            return False
        self.assertEqual(len(matches), 1, "Was expecting at most one page with that title")
        return True

    def _can_visit_page(self, page, user=None):
        self.client.logout()
        if user:
            self.login(user)
        self.navigate_to_path(page.get_absolute_url())
        return len(self._find('div.page-view'))

    def test_published(self):
        # It's listed for everyone, and everyone can visit the page:
        assert self.page.published
        for user in [None, self.user, self.user2]:
            self.assertTrue(self._can_see_on_userpage(self.page, user))
            self.assertTrue(self._can_visit_page(self.page, user))

    def test_unpublished(self):
        self.page.published = False
        self.page.save()

        # Owner can still visit it, but it's not on their profile page
        self.assertFalse(self._can_see_on_userpage(self.page, self.user))
        self.assertTrue(self._can_visit_page(self.page, self.user))

        # But others can't see it or visit it
        for user in [None, self.user2]:
            self.assertFalse(self._can_see_on_userpage(self.page, user))
            self.assertFalse(self._can_visit_page(self.page, user))
 
    def test_unpublished_membership(self):
        self.page.published = False
        self.page.save()

        m = Membership.objects.create(page=self.page, user=self.user2)

        # Still unlisted
        for user in [None, self.user, self.user2]:
            self.assertFalse(self._can_see_on_userpage(self.page, user))

        # Anon still can't visit
        self.assertFalse(self._can_visit_page(self.page, None))

        # But the member can visit
        self.assertTrue(self._can_visit_page(self.page, self.user2))

        # ... until we delete the membership
        m.delete()
        self.assertFalse(self._can_visit_page(self.page, self.user2))

class LoginTest(JLTest):
    def setUp(self):
        self.USERNAME, self.PASSWORD = 'bobross', 'rosspass'
        self.user = User.objects.create_user(self.USERNAME, email=EMAIL, password=self.PASSWORD)
        self.user.is_active = True
        self.user.save()

    def try_login(self, username, password):
        """Try credentials, return the response."""
        path = reverse('xhr_auth_login')
        self.client.logout()
        return self.client.post(path, {'username': username, 'password': password})

    def _login_succeeded(self, response):
        if response.status_code != 200:
            return False
        response = json.loads(response.content)
        return response['authenticated']

    def _login_failed_cleanly(self, response):
        self.assertFalse(self._login_succeeded(response))
        return response.status_code == 200

    def test_good_login(self):
        response = self.try_login(self.USERNAME, self.PASSWORD)
        self.assertTrue(self._login_succeeded(response))

    def test_bad_login(self):
        response = self.try_login(self.USERNAME, 'NOT THE PASSWORD')
        self.assertTrue(self._login_failed_cleanly(response))

    def test_good_email_login(self):
        response = self.try_login(EMAIL, self.PASSWORD)
        self.assertTrue(self._login_succeeded(response))

    def test_bad_email_login(self):
        response = self.try_login(EMAIL, 'NOT THE PASSWORD')
        self.assertTrue(self._login_failed_cleanly(response))

    def test_doubled_email_login(self):
        User.objects.create_user(self.USERNAME + '2', email=EMAIL, password=self.PASSWORD)
        response = self.try_login(EMAIL, 'NOT THE PASSWORD')
        self.assertTrue(self._login_failed_cleanly(response))


