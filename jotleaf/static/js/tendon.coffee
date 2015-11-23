# Our rivets replacement. Tries to be functional instead of
# declarative. Separates logic from markup.
#
# Features:
#  - named 'source elements' that originate events
#  - easy unbinding and rebinding to different source elements,
#    e.g. swapping out the model that a form refers to

# Constant used for DOM element inside a Binding
ELEMENT_SOURCE_NAME = '__element'

# Container for functional helpers
F = {}

F.compose = _.compose

F.get = (key) ->
  (obj) -> obj[key]

F.getFrom = (obj) ->
  (key) -> obj[key]

# todo: pretty sure there's an underscore method for this
F.getKeys = (obj, keys) ->
  _.map(keys, F.getFrom(obj))

F.caller = (attr) ->
  (obj) -> obj[attr]()

# Adapted from http://autotelicum.github.com/Smooth-CoffeeScript/literate/partial.html
F.partial = (func, a...) -> (b...) ->
  func (for arg in a then arg ?= b.shift())..., b...

F.obj = (key, val) ->
  o = {}
  o[key] = val
  return o

F.debug = (name, f) -> 
  (a...) ->
    log "#{name} called with", a...
    val = f(a...)
    log "...#{name} returning", val
    return val


# General module namespace
Tendon = {}

#
# Adapters
#

Tendon.makePullHandler = (getter, boundSetter) ->
  F.compose(boundSetter, getter)

Tendon.makePushHandler = (boundGetter, setter) ->
  (target) ->
    setter(target, boundGetter())

Tendon.fieldEvents = 'change keyup paste'

Tendon.getAttribute = (attrName) =>
  return (model) =>
    model.get(attrName)

Tendon.editAttribute = (attrName) =>
  return (model, value) =>
    model.edit(attrName, value)

Tendon.setValue = (element, value) =>
  element.val(value)

Tendon.getValue = (element) =>
  return element.val()

Tendon.getIntValue = (element) =>
  return parseInt(element.val(), 10)

Tendon.setBG = (element, value) =>
  element.css('background-color', value)

Tendon.setData = (dataKey) =>
  (element, value) =>
    element.data(dataKey, value)

Tendon.getColorPicker = (element) =>
  picker = element.data('colorpicker')
  colorFormat = element.data('color-format')
  if colorFormat == 'rgba'
    rgb = picker.color.toRGB()
    return "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, #{rgb.a})"
  else
    return picker.color.toHex()

Tendon.getFontPicker = (element) =>
  picker = element.data('fontselector')
  return picker.getSelected()

Tendon.fancyStyleValueEventMap = (itemSourceName, pageSourceName, attribute) ->
  # Creates an event map for styles that use TextItem.getStyleValue
  eventMap = {}
  eventMap[itemSourceName] = 'change:' + attribute
  eventMap[pageSourceName] = "change:default_textitem_#{attribute} change:admin_textitem_#{attribute} change:use_custom_admin_style"
  return eventMap

# A Tendon.Binding listens to multiple source objects for events, and
# calls a handler when any of the events is fired. It can dynamically 
# unbind and rebind the source objects.
Tendon.Binding = class
  constructor: (@nameEventMap, @handlerArgs, @handler, @triggerOnBind) ->
    # `nameEventMap` is a map of {sourceName -> eventName} pairs that
    # can trigger the handler
    #
    # Only executes when all of the sources it depends on are present,
    # i.e. not null.
    #
    # The handler is triggered when any event fires and all required
    # source objects are present.
    #
    # It may take source objects as parameters. The names 
    # should be passed in `handlerArgs` in the positional order
    # of the arguments.
    @sourceMap = {}
    @bound = false
    @_boundHandler = =>
      targets = F.getKeys(@sourceMap, @handlerArgs)
      if not _.every(targets, _.identity)
        return
      @handler(targets...)
 
  checkReadyToBind: (sourceMap) =>
    for k, _ of @nameEventMap
      if not sourceMap[k]
        return false
    return true

  updateSourceMap: (sourceMap) =>
    # todo: only unbind if a dependency changed
    @_unbind()
    @sourceMap = _.extend(@sourceMap, sourceMap)
    if @checkReadyToBind(@sourceMap)
      @_bind()

  _bind: =>
    assert not @bound
    assert @checkReadyToBind(@sourceMap)
    for srcName, eventName of @nameEventMap
      src = @sourceMap[srcName]
      src.on(eventName, @_boundHandler)
    if @triggerOnBind
      @_boundHandler()
    @bound = true

  _unbind: =>
    # todo: keep an explicit list of live bindings instead of
    # relying on @sourceMap?
    for srcName, eventName of @nameEventMap
      src = @sourceMap[srcName]
      if src
        src.off(eventName, @_boundHandler)
    @bound = false


