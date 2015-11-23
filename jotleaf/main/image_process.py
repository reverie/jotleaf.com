from PIL import Image

def make_alpha_version(inpath, outpath, getalpha=lambda a: a):
    i_orig = Image.open(inpath)
    width, _ = i_orig.size
    i_grey = i_orig.convert('L')
    i_alpha = i_grey.convert('RGBA')
    for i, lum in enumerate(i_grey.getdata()):
        y = i / width
        x = i % width
        a = getalpha(lum)
        i_alpha.putpixel((x,y), (lum, lum, lum, a))
    i_alpha.save(outpath)

def make_inverse_alpha_version(inpath, outpath):
    # `invert` means make the white parts transparent,
    # otherwise the dark parts are transparent
    make_alpha_version(inpath, outpath, lambda a: 255 - a)

def make_peaked_alpha_version(inpath, outpath):
    """Brings out the texture no matter what BG color is used."""
    make_alpha_version(inpath, outpath, lambda a: abs(128-a))
