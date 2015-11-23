""" 
Fabfile for deploying a Django app on Heroku.

To deploy:
$ fab deploy
"""
import sys
import time

from fabric.api import local

from jotleaf.root_dir import root_dir

#
# Settings
#

PROJECT_NAME = 'jotleaf'
HEROKU_APP_NAME = PROJECT_NAME
BRANCH = 'master'
HEROKU_REMOTE_NAME = 'heroku'
HEROKU_BRANCH = BRANCH

ROOT_DIR = root_dir('..')
sys.path.append(root_dir())
sys.path.append(ROOT_DIR)


#
# Helpers
#

def get_current_commit():
    return local('git rev-parse --verify %s' % BRANCH, capture=True).strip()

def get_time_str(t):
    return time.strftime('%Y-%m-%d-%H-%M-%S', time.localtime(t))

def get_current_branch():
    ref = local("git symbolic-ref HEAD", capture=True)
    assert ref.succeeded
    assert ref.startswith("refs/heads/")
    return ref.replace("refs/heads/", "")

def heroku(args):
    """
    Puts `args` between "heroku" and "--app [appname]"
    """
    args.insert(0, 'heroku')
    args.append('--app')
    args.append(HEROKU_APP_NAME)
    local(' '.join(args))

def heroku_manage_py(args):
    """
    Runs a manage.py command on Heroku
    """
    args = ['run python {}/manage.py'.format(PROJECT_NAME)] + args
    heroku(args)

def get_s3_bucket():
    import boto
    import settings
    conn = boto.connect_s3(
        settings.AWS_ACCESS_KEY_ID,
        settings.AWS_SECRET_ACCESS_KEY
    )
    return conn.get_bucket(settings.AWS_STORAGE_BUCKET_NAME)

def upload_to_s3(bucket, file_name, value, mimetype):
    """Uploads key `file_name` with value `value` and makes it public."""
    from boto.s3.key import Key
    AWS_HEADERS = {
        'Cache-Control':'max-age=31556926,public'
    }
    k = Key(bucket)
    k.key = file_name
    k.content_type = mimetype
    k.set_contents_from_string(value, headers=AWS_HEADERS)
    k.set_acl('public-read')

def compile_and_upload_js():
    from processor import processor
    from hashlib import md5 
    compiled_js = processor.compile_all_js(ROOT_DIR)
    bucket = get_s3_bucket()
    js_hash = None
    for compilation_name, js in compiled_js.items():
        js_hash = md5(js).hexdigest()
        filename = '{}_{}.js'.format(compilation_name, js_hash)
        print "Uploading", filename
        upload_to_s3(bucket, filename, js, 'application/x-javascript')
    
    # Technically returns only the last hash, but we only have one ATM
    return js_hash

#
# Tasks
#

def deploy():
    assert get_current_branch() == BRANCH
    RUN_TIME = time.time()
    RELEASE_TAG = get_time_str(RUN_TIME) + '_' + get_current_commit()
    local('git push origin master')
    JS_HASH = compile_and_upload_js()
    local('git push {} {}'.format(HEROKU_REMOTE_NAME, HEROKU_BRANCH))
    heroku_manage_py(['syncdb --noinput'])
    heroku_manage_py(['migrate --noinput'])
    heroku_manage_py(['loaddata initial_data'])

    # Do this last -- it points static files to the new versions
    # NB the name 'JOTLEAF_RELEASE_TAG' is coupled with assets.py
    heroku(['config:set', 'JOTLEAF_RELEASE_TAG=' + RELEASE_TAG])
    heroku(['config:set', 'JOTLEAF_JS_HASH=' + JS_HASH])

