#!/usr/bin/env python
"""
Functions related to JavaScript compilation.

When run from the command line, takes a template path, and
prints on stdout that template's compiled JS file.
"""
import codecs
import os
import re
import subprocess
import sys

from settings import PROJECT_NAME

PAGES_TO_PROCESS = [
    # paths relative to the template directory
    'spa_base.html'
]

TEMPLATE_DIR = 'templates'
STATIC_DIR = 'static'
EXTRA_JS = 'js/PRODUCTION.js'

def remove_console_log(path):
    subprocess.check_call(['sed', '-i.bak', '-r', r's/^\s*console\.log.*//', path])

def collect_js_srcs(filename):
    from django.template.context import Context
    from django.template import Template
    from django.template import loader # required, see last line of loader.py...
    from main.templatetags.assets import CompiledScriptsNode
    contents = codecs.open(filename, 'r', 'utf8').read()
    t = Template(contents)
    nodes = t.nodelist.get_nodes_by_type(CompiledScriptsNode)
    assert len(nodes) == 1
    n = nodes[0]
    text = n.render(Context())
    srcs = re.findall('src="([\w\-\/\.]+)"', text)
    for src in srcs:
        assert src.startswith('js/') # Sanity check
    assert len(srcs) == text.count('<script')
    srcs.insert(0, EXTRA_JS)
    return srcs
    
def src_to_filename(static_dir, src):
    return re.sub("{{[ ]*STATIC_URL[ ]*}}", static_dir + '/', src)

def path_join_and_assert(*args):
    result = os.path.join(*args)
    try:
        assert os.path.exists(result)
    except AssertionError:
        print "Missing file:", result
        raise
    return result

def make_compiled_js(release_dir, filename):
    """The commpiled JS for `filenames`"""
    print "Compiling JS for", filename
    template_dir = path_join_and_assert(release_dir, PROJECT_NAME, TEMPLATE_DIR)
    static_dir = path_join_and_assert(release_dir, PROJECT_NAME, STATIC_DIR)
    compiler = path_join_and_assert(release_dir, 'processor', 'compiler.jar')
    filename = os.path.join(template_dir, filename)
    js_srcs = collect_js_srcs(filename)
    js_files = [os.path.join(static_dir, src) for src in js_srcs]
    command = [
        'java', '-jar', compiler, 
        '--compilation_level', 'SIMPLE_OPTIMIZATIONS',
        '--warning_level', 'QUIET',
    ]
    for f in js_files:
        print "...including", f
        command.extend(['--js', f])
    process = subprocess.Popen(command, stdout=subprocess.PIPE)
    out, err = process.communicate()
    assert err is None
    return out

def compile_all_js(release_dir):
    """
    Returns a dictionary mapping 
        (compilation_name), e.g. "base.html"
    to
        (js), i.e. a string of the compiled JS file

    *Assumes that the compilation name of a given template is the template's name.*
    """
    assert os.path.exists(release_dir)
    return dict((filename, make_compiled_js(release_dir, filename)) for filename in PAGES_TO_PROCESS)

def main():
    compiled = compile_all_js(sys.argv[1])
    for filename, contents in compiled.items():
        output_filename = filename + '.js'
        with open(output_filename, 'w') as f:
            print "Writing", output_filename
            f.write(contents)

if __name__ == '__main__':
    main()
