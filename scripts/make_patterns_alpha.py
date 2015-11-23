"""
Dude these subtle patterns are so alpha.
"""

import glob
import os

from main.image_process import make_alpha_version, make_inverse_alpha_version, make_peaked_alpha_version

PATTERNS_DIR = './jotleaf/static/patterns/'

def ends_with_any(strings):
    def fn(s):
        for suffix in strings:
            if s.endswith(suffix):
                return True
        return False
    return fn

def main():
    SUFFIXES = {
        '_alpha': make_alpha_version,
        '_invalpha': make_inverse_alpha_version,
        '_midalpha': make_peaked_alpha_version,
    }
    filenames = glob.glob(PATTERNS_DIR + '*.png')
    file_bases = [os.path.splitext(filename)[0] for filename in filenames]
    is_computed_pattern = ends_with_any(SUFFIXES.keys())
    original_bases = [b for b in file_bases if not is_computed_pattern(b)]
    for file_base in original_bases:
        for suffix, maker in SUFFIXES.items():
            inpath = file_base + '.png'
            outpath = file_base + suffix + '.png'
            print "Making a version of", inpath, "at", outpath
            maker(inpath, outpath)

if __name__ == '__main__':
    main()

