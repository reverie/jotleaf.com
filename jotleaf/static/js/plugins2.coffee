# plugins2 exists so that we can have plugins that are
# in coffeescript instead of JS (plugins.js)

# In contenteditable div elements, new lines are marked differently depending on the browser.
# Chrome inserts a \n in the string
# FF/IE insert a <br> tag and no \n
# In order to extract text from one of these divs and maintain whitespace formatting, we
# need to make sure a newline character exists where there is a new line because we are 
# persisting our content as extracted the jQuery.text(div) which ignores BR elements.
jQuery.fn.br2nl = ->
  @each ->
    $(@).children('br').after('\n')

# From http://forum.jquery.com/topic/why-there-is-no-jquery-findone-method-or-smth-similar
# and http://jsfiddle.net/e4JdY/
jQuery.fn.findOne = (selector) ->
   result = @find(selector)
   if (result.length != 1)
      jQuery.error("Didn't find one " + selector)
   return @pushStack(result)

# monkeypatch for colorpicker
# prevent it from going off the bottom of the screen
$.fn.colorpicker.Constructor.prototype.place = ->
  if @component 
    offset = @component.offset() 
  else 
    offset = @element.offset()
  winHeight = $(window).height()
  pickerHeight = @picker.outerHeight()
  inputHeight = @height
  positionAbove = offset.top - pickerHeight
  positionBelow = offset.top + inputHeight
  if (positionBelow + pickerHeight) <= winHeight
    # Display below the input element as normal
    topOffset = positionBelow
  else
    # No room below -- show it above
    topOffset = positionAbove
  @picker.css({
      top: topOffset,
      left: offset.left
  })
