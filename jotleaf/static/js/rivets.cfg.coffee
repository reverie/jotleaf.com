rivets.configure 
  prefix: 'rv'
  # standard Backbone adapter from RivetsJS documentation
  adapter:
    subscribe: (obj, keypath, callback) ->
      assert obj instanceof Backbone.Model
      callback.wrapped = (m, v) ->
        callback v
      obj.on "change:" + keypath, callback.wrapped
    unsubscribe: (obj, keypath, callback) ->
      obj.off "change:" + keypath, callback.wrapped
    read: (obj, keypath) ->
      obj.get keypath
    publish: (obj, keypath, value) ->
      # the ? is hacky, but model:property should already by bypassing the adapter...
      log "editing", keypath, value
      obj.edit? keypath, value 

#
# Styles
#

rivets.binders.bg_color = (el, value)->
  $(el).css 'background-color', value

rivets.binders.bg_image = (el, value)->
  $(el).css 'background-image', "url(#{value})"

rivets.binders.color = (el, value) ->
  $(el).css 'color', value

rivets.binders.font_size = (el, value) ->
  # Take an integer `value` in pixels
  if value
    if not _.isNumber(value)
      value = parseInt(value, 10)
    assert _.isNumber(value)
    $(el).css 'font-size', "#{value}px"
  else
    $(el).css 'font-size', ''

rivets.binders.font_face = (el, value) ->
  $(el).css 'font-family', value

rivets.binders.fontlistitem = (el, value) ->
  $el = $(el)
  $el.data 'font-family', value.family
  $el.text value.displayName

rivets.binders.selected = (el, value)->
  if value is $(el).val()
    $(el).attr 'selected', true

#
# Show/hide effects
#

rivets.binders.slideshow = (el, value) ->
  $el = $(el)
  if value
    $(el).show('slideDown')
  else if not $el.is ':visible'
    # jQ skips animation on non-visible elements,
    # so go ahead and set .style.display directly
    rivets.binders.show el, value
  else
    $(el).hide('slideDown')

rivets.binders.slidehide = (el, value) ->
  rivets.binders.slideshow el, not value
