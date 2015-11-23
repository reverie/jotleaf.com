Vec = new class
  len: (vector) ->
    sum = 0
    for x in vector
      sum += x*x
    return Math.sqrt sum

  pointDistance: (p1, p2) ->
    diff = [p1[0] - p2[0], p1[1] - p2[1]]
    return @len diff

  segmentAngle: (p1, p2, p3) ->
    # Law of Cosines
    len_a = @pointDistance(p1, p2)
    len_b = @pointDistance(p2, p3)
    len_c = @pointDistance(p3, p1)
    cosine_C = (len_c*len_c - len_a*len_a - len_b*len_b)/(-2*len_a*len_b)
    radians = Math.acos cosine_C
    degrees = 360*radians/(2*Math.PI)
    return degrees

  equal: (p1, p2) ->
    p1[0] == p2[0] and p1[1] == p2[1]

  firstObtuse: (p0, path) ->
    # The index of the first point on `path`
    # such that (p0, p_i, p_{i+1}) forms an
    # obtuse angle.
    #
    # If `p0` is in `path`, its first index
    # will be returned instead.
    assert path.length

    # Check for presence
    for p1, idx in path
      if @equal p0, p1
        return idx

    # Loop again to find obtuse angle
    for p1, idx in path
      if idx == path.length - 1
        return 0 # We're at the end, give up
      p2 = path[idx+1]
      if @segmentAngle(p0, p1, p2) > 100
        return idx

fpMethod = (methodName, args) =>
  # Make filepicker return a deferred instead of using callbacks
  dfd = $.Deferred()
  args.push((fpfile) => dfd.resolve(fpfile))
  args.push((fperr) => dfd.reject(fperr))
  filepicker[methodName].apply(filepicker, args)
  return dfd

fpPickImage = =>
  # Wrapper around our desired image-picking options
  return fpMethod('pick', [{
      mimetypes: ['image/*']
      services: ['COMPUTER'
                 'URL'
                 'DROPBOX'
                 'INSTAGRAM'
                 'GMAIL'
                 'WEBCAM']
      }]
  )

fpStoreUrl = (url) =>
  return fpMethod('storeUrl', [url, {}])

fpStore = (input) =>
  return fpMethod('store', [input, {}])

clamp = (val, lo, hi) ->
   return Math.max(Math.min(val, hi), lo)

# from http://stackoverflow.com/questions/470832/getting-an-absolute-url-from-a-relative-one-ie6-issue
qualifyURL = (url) ->
  # TODO: test in IE9+
	a = document.createElement('a')
	a.href = url
	return a.href


# from http://stackoverflow.com/questions/9404793/check-if-same-origin-policy-applies
testSameOrigin = (url) ->
  a = document.createElement('a')
  a.href = url
  loc = window.location
  return (a.hostname == loc.hostname and
         a.port == loc.port and
         a.protocol == loc.protocol)


# Calls callback(width, height)
getImageSize = (src, callback) ->
  i = $('<img>').css({
    position: 'absolute'
    top: -10000
    left: -10000
  })
  i.load( =>
    [w, h]  = [i.width(), i.height()] # must be done before removing
    i.remove() # ...and we want to remove before callback in case of err
    callback(w, h)
  )
  i.appendTo($('body')).attr('src', src)

scaleBoxSize = (width, height, maxSize) ->
  scaler = Math.min(maxSize/width, maxSize/height)
  if scaler >= 1
    return [width, height]
  width = Math.round(scaler * width)
  height = Math.round(scaler * height)
  if width > maxSize # for off by 1z
    width = maxSize
  if height > maxSize
    height = maxSize
  return [width, height]


Color = new class

  # From http://mjijackson.com/2008/02/rgb-to-hsl-and-rgb-to-hsv-color-model-conversion-algorithms-in-javascript
  # * Converts an RGB color value to HSL. Conversion formula
  # * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
  # * Assumes r, g, and b are contained in the set [0, 255] and
  # * returns h, s, and l in the set [0, 1].
  # *
  # * @param   Number  r       The red color value
  # * @param   Number  g       The green color value
  # * @param   Number  b       The blue color value
  # * @return  Array           The HSL representation
  rgbToHsl: (r, g, b) ->
    r /= 255
    g /= 255
    b /= 255

    max = Math.max(r, g, b)
    min = Math.min(r, g, b)
    h = undefined
    s = undefined
    l = (max + min) / 2
    if max is min
      h = s = 0 # achromatic
    else
      d = max - min
      s = (if l > 0.5 then d / (2 - max - min) else d / (max + min))
      switch max
        when r
          h = (g - b) / d + ((if g < b then 6 else 0))
        when g
          h = (b - r) / d + 2
        when b
          h = (r - g) / d + 4
      h /= 6
    return [h, s, l]

  getCanvasAvgRgb: (canvas) ->
    # imgData is a byte array where each 4 byte chunk is rgba of
    # a single pixel
    # imgData[0:4] is rgba of the pixel at (0, 0)
    # imgData[4:8] is rgba of the pixel at (0, 1)
    canvasH = canvas.height
    canvasW = canvas.width

    imgData = canvas.getImageData(0, 0, canvasW, canvasH).data
    avgRgb = [0, 0, 0]
    numPixels = canvasH * canvasW
    numBytes = numPixels * 4
    for i in [0..numBytes-1] by 4
      r = imgData[i]
      g = imgData[i+1]
      b = imgData[i+2]

      avgRgb[0] += r
      avgRgb[1] += g
      avgRgb[2] += b

    avgRgb[0] /= numPixels
    avgRgb[1] /= numPixels
    avgRgb[2] /= numPixels
    return avgRgb

  getBGLuminance: (color, imageSrc, callback) =>
    # Repaint the canvas with the background color
    # Lazy loading and caching of the image and canvas elements
    if not @image
      @image = $('<img>')
    if not @canvas
      @canvas = $('<canvas/>')[0].getContext('2d')
    
    size = 20
    @canvas.width = @canvas.height = size
    @canvas.clearRect(0, 0, size, size)
    @canvas.fillStyle = color
    @canvas.fillRect(0, 0, size, size)

    onReady = =>
      rgb = @getCanvasAvgRgb(@canvas)
      [h, s, l] = @rgbToHsl(rgb...)
      callback(l)

    drawImage = =>
      try
        @canvas.drawImage(@image[0], 0, 0, size, size)
      catch e
        log "Draw Image failed", e

    # We only want to reload the image when the source changes
    # Otherwise we have to wait for image element to reload the image
    # Every time the page color changes, causing a visible lag in the
    # page background rerender
    if imageSrc 
      if imageSrc != @_lastImg
        @_lastImg = imageSrc
        @image.attr('crossOrigin', 'anonymous')
        @image.attr('src', imageSrc)
        @image.load( =>
          drawImage()
          onReady()
        )
      else
        drawImage()    
        onReady()
    else
      onReady()

