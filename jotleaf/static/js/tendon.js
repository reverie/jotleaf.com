// Generated by CoffeeScript 1.4.0
var ELEMENT_SOURCE_NAME, F, Tendon,
  __slice = [].slice,
  _this = this,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

ELEMENT_SOURCE_NAME = '__element';

F = {};

F.compose = _.compose;

F.get = function(key) {
  return function(obj) {
    return obj[key];
  };
};

F.getFrom = function(obj) {
  return function(key) {
    return obj[key];
  };
};

F.getKeys = function(obj, keys) {
  return _.map(keys, F.getFrom(obj));
};

F.caller = function(attr) {
  return function(obj) {
    return obj[attr]();
  };
};

F.partial = function() {
  var a, func;
  func = arguments[0], a = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  return function() {
    var arg, b;
    b = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return func.apply(null, __slice.call((function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = a.length; _i < _len; _i++) {
        arg = a[_i];
        _results.push(arg != null ? arg : arg = b.shift());
      }
      return _results;
    })()).concat(__slice.call(b)));
  };
};

F.obj = function(key, val) {
  var o;
  o = {};
  o[key] = val;
  return o;
};

F.debug = function(name, f) {
  return function() {
    var a, val;
    a = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    log.apply(null, ["" + name + " called with"].concat(__slice.call(a)));
    val = f.apply(null, a);
    log("..." + name + " returning", val);
    return val;
  };
};

Tendon = {};

Tendon.makePullHandler = function(getter, boundSetter) {
  return F.compose(boundSetter, getter);
};

Tendon.makePushHandler = function(boundGetter, setter) {
  return function(target) {
    return setter(target, boundGetter());
  };
};

Tendon.fieldEvents = 'change keyup paste';

Tendon.getAttribute = function(attrName) {
  return function(model) {
    return model.get(attrName);
  };
};

Tendon.editAttribute = function(attrName) {
  return function(model, value) {
    return model.edit(attrName, value);
  };
};

Tendon.setValue = function(element, value) {
  return element.val(value);
};

Tendon.getValue = function(element) {
  return element.val();
};

Tendon.getIntValue = function(element) {
  return parseInt(element.val(), 10);
};

Tendon.setBG = function(element, value) {
  return element.css('background-color', value);
};

Tendon.setData = function(dataKey) {
  return function(element, value) {
    return element.data(dataKey, value);
  };
};

Tendon.getColorPicker = function(element) {
  var colorFormat, picker, rgb;
  picker = element.data('colorpicker');
  colorFormat = element.data('color-format');
  if (colorFormat === 'rgba') {
    rgb = picker.color.toRGB();
    return "rgba(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ", " + rgb.a + ")";
  } else {
    return picker.color.toHex();
  }
};

Tendon.getFontPicker = function(element) {
  var picker;
  picker = element.data('fontselector');
  return picker.getSelected();
};

Tendon.fancyStyleValueEventMap = function(itemSourceName, pageSourceName, attribute) {
  var eventMap;
  eventMap = {};
  eventMap[itemSourceName] = 'change:' + attribute;
  eventMap[pageSourceName] = "change:default_textitem_" + attribute + " change:admin_textitem_" + attribute + " change:use_custom_admin_style";
  return eventMap;
};

Tendon.Binding = (function() {

  function _Class(nameEventMap, handlerArgs, handler, triggerOnBind) {
    var _this = this;
    this.nameEventMap = nameEventMap;
    this.handlerArgs = handlerArgs;
    this.handler = handler;
    this.triggerOnBind = triggerOnBind;
    this._unbind = __bind(this._unbind, this);

    this._bind = __bind(this._bind, this);

    this.updateSourceMap = __bind(this.updateSourceMap, this);

    this.checkReadyToBind = __bind(this.checkReadyToBind, this);

    this.sourceMap = {};
    this.bound = false;
    this._boundHandler = function() {
      var targets;
      targets = F.getKeys(_this.sourceMap, _this.handlerArgs);
      if (!_.every(targets, _.identity)) {
        return;
      }
      return _this.handler.apply(_this, targets);
    };
  }

  _Class.prototype.checkReadyToBind = function(sourceMap) {
    var k, _, _ref;
    _ref = this.nameEventMap;
    for (k in _ref) {
      _ = _ref[k];
      if (!sourceMap[k]) {
        return false;
      }
    }
    return true;
  };

  _Class.prototype.updateSourceMap = function(sourceMap) {
    this._unbind();
    this.sourceMap = _.extend(this.sourceMap, sourceMap);
    if (this.checkReadyToBind(this.sourceMap)) {
      return this._bind();
    }
  };

  _Class.prototype._bind = function() {
    var eventName, src, srcName, _ref;
    assert(!this.bound);
    assert(this.checkReadyToBind(this.sourceMap));
    _ref = this.nameEventMap;
    for (srcName in _ref) {
      eventName = _ref[srcName];
      src = this.sourceMap[srcName];
      src.on(eventName, this._boundHandler);
    }
    if (this.triggerOnBind) {
      this._boundHandler();
    }
    return this.bound = true;
  };

  _Class.prototype._unbind = function() {
    var eventName, src, srcName, _ref;
    _ref = this.nameEventMap;
    for (srcName in _ref) {
      eventName = _ref[srcName];
      src = this.sourceMap[srcName];
      if (src) {
        src.off(eventName, this._boundHandler);
      }
    }
    return this.bound = false;
  };

  return _Class;

})();

