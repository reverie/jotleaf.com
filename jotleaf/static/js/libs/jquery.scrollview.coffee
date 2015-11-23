#  ScrollView - jQuery plugin 0.1
# 
#  This plugin supplies contents view by grab and drag scroll.
# 
#  Copyright (c) 2009 Toshimitsu Takahashi
#  Modified 2009 by Andrew Badr
# 
#  Released under the MIT license.

class DraggableSurface
  constructor: (@container, @scrollBy) ->
    @container = $(@container)
    @active = true
    @_isGrabbing = false
    @_xp = @_yp = @_grabbedNode = null
    @bindEvents()

  dragClass: 'scrollview-dragging'

  startgrab: (target) =>
    @_isGrabbing = true
    @_grabbedNode = target
    @container.addClass(@dragClass)
    @container.trigger('start-drag')

  stopgrab: =>
    @_isGrabbing = false
    @container.removeClass(@dragClass)
    @container.trigger('stop-drag')
    @_grabbedNode = null

  bindEvents: =>
    @container.mousedown((e) =>
      # Tracks how many pixels we 'just' moved, so we can check
      # on a click event. Value should be zero if either the last
      # mousedown didn't initiate a drag, or if it did but the user
      # didn't move it [much].
      @_pixelsMoved = 0

      # Abort early if not active, so that we don't preventDefault 
      # on an event someone else wants
      # Added right click detection to hijack those from chrome's
      # finicky handling
      if not (@active and (e.which ==1 or e.which==3))
        return

      # This really is a grab -- preventdefault so the browser doesn't
      # search for text-selections to make while the mouse is down. 
      # (Big performance issue on Chrome, see:
      # http://code.google.com/p/chromium/issues/detail?id=103148 )
      e.preventDefault()
      
      # only left clicks cause dragging
      if e.which == 1
        # Start grabbing
        @startgrab(e.target)
        @_xp = e.pageX
        @_yp = e.pageY
    )

    @container.mousemove((e) =>
      if not @_isGrabbing
        return true
      xDiff = @_xp - e.pageX
      yDiff = @_yp - e.pageY
      @scrollBy(xDiff, yDiff)
      @_xp = e.pageX
      @_yp = e.pageY
      @_pixelsMoved += Math.abs(xDiff) + Math.abs(yDiff)
    )

    @container.on('mouseup mouseleave', @stopgrab)
    $(window).on('blur', @stopgrab)

    @container.click((e) =>
      if @_pixelsMoved > 5
        # If we drag the surface, but happened to click a link, don't trigger
        # the link's default click handler. This depends on there being no
        # more-specific click event handlers. One way to achieve this is by
        # using jq 'live' events.
        e.preventDefault()
        e.stopPropagation()
    )


  enable: =>
    @active = true

  disable: =>
    @active = false
    @stopgrab()

  destroy: =>
    @unbindEvents()

  unbindEvents: =>
    @container.off('mousedown mousemove click mouseup mouseleave')
    $(window).off('blur', @stopgrab)