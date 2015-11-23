class TabbedPane
  constructor: (element) ->
    @root = $(element)
    
    @tabs = @root.findOne('ul.tabs-nav')
    @content = @root.findOne('div.tabs-content') 

    @tabs.on('click', 'li', (e) => 
      target = $(e.target)
      @show(target)
    )

  show: (element) =>
    selector = element.data('target')

    if element.hasClass('active')
      return
    
    target = @content.findOne(selector).closest(".tabs-pane")

    @activate(element, @tabs)
    @activate(target, @content)

  activate: (element, container) =>
    container.find('.active').removeClass('active')
    element.addClass('active')

# A button that acts like a checkbox.
# Binds to a Backbone model attribute.
# Creates 4 mutually exclusive classes for your element
#  - btn-yes -- when the button is checked and not hovered
#  - btn-no -- when the button is unchecked and not hovered
#  - btn-yes-to-no -- when the button is checked and hovered
#  - btn-no-to-yes -- when the button is unchecked and hovered
# Nicer than simply using :hover because you don't
# want the transition styles to appear right after you
# click it.
# TODO use a backbone view?
# TODO use tendons?
class CheckboxButton
  CLASSES: {
    YES: 'btn-yes'
    NO: 'btn-no'
    YES_HOVER: 'btn-yes-to-no'
    NO_HOVER: 'btn-no-to-yes'
  }

  constructor: (@element, @options) ->
    if @options.model and @options.attribute
      @model = @options.model
      @attribute = @options.attribute
    else
      assert @options.getter and @options.setter
      @getter = @options.getter
      @setter = @options.setter

    @_setBaseClass()
    @_bindEvents()

  _getValue: =>
    if @getter
      return @getter()
    else
      return @model.get(@attribute)

  _setValue: (newVal) =>
    if @setter
      @setter(newVal)
    else
      @model.edit(@attribute, newVal)

  _bindEvents: =>
    @element.mouseenter( =>
      @_clearClasses()
      if @_getValue()
        @element.addClass(@CLASSES.YES_HOVER)
      else
        @element.addClass(@CLASSES.NO_HOVER)
    )

    @element.mouseleave( =>
      @_clearClasses()
      @_setBaseClass()
    )

    @element.click( =>
      @_setValue(not @_getValue())
      @_clearClasses()
      @_setBaseClass()
    )

  _setBaseClass: =>
    if @_getValue()
      @element.addClass(@CLASSES.YES)
    else
      @element.addClass(@CLASSES.NO)

  _clearClasses: =>
    @element.removeClass(_.values(@CLASSES).join(' '))

  destroy: =>
    @_unbindEvents()

  _unbindEvents: =>
    @element.off('mouseenter mouseleave click')
