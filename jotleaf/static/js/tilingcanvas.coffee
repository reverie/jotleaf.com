CANVAS_DEBUG = false
SCROLLPOS_DEBUG = false

class Tile extends Backbone.View
  #initialize: (@tileX, @tileY) ->
  className: 'tilingcanvas-tile'
  addItem: (pixelX, pixelY, el) =>
    el = $(el)
    $(el).appendTo(@$el).css
      left: pixelX
      top: pixelY
      position: 'absolute'
      # Without any z-index, tiles can end up partially covering items that
      # are rendered on them, thereby becoming the event.target instead of
      # the element. We use '2' so that the user can set some elements
      # to be in a kind of background layer (1) that's still above the tiles.
      #
      # Background layers start at z-index 1
      # Items start at z-index 100
      # Overlay UI at z-index 1000 (e.g. home btn)
      zIndex: (parseInt(el.css('zIndex'), 10) or 2) + 100

  render: =>
    if CANVAS_DEBUG
      tileX = @$el.data('tileX')
      tileY = @$el.data('tileY')
      @$el.text "(#{tileX}, #{tileY})"
      @$el.addClass 'debug'
    @

class Scroller
  # Helper class for auto-scrolling
  
  # If you change any of these values, make them per-page customizable
  # for fornowband.org. Eg, "SCROLL_PX_PER_SECOND: CONFIG?.SCROLL_PX_PER_SECOND or 20000".
  # And add the CONFIG to fornow's custom JS file.
  SCROLL_PX_PER_SECOND: 5000 # maximum scroll speed
  SCROLL_FREQUENCY: 60 # ticks per second
  ACCELERATION_TIME: 1000 # milliseconds to get to full speed

  # Path-following strategies:
  EXACT: 0 # go to every point in sequence
  FIRST_OBTUSE: 1 # start by going to the first obtuse angle
  #CLOSEST: 2: # start by going to the closest point / not implemented
  #CLOSEST_OBTUSE: 3: # start by going to the closest obtuse angle / not implemented

  constructor: (@getCurrentPosition, @moveContent, @path, strategy=0) ->
    # Smoothly scroll from our current position through
    # all the [x, y] points in @path in the surface coordinate system.

    assert @path.length
    @done = false # useful for testing

    # Set up constants
    @ACCELERATION = @SCROLL_PX_PER_SECOND*1000/@ACCELERATION_TIME # px/s/s
    DECEL_DIST = 1/2 * @ACCELERATION * (@ACCELERATION_TIME/1000) * (@ACCELERATION_TIME/1000)
    @DECEL_DIST = DECEL_DIST / 16 # Decel faster than accel
    @MIN_SPEED = 500

    # Choose target and process path depending on strategy
    switch strategy
      when @EXACT
        start_idx = 0
      when @FIRST_OBTUSE
        start_idx = Vec.firstObtuse @getCurrentPosition(), @path
      else
        throw new Error "Unknown scroll strategy"
    @path = @path.slice(start_idx)
    @expectedDistance = @pathLength @path
    @target = @path.shift()

    # Set up state
    @distanceMoved = 0
    @startTime = new Date().getTime()
    delay = Math.ceil(1000/@SCROLL_FREQUENCY) # ms between ticks

    # Begin
    @_timer = setInterval @move, delay

  move: =>
    # Acquire target
    [x, y] = @target

    # Calculate the movement vector.
    #
    # Recalculate it every tick, or else imprecision will 
    # take us off-target over very long distances.
    [centerX, centerY] = @getCurrentPosition()
    xDiff = centerX - x
    yDiff = centerY - y
    distanceLeft = vectorLen(xDiff, yDiff)
    distToMove = Math.ceil(@getSpeed() / @SCROLL_FREQUENCY)
    distToMove = Math.min distToMove, distanceLeft
    xMove = Math.round(xDiff * distToMove / distanceLeft)
    yMove = Math.round(yDiff * distToMove / distanceLeft)

    # go until we're within 10 pixels of the target, then
    # get new target from @path
    if vectorLen(yDiff, xDiff) > 10
      @moveContent xMove, yMove
      @distanceMoved += distToMove
    else if @path.length
      @target = @path.shift()
    else
      @moveContent xDiff, yDiff
      @cancel()

  pathLength: (xy_list) =>
    length = 0
    prevPoint = @getCurrentPosition()
    for [x, y] in xy_list
      length += vectorLen((x - prevPoint[0]), (y - prevPoint[1]))
      prevPoint = [x, y]
    return length

  getSpeed: =>
    # The effective SCROLL_PX_PER_SECOND for this tick,
    # given that we want to accelerate at the beginning
    # and decelerate at the end.
    
    # If we're close to the end, decelerate
    pxRemaining = Math.abs(Math.max(@expectedDistance - @distanceMoved, 0))
    ratio = Math.sqrt(pxRemaining) / Math.sqrt(@DECEL_DIST)
    downSpeed = ratio * @SCROLL_PX_PER_SECOND
    downSpeed = Math.max( Math.min(downSpeed, @SCROLL_PX_PER_SECOND), @MIN_SPEED)

    # Otherwise a time-linear acceleration to max speed
    timePassed = (new Date().getTime() - @startTime)/1000
    upSpeed = Math.min(timePassed * @ACCELERATION, @SCROLL_PX_PER_SECOND)

    result = Math.min(upSpeed, downSpeed)
    log "using speed", result
    return result

  cancel: ->
    clearInterval(@_timer)
    @done = true