#
# Binding makers
#

Tendon.makePull = (sourceName, eventName, getter, selector, setter, rootEl) =>
  # Listens to change events on a model event,
  # and propagates the value to a DOM element.
  # 
  # `setter` gets called with (element, value)
  assert (sourceName and eventName and getter and selector and setter and rootEl)
  element = rootEl.findOne(selector)
  boundSetter = F.partial(setter, element)
  handler = Tendon.makePullHandler(getter, boundSetter)
  nameEventMap = F.obj(sourceName, eventName)
  return new Tendon.Binding(nameEventMap, [sourceName], handler, true)

Tendon.makePush = (sourceName, eventName, getter, selector, setter, rootEl) =>
  # Listens to change events on on a form field,
  # and propagates the value to a 'target' model.
  element = rootEl.findOne(selector)
  boundGetter = F.partial(getter, element)
  handler = Tendon.makePushHandler(boundGetter, setter)
  nameEventMap = F.obj(ELEMENT_SOURCE_NAME, eventName)
  binding = new Tendon.Binding(nameEventMap, [sourceName], handler, false)
  sourceMap = {}
  sourceMap[ELEMENT_SOURCE_NAME] = element
  binding.updateSourceMap(sourceMap)
  return binding

Tendon.bbPull = (sourceName, attribute, selector, setter, rootEl) =>
  # `pull` from a backbone model to a DOM element
  eventName = 'change:' + attribute
  getter = Tendon.getAttribute(attribute)
  return Tendon.makePull(sourceName, eventName, getter, selector, setter, rootEl)

Tendon.bbPush = (sourceName, attribute, selector, getter, eventName, rootEl) =>
  # Listens to change events on on a form field,
  # and propagates the value to a 'target' model.
  setter = Tendon.editAttribute(attribute)
  return Tendon.makePush(sourceName, eventName, getter, selector, setter, rootEl)

Tendon.baseTwoWay = (sourceName, attribute, selector, setter, getter, rootEl) =>
  return [
    Tendon.bbPull(sourceName, attribute, selector, setter, rootEl),
    Tendon.bbPush(sourceName, attribute, selector, getter, Tendon.fieldEvents, rootEl)
  ]

Tendon.twoWay = (sourceName, attribute, selector, rootEl) =>
  # Default two-way binding. Assumes a plain input field and BB.
  # Returns a bundle (array of Bindings).
  return Tendon.baseTwoWay(sourceName, attribute, selector, Tendon.setValue, Tendon.getValue, rootEl)

Tendon.twoWayInt = (sourceName, attribute, selector, rootEl) =>
  setter = Tendon.setValue
  getter = Tendon.getIntValue
  return Tendon.baseTwoWay(sourceName, attribute, selector, setter, getter, rootEl)

Tendon.twoWayCheckbox = (sourceName, attribute, selector, rootEl) =>
  setter = (el, val) -> el.prop('checked', val)
  getter = (el) -> el.prop('checked')
  return Tendon.baseTwoWay(sourceName, attribute, selector, setter, getter, rootEl)

