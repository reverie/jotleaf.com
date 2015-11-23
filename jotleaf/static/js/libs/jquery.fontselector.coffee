# Expects options.initial to be a [class, name, displayname] tuple
# (Our custom font data structure. Maybe we should use a class?)
class FontSelector
  constructor: (element, options) ->
    @options = $.extend({
      selected: (style) ->
      className: 'open'
    }, options)

    # Get elements
    @root = element
    @initial = @root.findOne('.initial')
    @ul = @root.findOne("ul")

    # Setup
    @root.data('fontselector', @)
    @ul.hide()
    @_visible = false
    @setSelected(@options.initial[1], @options.initial[2])
    @ul.find("li").each( ->
      $t = $(this)
      family = $t.data('font-family')
      $t.css("font-family", family)
    )
    @bindEvents()

  bindEvents: =>
    @initial.click(@open)

    @ul.on('click', 'li', (e) =>
      $t = $(e.target)
      family = $t.data('font-family')
      displayName = $t.text()
      @setSelected(family, displayName)
      @root.trigger('fontChange', [family])
      @options.selected(family)
      @close()
    )

    $("html").click(@close)

  setSelected: (family, displayName) =>
    unquoted = family.replace(/'/g, '')
    @_selected = unquoted
    @initial.css("font-family", family)
    @initial.text(displayName)

  getSelected: =>
    return @_selected

  open: =>
    if @_visible
      return
    @root.addClass(@options.className)

    # set UL width to match initial's outerwidth. it's kind of hacky to 
    # put this here instead of letting clients decide it, but it was
    # the easiest thing to do. the client can't do this unless the
    # font selector is in the DOM already, which was annnoying
    @ul.outerWidth(@initial.outerWidth())

    @ul.slideDown("fast", =>
      # HACK: Setting overflow-y manually here because someone keeps changing it
      @ul.css('overflow', 'auto')
      @ul.css('overflow-y', 'auto')
      @_visible = true
    )

  close: =>
    if not @_visible
      return
    @ul.slideUp("fast", =>
      @root.removeClass(@options.className)
      @_visible = false
    )

  destroy: =>
    @unbindEvents()

  unbindEvents: =>
    @ul?.off('click', 'li')
    $("html").off('click', @close)
    @initial.off('click', @open)

