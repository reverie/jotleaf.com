#!/usr/bin/env python
"""
Inverts an image
usage: <script> file_in file_out
"""
import sys
from PIL import Image, ImageOps


def main():
    infile = sys.argv[1]
    outfile = sys.argv[2]
    i = Image.open(infile).convert('L')
    i2 = ImageOps.invert(i)
    i2.save(outfile)

if __name__ == '__main__':
    main()