Tendon.colorPickerBundle = (sourceName, attribute, selector, rootEl) =>
  # Bindings useful for our colorpicker lib
  bindings = []
  baseArgs = [sourceName, attribute, selector]
  makeArgs = -> baseArgs.concat(Array.prototype.slice.call(arguments,0))
  addBinding = (maker, args) -> 
    bindings.push(maker(args...))
  addBinding(Tendon.bbPull, makeArgs(Tendon.setBG, rootEl))
  addBinding(Tendon.bbPull, makeArgs(Tendon.setData('color'), rootEl))
  addBinding(Tendon.bbPush, makeArgs(Tendon.getColorPicker, 'changeColor', rootEl))
  for b in Tendon.twoWay(makeArgs(rootEl)...)
    bindings.push(b)
  return bindings

Tendon.fancyColorPickerBundle = (textItemSourceName, pageSourceName, itemViewSourceName, attribute, selector, getter, rootEl) =>
  # Used for text items, which have a more complex color calculation
  # todo: factor out w/colorPickerBundle?
  # todo: move out of tendon.coffee to a JL-specific place?
  bindings = []

  pull_nameEventMap = Tendon.fancyStyleValueEventMap(textItemSourceName, pageSourceName, attribute)
  element = rootEl.findOne(selector)
  handlerArgs = [itemViewSourceName]
  handler = (itemView) ->
    color = getter(itemView)
    Tendon.setBG(element, color)
    Tendon.setValue(element, color)
    Tendon.setData('color')(element, color)
  bindings.push(new Tendon.Binding(pull_nameEventMap, handlerArgs, handler, true))

  bindings.push(Tendon.bbPush(textItemSourceName, attribute, selector, Tendon.getColorPicker, 'changeColor', rootEl))

  bindings.push(Tendon.bbPush(textItemSourceName, attribute, selector, Tendon.getValue, Tendon.fieldEvents, rootEl))

  return bindings

Tendon.fancyFontSizeBundle = (textItemSourceName, pageSourceName, itemViewSourceName, attribute, selector, rootEl) =>
  bindings = []
  bindings.push(Tendon.bbPush(textItemSourceName, attribute, selector, Tendon.getIntValue, 'change', rootEl))
  element = rootEl.findOne(selector)
  getter = F.caller('getFontSize')
  eventMap = Tendon.fancyStyleValueEventMap(textItemSourceName, pageSourceName, attribute)
  setter = Tendon.setValue
  boundSetter = F.partial(setter, element)
  handler = Tendon.makePullHandler(getter, boundSetter)
  fontPuller = new Tendon.Binding(eventMap, [itemViewSourceName], handler, true)
  bindings.push(fontPuller)
  return bindings

# A Tendon.Tendon is a bundle of Bindings. They typically listen to 
# the same models or inputs, and are all created or destroyed at the 
# same time.
Tendon.Tendon = class
  constructor: (@$el, namedSources) ->
    @_bindings = []
    @_mySourceMap = _.clone(namedSources)

  addBinding: (binding) =>
    @_bindings.push(binding)
    binding.updateSourceMap(@_mySourceMap)

  updateSourceMap: (newSourceMap) =>
    _.extend(@_mySourceMap, newSourceMap)
    for b in @_bindings
      b.updateSourceMap(@_mySourceMap)

  useBundle: (bundleMaker, args) =>
    args.push(@$el)
    bindings = bundleMaker(args...)
    @addBinding(b) for b in bindings

  useBinding: (bindingMaker, args) =>
    args.push(@$el)
    binding = bindingMaker(args...)
    @addBinding(binding)

  unbind: =>
    binding._unbind() for binding in @_bindings

Tendon.Simple = (el, action, condition, listen) =>
  handle = =>
    val = condition.checker()
    action(el, val)
  handle()
  for [target, eventNames] in condition.events
    listen(target, eventNames, handle)
