"""
We serve our own copies of some external JS files. This script makes
it easier to keep them updated from the remote copy.
"""

import requests
import os.path

JS_LIBS_DIR = './jotleaf/static/js/libs'

EXTERNAL_LIBS = [
    # Local name, remote URL
    ('webfont.js', 'http://ajax.googleapis.com/ajax/libs/webfont/1/webfont.js'),
    ('pusher-1.12.js', 'http://js.pusher.com/1.12/pusher.js'),
    ('filepicker.js', 'http://api.filepicker.io/v1/filepicker.js'),

]

def main():
    for local_name, url in EXTERNAL_LIBS:
        content = requests.get(url).text
        filename = os.path.join(JS_LIBS_DIR, local_name)
        f = open(filename, 'w')
        f.write(content)
        f.close()
        print "Updated", local_name

if __name__ == '__main__':
    main()

