import os
import os.path
import subprocess

from django.core.management.base import BaseCommand

from main.image_process import make_inverse_alpha_version

class Command(BaseCommand):
    help = 'Makes 128x128 versions of an SVG with transparent backgrounds. One with a black foreground, and one with a white foreground.'
    args = '<path_to_svg>'

    def _run_convert_cmd(self, *convert_args):
        args = ['convert']
        args.extend(convert_args)
        subprocess.check_call(args)

    def _make_shadow_args(self, color):
        # 60 is opacity, 4 is the radius?, 0/0 is the offset
        # -layers merge combines the foreground and shadow layers
        # beyond that I don't get it either; copied from example
        s = "-alpha set ( +clone -background %s -shadow 60x4+0+0 ) +swap -background none -layers merge" % color
        return s.split()

    def handle(self, *args, **options):
        subprocess.check_call
        relative_infile = args[0]
        infile = os.path.join(os.getcwd(), relative_infile)

        filename, extension = os.path.splitext(infile)
        assert extension == '.svg'

        # Make initial PNG: black foreground, white background.
        plain_outfile = filename + '.png'
        self._run_convert_cmd(infile, plain_outfile)

        # Make PNG with black foreground, transparent background
        black_outfile = filename + '_black.png'
        make_inverse_alpha_version(plain_outfile, black_outfile)

        # Make PNG with white foreground, transparent background
        white_outfile = filename + '_white.png'
        self._run_convert_cmd('-negate', black_outfile, white_outfile)

        # Make PNG with black foreground, transparent background, white shadow
        black_shadow_outfile = filename + '_black_shadowed.png'
        args = [black_outfile]
        args.extend(self._make_shadow_args('white'))
        args.append(black_shadow_outfile)
        self._run_convert_cmd(*args)

        # Make PNG with white foreground, transparent background, black shadow
        white_shadow_outfile = filename + '_white_shadowed.png'
        args = [white_outfile]
        args.extend(self._make_shadow_args('black'))
        args.append(white_shadow_outfile)
        self._run_convert_cmd(*args)
