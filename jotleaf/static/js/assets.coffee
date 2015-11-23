fonts = [
  # category, value, display-name, show-on-page=true
  ['builtin', 'Arial', 'Arial'],
  ['builtin', 'Courier New', 'Courier New'],
  ['builtin', 'Comic Sans MS', 'Comic Sans'],
  ['builtin', 'Impact', 'Impact'],
  ['builtin', 'Verdana', 'Verdana', false],
  ['google', 'Open Sans', 'Open Sans'],
  ['google', 'Kreon', 'Kreon'],
  ['google', 'Lobster', 'Lobster'],
  ['google', 'Crafty Girls', 'Crafty'],
  ['google', 'Philosopher', 'Philosopher'],
  ['google', 'Marck Script', 'Marck Script'],
  ['google', 'Shadows Into Light', 'Shadows Into Light'],

  # used for website, not page
  ['google', 'Lato', 'Lato', false],
]

bg_textures = [
  # filename, [w, h], showOption
  # Base alpha
  ["light_wool_alpha.png", [190, 191], false]
  ["clean_textile_alpha.png", [420, 420], false]
  ["arab_tile_alpha.png", [110, 110], false]
  ["gplaypattern_alpha.png", [188, 178], false]
  ["wall4_alpha.png", [300, 300], false]
  ["light_wood_alpha.png", [512, 512], false]
  ["green_dust_alpha.png", [592, 600], false]
  ["old_mathematics_alpha.png", [200, 200], false]
  ["greyfloral_alpha.png", [150, 124], false]
  ["custom-white-linen_alpha.png", [482, 490], false]
  ["carbon_fibre_alpha.png", [24, 22], false]

  # Inverted alpha:
  ["light_wool_invalpha.png", [190, 191], false]
  ["clean_textile_invalpha.png", [420, 420], false]
  ["arab_tile_invalpha.png", [110, 110], false]
  ["gplaypattern_invalpha.png", [188, 178], false]
  ["wall4_invalpha.png", [300, 300], false]
  ["light_wood_invalpha.png", [512, 512], false]
  ["green_dust_invalpha.png", [592, 600], false]
  ["old_mathematics_invalpha.png", [200, 200], false]
  ["greyfloral_invalpha.png", [150, 124], false]
  ["custom-white-linen_invalpha.png", [482, 490], false]
  ["carbon_fibre_invalpha.png", [24, 22], false]

  # Midrange alpha:
  ["custom-white-linen_midalpha.png", [482, 490], true]
  ["light_wool_midalpha.png", [190, 191], true]
  ["clean_textile_midalpha.png", [420, 420], true]
  ["arab_tile_midalpha.png", [110, 110], true]
  ["gplaypattern_midalpha.png", [188, 178], true]
  ["wall4_midalpha.png", [300, 300], true]
  ["light_wood_midalpha.png", [512, 512], true]
  ["green_dust_midalpha.png", [592, 600], true]
  ["old_mathematics_midalpha.png", [200, 200], true]
  ["greyfloral_midalpha.png", [150, 124], true]
  ["carbon_fibre_midalpha.png", [24, 22], true]

]

loadGoogleFonts = (familyList) ->
  familyList = (f.replace(' ', '+') for f in familyList)
  args = familyList.join('|')
  url = "http://fonts.googleapis.com/css?family=#{args}"
  link = $("<link rel='stylesheet' href='#{url}' type='text/css' />")
  $("head").append(link)

class Font
  constructor: (@category, @family, @displayName, @isPageOption=true) ->

_fontCmp = (a, b) ->
  if (a.family == '') or (a.displayName < b.displayName)
    return -1
  if (b.family == '') or (b.displayName < a.displayName)
    return 1
  return 0

class FontRegistry
  constructor: ->
    @_fonts = {} # family-name -> font
    @_loaded = {}

  add: (font) =>
    assert not @_fonts[font.family]
    @_fonts[font.family] = font

  ensureAllLoaded: =>
    familiesToLoad = []
    for family, font of @_fonts
      if @_loaded[family]
        continue
      @_loaded[family] = true
      if font.category == 'builtin'
        continue
      assert font.category == 'google'
      familiesToLoad.push(family)
    loadGoogleFonts(familiesToLoad)

  list: =>
    # An alphabetically-sorted list of fonts that are
    # to be shown as options for the page editor.
    fonts = _.values(@_fonts)
    fonts = _.filter(fonts, F.get('isPageOption'))
    fonts.sort(_fontCmp)
    return fonts

  getByFamily: (family) =>
    # or throw error?
    return @_fonts[family]

# Having BGPattern and ImageAtURL as separate things is hacky. Unify these.

class BGPattern
  constructor: (@name, @size, @showOption) ->
    assert /^[\w_-]+\.png$/.test @name
    @url = "#{JL_CONFIG.STATIC_URL}patterns/#{@name}"
    @id = @name

class ImageAtURL
  constructor: (@url, @size, @showOption) ->
    # `size` might be null
    @id = url

  ensureSize: (callback) ->
    # Ensure we have size info, then call callback
    if @size
      callback @
    else
      # TODO: use getImageSize
      i = $('<img>').css({
        position: 'absolute'
        top: -10000
        left: -1000
      })
      i.load( =>
        @size = [i.width(), i.height()]
        i.remove()
        callback @
      )
      i.appendTo($('body')).attr('src', @url)

class PatternRegistry
  # TODO: combine with FontRegistry
  constructor: ->
    @_imgs = {}
    @_imgList = []

  add: (img) =>
    assert not @_imgs[img.id]
    @_imgs[img.id] = img
    @_imgList.push img

  list: =>
    return (img for img in @_imgList when img.showOption)

  get: (imgId) =>
    assert @_imgs[imgId]
    return @_imgs[imgId]

  hasKey: (imgId) =>
    return @_imgs[imgId]

Assets = new class
  constructor: ->
    @Fonts = new FontRegistry()
    for args in fonts
      @Fonts.add(new Font(args...))
    setTimeout(@Fonts.ensureAllLoaded, 0)

    @BGPatterns = new PatternRegistry()
    for args in bg_textures
      @BGPatterns.add(new BGPattern(args...))

  isCustomPattern: (url) =>
    return url.indexOf('/') != -1

