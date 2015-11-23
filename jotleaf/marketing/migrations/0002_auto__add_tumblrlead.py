# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models


class Migration(SchemaMigration):

    def forwards(self, orm):
        # Adding model 'TumblrLead'
        db.create_table('marketing_tumblrlead', (
            ('id', self.gf('uuidfield.fields.UUIDField')(unique=True, max_length=32, primary_key=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, blank=True)),
            ('tumblr_user', self.gf('django.db.models.fields.CharField')(max_length=100)),
            ('ywot_refers', self.gf('django.db.models.fields.PositiveIntegerField')(null=True, blank=True)),
            ('time_last_scraped', self.gf('django.db.models.fields.DateTimeField')(null=True, blank=True)),
            ('ywot_link_present', self.gf('django.db.models.fields.NullBooleanField')(null=True, blank=True)),
            ('ywot_world_name', self.gf('django.db.models.fields.CharField')(max_length=100)),
            ('ywot_username', self.gf('django.db.models.fields.CharField')(max_length=100)),
            ('email_address', self.gf('django.db.models.fields.CharField')(max_length=100)),
            ('time_emailed', self.gf('django.db.models.fields.DateTimeField')(null=True, blank=True)),
        ))
        db.send_create_signal('marketing', ['TumblrLead'])


    def backwards(self, orm):
        # Deleting model 'TumblrLead'
        db.delete_table('marketing_tumblrlead')


    models = {
        'marketing.tumblrlead': {
            'Meta': {'object_name': 'TumblrLead'},
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            'email_address': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'id': ('uuidfield.fields.UUIDField', [], {'unique': 'True', 'max_length': '32', 'primary_key': 'True'}),
            'time_emailed': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'time_last_scraped': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'tumblr_user': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'ywot_link_present': ('django.db.models.fields.NullBooleanField', [], {'null': 'True', 'blank': 'True'}),
            'ywot_refers': ('django.db.models.fields.PositiveIntegerField', [], {'null': 'True', 'blank': 'True'}),
            'ywot_username': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'ywot_world_name': ('django.db.models.fields.CharField', [], {'max_length': '100'})
        }
    }

    complete_apps = ['marketing']