Tendon.makePull = function(sourceName, eventName, getter, selector, setter, rootEl) {
  var boundSetter, element, handler, nameEventMap;
  assert(sourceName && eventName && getter && selector && setter && rootEl);
  element = rootEl.findOne(selector);
  boundSetter = F.partial(setter, element);
  handler = Tendon.makePullHandler(getter, boundSetter);
  nameEventMap = F.obj(sourceName, eventName);
  return new Tendon.Binding(nameEventMap, [sourceName], handler, true);
};

Tendon.makePush = function(sourceName, eventName, getter, selector, setter, rootEl) {
  var binding, boundGetter, element, handler, nameEventMap, sourceMap;
  element = rootEl.findOne(selector);
  boundGetter = F.partial(getter, element);
  handler = Tendon.makePushHandler(boundGetter, setter);
  nameEventMap = F.obj(ELEMENT_SOURCE_NAME, eventName);
  binding = new Tendon.Binding(nameEventMap, [sourceName], handler, false);
  sourceMap = {};
  sourceMap[ELEMENT_SOURCE_NAME] = element;
  binding.updateSourceMap(sourceMap);
  return binding;
};

Tendon.bbPull = function(sourceName, attribute, selector, setter, rootEl) {
  var eventName, getter;
  eventName = 'change:' + attribute;
  getter = Tendon.getAttribute(attribute);
  return Tendon.makePull(sourceName, eventName, getter, selector, setter, rootEl);
};

Tendon.bbPush = function(sourceName, attribute, selector, getter, eventName, rootEl) {
  var setter;
  setter = Tendon.editAttribute(attribute);
  return Tendon.makePush(sourceName, eventName, getter, selector, setter, rootEl);
};

Tendon.baseTwoWay = function(sourceName, attribute, selector, setter, getter, rootEl) {
  return [Tendon.bbPull(sourceName, attribute, selector, setter, rootEl), Tendon.bbPush(sourceName, attribute, selector, getter, Tendon.fieldEvents, rootEl)];
};

Tendon.twoWay = function(sourceName, attribute, selector, rootEl) {
  return Tendon.baseTwoWay(sourceName, attribute, selector, Tendon.setValue, Tendon.getValue, rootEl);
};

Tendon.twoWayInt = function(sourceName, attribute, selector, rootEl) {
  var getter, setter;
  setter = Tendon.setValue;
  getter = Tendon.getIntValue;
  return Tendon.baseTwoWay(sourceName, attribute, selector, setter, getter, rootEl);
};

Tendon.twoWayCheckbox = function(sourceName, attribute, selector, rootEl) {
  var getter, setter;
  setter = function(el, val) {
    return el.prop('checked', val);
  };
  getter = function(el) {
    return el.prop('checked');
  };
  return Tendon.baseTwoWay(sourceName, attribute, selector, setter, getter, rootEl);
};

Tendon.colorPickerBundle = function(sourceName, attribute, selector, rootEl) {
  var addBinding, b, baseArgs, bindings, makeArgs, _i, _len, _ref;
  bindings = [];
  baseArgs = [sourceName, attribute, selector];
  makeArgs = function() {
    return baseArgs.concat(Array.prototype.slice.call(arguments, 0));
  };
  addBinding = function(maker, args) {
    return bindings.push(maker.apply(null, args));
  };
  addBinding(Tendon.bbPull, makeArgs(Tendon.setBG, rootEl));
  addBinding(Tendon.bbPull, makeArgs(Tendon.setData('color'), rootEl));
  addBinding(Tendon.bbPush, makeArgs(Tendon.getColorPicker, 'changeColor', rootEl));
  _ref = Tendon.twoWay.apply(Tendon, makeArgs(rootEl));
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    b = _ref[_i];
    bindings.push(b);
  }
  return bindings;
};

