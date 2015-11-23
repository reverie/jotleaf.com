# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models


class Migration(SchemaMigration):

    def forwards(self, orm):
        # Adding model 'Page'
        db.create_table(u'main_page', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, db_index=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, db_index=True, blank=True)),
            ('owner', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.CustomUser'], null=True, blank=True)),
            ('creator_session_id', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
            ('creator_ip', self.gf('django.db.models.fields.IPAddressField')(max_length=15, null=True, blank=True)),
            ('published', self.gf('django.db.models.fields.BooleanField')(default=False)),
            ('published_at', self.gf('django.db.models.fields.DateTimeField')(null=True, db_index=True)),
            ('text_writability', self.gf('django.db.models.fields.IntegerField')(default=3)),
            ('image_writability', self.gf('django.db.models.fields.IntegerField')(default=3)),
            ('title', self.gf('django.db.models.fields.CharField')(max_length=100)),
            ('short_url', self.gf('django.db.models.fields.SlugField')(max_length=50, null=True, blank=True)),
            ('bg_color', self.gf('django.db.models.fields.CharField')(default='#fafafa', max_length=32, blank=True)),
            ('bg_texture', self.gf('django.db.models.fields.CharField')(default='light_wool_midalpha.png', max_length=1024, blank=True)),
            ('bg_fn', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('default_textitem_color', self.gf('django.db.models.fields.CharField')(default='#000', max_length=32, blank=True)),
            ('default_textitem_bg_color', self.gf('django.db.models.fields.CharField')(default='', max_length=32, blank=True)),
            ('default_textitem_font_size', self.gf('django.db.models.fields.PositiveIntegerField')(default=13, null=True, blank=True)),
            ('default_textitem_font', self.gf('django.db.models.fields.CharField')(default='Arial', max_length=32, blank=True)),
            ('default_textitem_bg_texture', self.gf('django.db.models.fields.CharField')(max_length=1024, blank=True)),
            ('use_custom_admin_style', self.gf('django.db.models.fields.BooleanField')(default=False)),
            ('admin_textitem_color', self.gf('django.db.models.fields.CharField')(default='#000', max_length=32, blank=True)),
            ('admin_textitem_bg_color', self.gf('django.db.models.fields.CharField')(default='', max_length=32, blank=True)),
            ('admin_textitem_font_size', self.gf('django.db.models.fields.PositiveIntegerField')(default=13, null=True, blank=True)),
            ('admin_textitem_bg_texture', self.gf('django.db.models.fields.CharField')(max_length=1024, blank=True)),
            ('admin_textitem_font', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
        ))
        db.send_create_signal(u'main', ['Page'])

        # Adding model 'TextItem'
        db.create_table(u'main_textitem', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, db_index=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, db_index=True, blank=True)),
            ('page', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.Page'])),
            ('creator', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.CustomUser'], null=True)),
            ('creator_window_id', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
            ('creator_session_id', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
            ('creator_ip', self.gf('django.db.models.fields.IPAddressField')(max_length=15, null=True, blank=True)),
            ('x', self.gf('django.db.models.fields.IntegerField')()),
            ('y', self.gf('django.db.models.fields.IntegerField')()),
            ('height', self.gf('django.db.models.fields.IntegerField')(null=True, blank=True)),
            ('width', self.gf('django.db.models.fields.IntegerField')(null=True, blank=True)),
            ('border_color', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('border_width', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('border_radius', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('content', self.gf('django.db.models.fields.TextField')(blank=True)),
            ('editable', self.gf('django.db.models.fields.BooleanField')(default=False)),
            ('link_to_url', self.gf('django.db.models.fields.TextField')(blank=True)),
            ('color', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('bg_color', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('bg_texture', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('font_size', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('font', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
        ))
        db.send_create_signal(u'main', ['TextItem'])

        # Adding model 'ImageItem'
        db.create_table(u'main_imageitem', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, db_index=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, db_index=True, blank=True)),
            ('page', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.Page'])),
            ('creator', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.CustomUser'], null=True)),
            ('creator_window_id', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
            ('creator_session_id', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
            ('creator_ip', self.gf('django.db.models.fields.IPAddressField')(max_length=15, null=True, blank=True)),
            ('x', self.gf('django.db.models.fields.IntegerField')()),
            ('y', self.gf('django.db.models.fields.IntegerField')()),
            ('height', self.gf('django.db.models.fields.IntegerField')(null=True, blank=True)),
            ('width', self.gf('django.db.models.fields.IntegerField')(null=True, blank=True)),
            ('border_color', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('border_width', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('border_radius', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('src', self.gf('django.db.models.fields.CharField')(max_length=1000)),
            ('link_to_url', self.gf('django.db.models.fields.TextField')(blank=True)),
        ))
        db.send_create_signal(u'main', ['ImageItem'])

        # Adding model 'EmbedItem'
        db.create_table(u'main_embeditem', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, db_index=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, db_index=True, blank=True)),
            ('page', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.Page'])),
            ('creator', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.CustomUser'], null=True)),
            ('creator_window_id', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
            ('creator_session_id', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
            ('creator_ip', self.gf('django.db.models.fields.IPAddressField')(max_length=15, null=True, blank=True)),
            ('x', self.gf('django.db.models.fields.IntegerField')()),
            ('y', self.gf('django.db.models.fields.IntegerField')()),
            ('height', self.gf('django.db.models.fields.IntegerField')(null=True, blank=True)),
            ('width', self.gf('django.db.models.fields.IntegerField')(null=True, blank=True)),
            ('border_color', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('border_width', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('border_radius', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('original_url', self.gf('django.db.models.fields.TextField')(blank=True)),
            ('embedly_data', self.gf('django.db.models.fields.TextField')(blank=True)),
        ))
        db.send_create_signal(u'main', ['EmbedItem'])

        # Adding model 'Membership'
        db.create_table(u'main_membership', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, db_index=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, db_index=True, blank=True)),
            ('page', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.Page'])),
            ('user', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.CustomUser'])),
        ))
        db.send_create_signal(u'main', ['Membership'])

        # Adding unique constraint on 'Membership', fields ['page', 'user']
        db.create_unique(u'main_membership', ['page_id', 'user_id'])

        # Adding model 'PageView'
        db.create_table(u'main_pageview', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, db_index=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, db_index=True, blank=True)),
            ('user', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.CustomUser'], null=True)),
            ('page', self.gf('django.db.models.fields.related.ForeignKey')(to=orm['main.Page'])),
            ('ip_address', self.gf('django.db.models.fields.IPAddressField')(max_length=15)),
            ('sessionid', self.gf('django.db.models.fields.CharField')(max_length=32, null=True, blank=True)),
        ))
        db.send_create_signal(u'main', ['PageView'])

        # Adding model 'CustomUser'
        db.create_table('auth_user', (
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
            ('password', self.gf('django.db.models.fields.CharField')(max_length=128)),
            ('last_login', self.gf('django.db.models.fields.DateTimeField')(default=datetime.datetime.now)),
            ('is_superuser', self.gf('django.db.models.fields.BooleanField')(default=False)),
            ('username', self.gf('django.db.models.fields.CharField')(unique=True, max_length=30)),
            ('first_name', self.gf('django.db.models.fields.CharField')(max_length=30, blank=True)),
            ('last_name', self.gf('django.db.models.fields.CharField')(max_length=30, blank=True)),
            ('email', self.gf('django.db.models.fields.EmailField')(max_length=75, blank=True)),
            ('is_staff', self.gf('django.db.models.fields.BooleanField')(default=False)),
            ('is_active', self.gf('django.db.models.fields.BooleanField')(default=True)),
            ('date_joined', self.gf('django.db.models.fields.DateTimeField')(default=datetime.datetime.now)),
        ))
        db.send_create_signal(u'main', ['CustomUser'])

        # Adding M2M table for field groups on 'CustomUser'
        db.create_table('auth_user_groups', (
            ('id', models.AutoField(verbose_name='ID', primary_key=True, auto_created=True)),
            ('customuser', models.ForeignKey(orm[u'main.customuser'], null=False)),
            ('group', models.ForeignKey(orm[u'auth.group'], null=False))
        ))
        db.create_unique('auth_user_groups', ['customuser_id', 'group_id'])

        # Adding M2M table for field user_permissions on 'CustomUser'
        db.create_table('auth_user_user_permissions', (
            ('id', models.AutoField(verbose_name='ID', primary_key=True, auto_created=True)),
            ('customuser', models.ForeignKey(orm[u'main.customuser'], null=False)),
            ('permission', models.ForeignKey(orm[u'auth.permission'], null=False))
        ))
        db.create_unique('auth_user_user_permissions', ['customuser_id', 'permission_id'])

        # Adding model 'Follow'
        db.create_table(u'main_follow', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, db_index=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, db_index=True, blank=True)),
            ('user', self.gf('django.db.models.fields.related.ForeignKey')(related_name='friends', to=orm['main.CustomUser'])),
            ('target', self.gf('django.db.models.fields.related.ForeignKey')(related_name='followers', to=orm['main.CustomUser'])),
        ))
        db.send_create_signal(u'main', ['Follow'])

        # Adding unique constraint on 'Follow', fields ['user', 'target']
        db.create_unique(u'main_follow', ['user_id', 'target_id'])


    def backwards(self, orm):
        # Removing unique constraint on 'Follow', fields ['user', 'target']
        db.delete_unique(u'main_follow', ['user_id', 'target_id'])

        # Removing unique constraint on 'Membership', fields ['page', 'user']
        db.delete_unique(u'main_membership', ['page_id', 'user_id'])

        # Deleting model 'Page'
        db.delete_table(u'main_page')

        # Deleting model 'TextItem'
        db.delete_table(u'main_textitem')

        # Deleting model 'ImageItem'
        db.delete_table(u'main_imageitem')

        # Deleting model 'EmbedItem'
        db.delete_table(u'main_embeditem')

        # Deleting model 'Membership'
        db.delete_table(u'main_membership')

        # Deleting model 'PageView'
        db.delete_table(u'main_pageview')

        # Deleting model 'CustomUser'
        db.delete_table('auth_user')

        # Removing M2M table for field groups on 'CustomUser'
        db.delete_table('auth_user_groups')

        # Removing M2M table for field user_permissions on 'CustomUser'
        db.delete_table('auth_user_user_permissions')

        # Deleting model 'Follow'
        db.delete_table(u'main_follow')


    models = {
        u'auth.group': {
            'Meta': {'object_name': 'Group'},
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '80'}),
            'permissions': ('django.db.models.fields.related.ManyToManyField', [], {'to': u"orm['auth.Permission']", 'symmetrical': 'False', 'blank': 'True'})
        },
        u'auth.permission': {
            'Meta': {'ordering': "(u'content_type__app_label', u'content_type__model', u'codename')", 'unique_together': "((u'content_type', u'codename'),)", 'object_name': 'Permission'},
            'codename': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'content_type': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['contenttypes.ContentType']"}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '50'})
        },
        u'contenttypes.contenttype': {
            'Meta': {'ordering': "('name',)", 'unique_together': "(('app_label', 'model'),)", 'object_name': 'ContentType', 'db_table': "'django_content_type'"},
            'app_label': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'model': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '100'})
        },
        u'main.customuser': {
            'Meta': {'object_name': 'CustomUser', 'db_table': "'auth_user'"},
            'date_joined': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'email': ('django.db.models.fields.EmailField', [], {'max_length': '75', 'blank': 'True'}),
            'first_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'groups': ('django.db.models.fields.related.ManyToManyField', [], {'to': u"orm['auth.Group']", 'symmetrical': 'False', 'blank': 'True'}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'is_active': ('django.db.models.fields.BooleanField', [], {'default': 'True'}),
            'is_staff': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'is_superuser': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'last_login': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'last_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'password': ('django.db.models.fields.CharField', [], {'max_length': '128'}),
            'user_permissions': ('django.db.models.fields.related.ManyToManyField', [], {'to': u"orm['auth.Permission']", 'symmetrical': 'False', 'blank': 'True'}),
            'username': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '30'})
        },
        u'main.embeditem': {
            'Meta': {'object_name': 'EmbedItem'},
            'border_color': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'border_radius': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'border_width': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'db_index': 'True', 'blank': 'True'}),
            'creator': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.CustomUser']", 'null': 'True'}),
            'creator_ip': ('django.db.models.fields.IPAddressField', [], {'max_length': '15', 'null': 'True', 'blank': 'True'}),
            'creator_session_id': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'creator_window_id': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'embedly_data': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            'height': ('django.db.models.fields.IntegerField', [], {'null': 'True', 'blank': 'True'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'original_url': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            'page': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.Page']"}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'db_index': 'True', 'blank': 'True'}),
            'width': ('django.db.models.fields.IntegerField', [], {'null': 'True', 'blank': 'True'}),
            'x': ('django.db.models.fields.IntegerField', [], {}),
            'y': ('django.db.models.fields.IntegerField', [], {})
        },
        u'main.follow': {
            'Meta': {'unique_together': "[['user', 'target']]", 'object_name': 'Follow'},
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'db_index': 'True', 'blank': 'True'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'target': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'followers'", 'to': u"orm['main.CustomUser']"}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'db_index': 'True', 'blank': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'friends'", 'to': u"orm['main.CustomUser']"})
        },
        u'main.imageitem': {
            'Meta': {'object_name': 'ImageItem'},
            'border_color': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'border_radius': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'border_width': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'db_index': 'True', 'blank': 'True'}),
            'creator': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.CustomUser']", 'null': 'True'}),
            'creator_ip': ('django.db.models.fields.IPAddressField', [], {'max_length': '15', 'null': 'True', 'blank': 'True'}),
            'creator_session_id': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'creator_window_id': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'height': ('django.db.models.fields.IntegerField', [], {'null': 'True', 'blank': 'True'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'link_to_url': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            'page': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.Page']"}),
            'src': ('django.db.models.fields.CharField', [], {'max_length': '1000'}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'db_index': 'True', 'blank': 'True'}),
            'width': ('django.db.models.fields.IntegerField', [], {'null': 'True', 'blank': 'True'}),
            'x': ('django.db.models.fields.IntegerField', [], {}),
            'y': ('django.db.models.fields.IntegerField', [], {})
        },
        u'main.membership': {
            'Meta': {'unique_together': "[['page', 'user']]", 'object_name': 'Membership'},
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'db_index': 'True', 'blank': 'True'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'page': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.Page']"}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'db_index': 'True', 'blank': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.CustomUser']"})
        },
        u'main.page': {
            'Meta': {'object_name': 'Page'},
            'admin_textitem_bg_color': ('django.db.models.fields.CharField', [], {'default': "''", 'max_length': '32', 'blank': 'True'}),
            'admin_textitem_bg_texture': ('django.db.models.fields.CharField', [], {'max_length': '1024', 'blank': 'True'}),
            'admin_textitem_color': ('django.db.models.fields.CharField', [], {'default': "'#000'", 'max_length': '32', 'blank': 'True'}),
            'admin_textitem_font': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'admin_textitem_font_size': ('django.db.models.fields.PositiveIntegerField', [], {'default': '13', 'null': 'True', 'blank': 'True'}),
            'bg_color': ('django.db.models.fields.CharField', [], {'default': "'#fafafa'", 'max_length': '32', 'blank': 'True'}),
            'bg_fn': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'bg_texture': ('django.db.models.fields.CharField', [], {'default': "'light_wool_midalpha.png'", 'max_length': '1024', 'blank': 'True'}),
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'db_index': 'True', 'blank': 'True'}),
            'creator_ip': ('django.db.models.fields.IPAddressField', [], {'max_length': '15', 'null': 'True', 'blank': 'True'}),
            'creator_session_id': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'default_textitem_bg_color': ('django.db.models.fields.CharField', [], {'default': "''", 'max_length': '32', 'blank': 'True'}),
            'default_textitem_bg_texture': ('django.db.models.fields.CharField', [], {'max_length': '1024', 'blank': 'True'}),
            'default_textitem_color': ('django.db.models.fields.CharField', [], {'default': "'#000'", 'max_length': '32', 'blank': 'True'}),
            'default_textitem_font': ('django.db.models.fields.CharField', [], {'default': "'Arial'", 'max_length': '32', 'blank': 'True'}),
            'default_textitem_font_size': ('django.db.models.fields.PositiveIntegerField', [], {'default': '13', 'null': 'True', 'blank': 'True'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'image_writability': ('django.db.models.fields.IntegerField', [], {'default': '3'}),
            'owner': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.CustomUser']", 'null': 'True', 'blank': 'True'}),
            'published': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'published_at': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'db_index': 'True'}),
            'short_url': ('django.db.models.fields.SlugField', [], {'max_length': '50', 'null': 'True', 'blank': 'True'}),
            'text_writability': ('django.db.models.fields.IntegerField', [], {'default': '3'}),
            'title': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'db_index': 'True', 'blank': 'True'}),
            'use_custom_admin_style': ('django.db.models.fields.BooleanField', [], {'default': 'False'})
        },
        u'main.pageview': {
            'Meta': {'object_name': 'PageView'},
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'db_index': 'True', 'blank': 'True'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'ip_address': ('django.db.models.fields.IPAddressField', [], {'max_length': '15'}),
            'page': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.Page']"}),
            'sessionid': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'db_index': 'True', 'blank': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.CustomUser']", 'null': 'True'})
        },
        u'main.textitem': {
            'Meta': {'object_name': 'TextItem'},
            'bg_color': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'bg_texture': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'border_color': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'border_radius': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'border_width': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'color': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'content': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'db_index': 'True', 'blank': 'True'}),
            'creator': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.CustomUser']", 'null': 'True'}),
            'creator_ip': ('django.db.models.fields.IPAddressField', [], {'max_length': '15', 'null': 'True', 'blank': 'True'}),
            'creator_session_id': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'creator_window_id': ('django.db.models.fields.CharField', [], {'max_length': '32', 'null': 'True', 'blank': 'True'}),
            'editable': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'font': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'font_size': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'height': ('django.db.models.fields.IntegerField', [], {'null': 'True', 'blank': 'True'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'link_to_url': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            'page': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['main.Page']"}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'db_index': 'True', 'blank': 'True'}),
            'width': ('django.db.models.fields.IntegerField', [], {'null': 'True', 'blank': 'True'}),
            'x': ('django.db.models.fields.IntegerField', [], {}),
            'y': ('django.db.models.fields.IntegerField', [], {})
        }
    }

    complete_apps = ['main']