class TilingCanvas extends Backbone.View
  # Simulates an infinite or bounded surface by creating new
  # tiles outside the visible area
  #
  # The canvas has a pixel coordinate system. The view is initially centered
  # at (0,0) in the middle of parentEl. The coordinates go down and to the right,
  # like an HTML element.
  #
  # For now, we never garbage collect old tiles, just keep
  # making new ones, and we always render all items.


  #
  # Constants and Backbone vars 
  #
  
  TILE_WIDTH: 1024
  TILE_HEIGHT: 1024

  className: 'tilingcanvas-canvas'

  events:
    'dragstart .tile-bg-layer': (e) -> e.preventDefault()
    'scroll': 'adjustForExternalScroll'
  
  #
  # Public interface
  #
  initialize: (@parentEl) =>
    @parentEl = $(@parentEl)
    @tiles = {} # tiles[tileX][tileY] -> tile
    @_pasteHappened = false
    if @DEBUG
      @$el.addClass 'debug'
    @_moved = 0 # number of pixels traveled
    @_expectedScrollLeft = @_expectedScrollTop = 0
    @

  render: =>
    assert @parentEl.css('position') == 'relative'
    @parentEl.append @el
    width = @$el.width()
    height = @$el.height()

    # If we have an odd size, expand it by one so that
    #  - we can always get the center by dividing by two
    #  - it will be the real center, in the odd case
    width += (width % 2)
    height += (height % 2)

    # Record size so we can keep center after a resize:
    @width = width
    @height = height

    # Mapping from screen locations to pixel coordinates:
    # the "top left pixel" is the top left VISIBLE pixel,
    # not the top left pixel of the main tilingcanvas
    # element, which may be larger
    # TODO: make this a single value [x, y]
    @topLeftPixelX = -width/2
    @topLeftPixelY = -height/2

    #log "TilingCanvas.render found [width, height, tlpX, tlpY]:", @width, @height, @topLeftPixelX, @topLeftPixelY
    @_initialRender = true
    @renderMandatoryTiles()
    @_initialRender = false
    @$el.scrollLeft(0)
    @$el.scrollTop(0)
    @resize()
    [centerX, centerY] = @getCenter()
    @trigger('set-center', centerX, centerY)
    return @

    
  addItem: (pixelX, pixelY, element) =>
    # Add an item to be displayed on the canvas
    if SCROLLPOS_DEBUG 
      @confirmScrollPosition()
    [tileX, tileY, pixelX, pixelY] = @getCoords pixelX, pixelY
    tile = @getTile tileX, tileY
    tile.addItem pixelX, pixelY, element


  adjustForExternalScroll: (e)=>
    # This scroll handler was introduced to handle scrolls initiated outside 
    # of our code. When editing a text item, the cursor is inside a 
    # contenteditable div.  If the cursor crosses the visible area border, 
    # the browser scrolls in order to follow the cursor. This outside scroll 
    # event was not previously detected and caused misalignment between  our 
    # representation of the visible area of the page, and the actual area 
    # being viewed. Pasting in long text could also bring the cursor into an 
    # area that has not been rendered yet, thus the need to call 
    # renderMandatoryTiles.

    # When our idea of where we are is different from the actual attribute 
    # value, we know an external event has caused this shift and we need to
    # propagate the effects of the external scroll event into our model.
    # log e
    hasMismatch = (
      @_expectedScrollLeft != @$el.scrollLeft() or
      @_expectedScrollTop != @$el.scrollTop()
    )
    if hasMismatch
      log "*** external scroll detected, paste caused:#{@_pasteHappened}", e

      if @_pasteHappened
        @$el.scrollLeft(@_expectedScrollLeft)
        @$el.scrollTop(@_expectedScrollTop)
        return
      else
        # How much have we shifted
        dX = @_expectedScrollLeft - @$el.scrollLeft()
        dY = @_expectedScrollTop - @$el.scrollTop() 
    
        # Update our model of the world
        @topLeftPixelX -= dX
        @topLeftPixelY -= dY

        @_expectedScrollLeft = @$el.scrollLeft() 
        @_expectedScrollTop = @$el.scrollTop()
        

        # TODO: DRY, refactor out of moveContentBy and here
        # Large items might touch tiles which haven't been rendered
        @_moved += Math.abs(dX) + Math.abs(dY)
        assert _.isNumber(@_moved) and not _.isNaN(@_moved)
        if @_moved > @TILE_WIDTH # or TILE_HEIGHT (use max?)
          @renderMandatoryTiles(dX, dY)
          @_moved = 0

        [centerX, centerY] = @getCenter()
        @trigger('set-center', centerX, centerY)
  
  isBoxInView: (x,y, width, height) =>
    rightBoxEdge = x + width
    bottomBoxEdge = y + height
    if rightBoxEdge < @topLeftPixelX or bottomBoxEdge < @topLeftPixelY
      return false
    rightBound = @topLeftPixelX + @width
    bottomBound = @topLeftPixelY + @height
    if x > rightBound or y > bottomBound
      return false
    return true

  resize: =>
    # `resize` must be called when parent 
    # element is resized.
    
    # There is a potentially problematic case here
    # that we have to be careful of. If the surface
    # was very small, and then we maximized it suddenly,
    # there may not have been enough tiles rendered
    # to the bottom or right to fill the content. In
    # this case, our scroll position is forcibly
    # lowered by the browser without triggering
    # a scroll event or any other indication. This
    # causes a mismatch between the expected and
    # actual scroll position, which causes all kinds
    # of rendering and positioning errors. The solution
    # is to add a dummy element to the surface that
    # makes scroll room, then set our scroll position
    # back to what we expect.
    hasMismatch = (
      @_expectedScrollLeft != @$el.scrollLeft() or
      @_expectedScrollTop != @$el.scrollTop()
    )
    if hasMismatch
      log "*** Adjusting for unexpected scroll"
      d = $('<div>').css
        position: 'absolute'
        height: '1px'
        width: '1px'
        left: @$el.width() + @_expectedScrollLeft + 1 # "+ 1" is just a guess
        top: @$el.height() + @_expectedScrollTop + 1
      @$el.append(d)
      @$el.scrollLeft @_expectedScrollLeft
      @$el.scrollTop @_expectedScrollTop
      if SCROLLPOS_DEBUG 
        @confirmScrollPosition()
      @renderMandatoryTiles()
      d.remove()
    # End of bad case. Proceeding as usual...

    if SCROLLPOS_DEBUG 
      @confirmScrollPosition()

    # Get new size
    newWidth = @$el.width()
    newHeight = @$el.height()

    # See note in @render
    if newWidth % 2
      newWidth += 1
    if newHeight % 2
      newHeight += 1

    # Get adjustments so as to maintain the same center.
    # Guaranteed to be divisible by 2 due to +1s above.
    xOffset = (newWidth - @width)/2
    yOffset = (newHeight - @height)/2

    #log "TilingCanvas resizing, with values:", newWidth, newHeight, xOffset, yOffset

    # Store new values
    @width = newWidth
    @height = newHeight

    # There might be missing pieces if the 
    # window got a lot bigger.
    @renderMandatoryTiles()

    # Scroll to re-center
    @moveContentBy(xOffset, yOffset)

    if SCROLLPOS_DEBUG 
      @confirmScrollPosition()

    @trigger('resize', @width, @height)  

  screenPixelsToCoords: (screenX, screenY) =>
    #log "screenPixelsToCoords called with", arguments
    #log "returning", [screenX + @topLeftPixelX, screenY + @topLeftPixelY]
    return [screenX + @topLeftPixelX, screenY + @topLeftPixelY]

  moveContentBy: (dX, dY) =>
    # dX moves the visible content to the right
    # dY moves the visible content down
    # Called 'move' instead of 'scroll' to avoid sign (+-)
    # semantic ambiguities, but in practice used to
    # implement scrolling.

    if SCROLLPOS_DEBUG 
      @confirmScrollPosition()

    # If we've moved a lot, make sure we don't
    # reach any unrendered tiles. TODO: look
    # into making this happen asynchronously, 
    # after the moveContent calls are done, 
    # for a better user experience.
    @_moved += Math.abs(dX) + Math.abs(dY)
    assert _.isNumber(@_moved) and not _.isNaN(@_moved)
    if @_moved > @TILE_WIDTH # or TILE_HEIGHT (use max?)
      @renderMandatoryTiles(dX, dY)
      @_moved = 0

    @moveContentX(dX)
    @moveContentY(dY)

    [centerX, centerY] = @getCenter()
    @trigger('set-center', centerX, centerY)

  setBackground: (bgUrl, bgSize) =>
    # `bgSize` is a [height, weight] 2-tuple of integers
    log "setBackground called with", arguments
    @clearBackground()
    cssValue = "url('#{bgUrl}')"
    @backgroundImage = cssValue
    @backgroundSize = bgSize
    for tile in @$('.' + Tile.prototype.className)
      @setTileElBG $(tile)

  # Depreacted code for passing in a background-determining function
    #if _.isString bg
    #else
    #  assert _.isFunction bg
    #  @backgroundFn = bg
    #  for tx, d of @tiles
    #    for ty, tile of d
    #      log "adding background layers to", tx, ty
    #      @addImageBackgroundLayers tile

  clearBackground: =>
    @backgroundFn = null
    @backgroundImage = null
    @backgroundSize = null
    @$('.' + Tile.prototype.className).css('backgroundImage', '')
    @$('.tile-bg-layer').remove()

  getCenter: =>
    [@topLeftPixelX + @width/2, @topLeftPixelY + @height/2]

  initScrollToCoords: (x, y) =>
    @cancelScrolling()
    @_scroller = new Scroller(@getCenter, @moveContentBy, [[x, y]])

  initPathScroll: (xy_list) =>
    @cancelScrolling()
    @_scroller = new Scroller(@getCenter, @moveContentBy, xy_list, Scroller.prototype.FIRST_OBTUSE)

  cancelScrolling: =>
    @_scroller?.cancel()

  #
  # Internal interface
  #
  getCoords: (pixelX, pixelY) =>
    # Converts coordinates in the surface's coordinate system
    # to the TilingCanvas internal coordinate system.
    #
    # Not related to screen or element coordinates.
    [tileX, pixelX] = divMod pixelX, @TILE_WIDTH
    [tileY, pixelY] = divMod pixelY, @TILE_HEIGHT
    return [tileX, tileY, pixelX, pixelY]

  #addImageBackgroundLayers: (tile) =>
  #  layers = @backgroundFn tile.tileX, tile.tileY
  #  #log "adding layers", layers, "to tile", tile.tileX, tile.tileY
  #  layerNum = 1
  #  for layer in layers
  #    i = $('<img>').attr('src', layer).addClass('tile-bg-layer').css(
  #      zIndex: layerNum
  #      position: 'absolute'
  #      top: 0
  #      left: 0
  #    )
  #    tile.$el.append(i)
  #    layerNum += 1

  createTile: (tileX, tileY) =>
    #log "Creating tile", tileX, tileY
    # Create view
    tile = new Tile()
    # tile = new Tile()

    if not @_initialRender
      if SCROLLPOS_DEBUG 
        @confirmScrollPosition()

    # Get pixel offset coordinates
    # We need the @_initialRender test because of an apparent bug in Firefox.
    # It works fine on the first load. But if you scroll the canvas and then refresh,
    # some of the tiles are misaligned. This is because Firefox tries to restore the previous
    # scroll position, but this happens in the middle of the thread of execution that's
    # doing the first renderMandatoryTiles calls. The scrollTop and scrollLeft values
    # gradually change while the tiles are rendering, causing the misalignment. Note
    # that since this is happening in the middle of the rendering thread somehow, there
    # is no scroll event until after it's done. So we ignore the real value here, 
    # and restore the scroll position to (0, 0) in @render.
    ourCoordX = @TILE_WIDTH*tileX
    screenCoordX = ourCoordX - @topLeftPixelX
    elementCoordX = screenCoordX + (if @_initialRender then 0 else @$el.scrollLeft())
    ourCoordY = @TILE_HEIGHT*tileY
    screenCoordY = ourCoordY - @topLeftPixelY
    elementCoordY = screenCoordY + (if @_initialRender then 0 else @$el.scrollTop())

    #log "TilingCanvas.createTile", ourCoordX, screenCoordX, elementCoordX, ourCoordY, screenCoordY, elementCoordY, @$el.scrollLeft(), @$el.scrollTop()

    # Style, position, and insert into DOM
    tile.$el.css
      left: elementCoordX
      top: elementCoordY
      width: @TILE_WIDTH
      height: @TILE_HEIGHT
    tile.$el.data 'tileX', tileX
    tile.$el.data 'tileY', tileY
    if @backgroundImage
      @setTileElBG tile.$el
    tile.$el.appendTo(@el)

    if CANVAS_DEBUG
      tile.render()

    #if @backgroundFn
    #  @addImageBackgroundLayers tile

    return tile

  getTile: (tileX, tileY) =>
    tile = @tiles[tileX]?[tileY]
    if not tile
      tile = @createTile tileX, tileY
      @tiles[tileX] ||= {} 
      @tiles[tileX][tileY] = tile
    return tile      

  # dX, dY influence what the mandatory tiles will be.
  # We are about to move, if we move beyond 'explored'
  # territory, we must render those tiles before jumping
  getMandatoryTiles: (dX, dY) =>
    # bounds of mandatory rendered rectangle of tile coordinates
    # Get mins:
    [minPixelX, minPixelY] = [@topLeftPixelX, @topLeftPixelY]

    if -dX < minPixelX
      minPixelX -= dX

    if -dY < minPixelY
      minPixelY -= dY  

    [minTileX, minTileY, _, _] = @getCoords minPixelX, minPixelY
    minTileX -= 1
    minTileY -= 1

    # Get maxes:
    maxPixelX = minPixelX + @$el.width()
    maxPixelY = minPixelY + @$el.height()
    
    if -dX > maxPixelX
      maxPixelX -= dX 

    if -dY > maxPixelY
      maxPixelY -= dY

    [maxTileX, maxTileY, _, _] = @getCoords maxPixelX, maxPixelY
    maxTileX += 1
    maxTileY += 1

    # Result
    [minTileX, minTileY, maxTileX, maxTileY]

  renderMandatoryTiles: (dX=0, dY=0)=>
    [minTileX, minTileY, maxTileX, maxTileY] = @getMandatoryTiles(dX, dY)
    for x in [minTileX..maxTileX]
      for y in [minTileY..maxTileY]
        @getTile x, y

  moveContentX: (dX) => 
    # Move everything dX pixels to the right
    @_moveContent('scrollLeft', @makeLeftRoom, @makeRightRoom, 'scrollWidth', 'width', dX)
    @topLeftPixelX -= dX

  moveContentY: (dY) => 
    # Move everything dX pixels down
    @_moveContent('scrollTop', @makeTopRoom, @makeBottomRoom, 'scrollHeight', 'height', dY)
    @topLeftPixelY -= dY

  _moveContent: (scrollAttr, makeNegativeRoom, makePositiveRoom, scrollSizeAttr, sizeAttr, distance) =>
    # For internal use only. Does not preserve @topLeftPixel*
    # Get the current scroll position on the relevant axis
    scrollPos = @$el[scrollAttr]() # scrollTop/Left
    # We subtract the distance, because moving the document
    # "down" is "less scrolling", and "down" movement 
    # is considered a positive distance by our convention.
    newScrollPos = scrollPos - distance
    if newScrollPos < 0
      # make"X"Room functions return the amount of room that
      # they added (in pixels). Adding new room at the top
      # or left side of an element ("negative" room) means
      # our scroll position has to increase to keep the
      # the same view of the contents.
      newRoom = makeNegativeRoom(-newScrollPos)
      newScrollPos = newScrollPos + newRoom
    else
      # contentSize is the size of the scrollable content
      # (technically it's the content + padding)
      contentSize = @$el.prop(scrollSizeAttr)
      viewSize = @$el[sizeAttr]() # height or width
      roomToScroll = contentSize - viewSize - newScrollPos
      if roomToScroll < 0
        makePositiveRoom(-roomToScroll)
    # Finally, now that we know we have room, set the
    # new scroll position.
    if scrollAttr == 'scrollLeft'
      @_expectedScrollLeft = newScrollPos
    else
      assert scrollAttr == 'scrollTop'
      @_expectedScrollTop = newScrollPos
    @$el[scrollAttr] newScrollPos

  makeLeftRoom: (numPx) =>
    # Makes at least `numPx` pixels of new space available 
    # on the left side of the containing element, while not 
    # visibly moving any content.
    # 
    # Returns # of pixels created
    #log "TilingCanvas.makeLeftRoom"
    if SCROLLPOS_DEBUG 
      @confirmScrollPosition()
    tileSizes = Math.ceil(numPx/@TILE_WIDTH)
    roomToAdd = tileSizes * @TILE_WIDTH
    for el in @$el.children()
      el = $(el)
      leftOffset = parseInt el.css('left'), 10
      newLeftOffset = leftOffset + roomToAdd
      el.css 'left', newLeftOffset
    scrollPosition = @$el.scrollLeft()
    newScrollPosition = scrollPosition + roomToAdd
    @$el.scrollLeft newScrollPosition
    assert @$el.scrollLeft() == newScrollPosition
    @_expectedScrollLeft = newScrollPosition
    return roomToAdd

  makeTopRoom: (numPx) =>
    # Makes at least `numPx` pixels of new space available 
    # on the top of the containing element, while not 
    # visibly moving any content.
    # 
    # Returns # of pixels created
    #
    # TODO: factor out w/makeLeftRoom
    #log "TilingCanvas.makeTopRoom"
    if SCROLLPOS_DEBUG 
      @confirmScrollPosition()
    tileSizes = Math.ceil(numPx/@TILE_HEIGHT)
    roomToAdd = tileSizes * @TILE_HEIGHT
    for el in @$el.children()
      el = $(el)
      topOffset = parseInt el.css('top'), 10
      newTopOffset = topOffset + roomToAdd
      el.css 'top', newTopOffset
    scrollPosition = @$el.scrollTop()
    newScrollPosition = scrollPosition + roomToAdd
    @$el.scrollTop newScrollPosition
    assert @$el.scrollTop() == newScrollPosition
    @_expectedScrollTop = newScrollPosition
    return roomToAdd

  makeRightRoom: (numPx) =>
    # Makes at least `numPx` pixels of new space available 
    # on the right side of the containing element, while not 
    # visibly moving any content.
    #log "TilingCanvas.makeRightRoom"
    if SCROLLPOS_DEBUG 
      @confirmScrollPosition()
    tileSizes = Math.ceil(numPx/@TILE_WIDTH)
    roomToAdd = tileSizes * @TILE_WIDTH
    [_, _, maxTileX, maxTileY] = @getMandatoryTiles()
    @getTile maxTileX + tileSizes, maxTileY + tileSizes

  makeBottomRoom: (numPx) =>
    # Makes at least `numPx` pixels of new space available 
    # on the bottom of the containing element, while not 
    # visibly moving any content.
    #log "TilingCanvas.makeBottomRoom"
    # TODO: remove dependency on TILE_WIDTH >= TILE_HEIGHT
    @makeRightRoom numPx

  confirmScrollPosition: =>
    # Fix for assertionException when pasting an image url
    # at the screen edge.  This sequence of events causes a
    # a scroll event that is handled AFTER our paste handler
    # causing a misalignment.

    # TODO: look into the cause of this sequence and remove 
    # this call because if basically renders these assertions
    # useless.
    @adjustForExternalScroll(null)
    
    assert @_expectedScrollLeft == @$el.scrollLeft(), "#{@_expectedScrollLeft} != #{@$el.scrollLeft()}"
    assert @_expectedScrollTop == @$el.scrollTop(), "#{@_expectedScrollTop} != #{@$el.scrollTop()}"

  getDistanceToCenter: =>
    [centerX, centerY] = @getCenter()
    return vectorLen(centerX, centerY)

  setTileElBG: ($tileEl) =>
    tileX = $tileEl.data('tileX')
    tileY = $tileEl.data('tileY')
    [w, h] = @backgroundSize
    
    # w/2 and h/2 to center background image
    bgOffsetX = parseInt(w/2) - divMod((tileX*@TILE_WIDTH), w)[1]
    bgOffsetY = parseInt(h/2) - divMod((tileY*@TILE_HEIGHT), h)[1]

    positionStyle = "#{bgOffsetX}px #{bgOffsetY}px"
    $tileEl.css
      backgroundImage: @backgroundImage
      backgroundPosition: positionStyle

#main = ->
#  parent = $('#page')
#  w = $(window)
#  parent.height parseInt .8*w.height()
#  parent.width parseInt .8*w.width()
#  window.tc = c = new TilingCanvas(parent).render()
#  $(window).resize =>
#    parent.height parseInt .8*w.height()
#    parent.width parseInt .8*w.width()
#    c.resize()
#
#if CANVAS_DEBUG
#  main()