Tendon.fancyColorPickerBundle = function(textItemSourceName, pageSourceName, itemViewSourceName, attribute, selector, getter, rootEl) {
  var bindings, element, handler, handlerArgs, pull_nameEventMap;
  bindings = [];
  pull_nameEventMap = Tendon.fancyStyleValueEventMap(textItemSourceName, pageSourceName, attribute);
  element = rootEl.findOne(selector);
  handlerArgs = [itemViewSourceName];
  handler = function(itemView) {
    var color;
    color = getter(itemView);
    Tendon.setBG(element, color);
    Tendon.setValue(element, color);
    return Tendon.setData('color')(element, color);
  };
  bindings.push(new Tendon.Binding(pull_nameEventMap, handlerArgs, handler, true));
  bindings.push(Tendon.bbPush(textItemSourceName, attribute, selector, Tendon.getColorPicker, 'changeColor', rootEl));
  bindings.push(Tendon.bbPush(textItemSourceName, attribute, selector, Tendon.getValue, Tendon.fieldEvents, rootEl));
  return bindings;
};

Tendon.fancyFontSizeBundle = function(textItemSourceName, pageSourceName, itemViewSourceName, attribute, selector, rootEl) {
  var bindings, boundSetter, element, eventMap, fontPuller, getter, handler, setter;
  bindings = [];
  bindings.push(Tendon.bbPush(textItemSourceName, attribute, selector, Tendon.getIntValue, 'change', rootEl));
  element = rootEl.findOne(selector);
  getter = F.caller('getFontSize');
  eventMap = Tendon.fancyStyleValueEventMap(textItemSourceName, pageSourceName, attribute);
  setter = Tendon.setValue;
  boundSetter = F.partial(setter, element);
  handler = Tendon.makePullHandler(getter, boundSetter);
  fontPuller = new Tendon.Binding(eventMap, [itemViewSourceName], handler, true);
  bindings.push(fontPuller);
  return bindings;
};

Tendon.Tendon = (function() {

  function _Class($el, namedSources) {
    this.$el = $el;
    this.unbind = __bind(this.unbind, this);

    this.useBinding = __bind(this.useBinding, this);

    this.useBundle = __bind(this.useBundle, this);

    this.updateSourceMap = __bind(this.updateSourceMap, this);

    this.addBinding = __bind(this.addBinding, this);

    this._bindings = [];
    this._mySourceMap = _.clone(namedSources);
  }

  _Class.prototype.addBinding = function(binding) {
    this._bindings.push(binding);
    return binding.updateSourceMap(this._mySourceMap);
  };

  _Class.prototype.updateSourceMap = function(newSourceMap) {
    var b, _i, _len, _ref, _results;
    _.extend(this._mySourceMap, newSourceMap);
    _ref = this._bindings;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      b = _ref[_i];
      _results.push(b.updateSourceMap(this._mySourceMap));
    }
    return _results;
  };

  _Class.prototype.useBundle = function(bundleMaker, args) {
    var b, bindings, _i, _len, _results;
    args.push(this.$el);
    bindings = bundleMaker.apply(null, args);
    _results = [];
    for (_i = 0, _len = bindings.length; _i < _len; _i++) {
      b = bindings[_i];
      _results.push(this.addBinding(b));
    }
    return _results;
  };

  _Class.prototype.useBinding = function(bindingMaker, args) {
    var binding;
    args.push(this.$el);
    binding = bindingMaker.apply(null, args);
    return this.addBinding(binding);
  };

  _Class.prototype.unbind = function() {
    var binding, _i, _len, _ref, _results;
    _ref = this._bindings;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      binding = _ref[_i];
      _results.push(binding._unbind());
    }
    return _results;
  };

  return _Class;

})();

Tendon.Simple = function(el, action, condition, listen) {
  var eventNames, handle, target, _i, _len, _ref, _ref1, _results;
  handle = function() {
    var val;
    val = condition.checker();
    return action(el, val);
  };
  handle();
  _ref = condition.events;
  _results = [];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    _ref1 = _ref[_i], target = _ref1[0], eventNames = _ref1[1];
    _results.push(listen(target, eventNames, handle));
  }
  return _results;
};
