// Generated by CoffeeScript 1.4.0
var CheckboxButton, TabbedPane,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

TabbedPane = (function() {

  function TabbedPane(element) {
    this.activate = __bind(this.activate, this);

    this.show = __bind(this.show, this);

    var _this = this;
    this.root = $(element);
    this.tabs = this.root.findOne('ul.tabs-nav');
    this.content = this.root.findOne('div.tabs-content');
    this.tabs.on('click', 'li', function(e) {
      var target;
      target = $(e.target);
      return _this.show(target);
    });
  }

  TabbedPane.prototype.show = function(element) {
    var selector, target;
    selector = element.data('target');
    if (element.hasClass('active')) {
      return;
    }
    target = this.content.findOne(selector).closest(".tabs-pane");
    this.activate(element, this.tabs);
    return this.activate(target, this.content);
  };

  TabbedPane.prototype.activate = function(element, container) {
    container.find('.active').removeClass('active');
    return element.addClass('active');
  };

  return TabbedPane;

})();

CheckboxButton = (function() {

  CheckboxButton.prototype.CLASSES = {
    YES: 'btn-yes',
    NO: 'btn-no',
    YES_HOVER: 'btn-yes-to-no',
    NO_HOVER: 'btn-no-to-yes'
  };

  function CheckboxButton(element, options) {
    this.element = element;
    this.options = options;
    this._unbindEvents = __bind(this._unbindEvents, this);

    this.destroy = __bind(this.destroy, this);

    this._clearClasses = __bind(this._clearClasses, this);

    this._setBaseClass = __bind(this._setBaseClass, this);

    this._bindEvents = __bind(this._bindEvents, this);

    this._setValue = __bind(this._setValue, this);

    this._getValue = __bind(this._getValue, this);

    if (this.options.model && this.options.attribute) {
      this.model = this.options.model;
      this.attribute = this.options.attribute;
    } else {
      assert(this.options.getter && this.options.setter);
      this.getter = this.options.getter;
      this.setter = this.options.setter;
    }
    this._setBaseClass();
    this._bindEvents();
  }

  CheckboxButton.prototype._getValue = function() {
    if (this.getter) {
      return this.getter();
    } else {
      return this.model.get(this.attribute);
    }
  };

  CheckboxButton.prototype._setValue = function(newVal) {
    if (this.setter) {
      return this.setter(newVal);
    } else {
      return this.model.edit(this.attribute, newVal);
    }
  };

  CheckboxButton.prototype._bindEvents = function() {
    var _this = this;
    this.element.mouseenter(function() {
      _this._clearClasses();
      if (_this._getValue()) {
        return _this.element.addClass(_this.CLASSES.YES_HOVER);
      } else {
        return _this.element.addClass(_this.CLASSES.NO_HOVER);
      }
    });
    this.element.mouseleave(function() {
      _this._clearClasses();
      return _this._setBaseClass();
    });
    return this.element.click(function() {
      _this._setValue(!_this._getValue());
      _this._clearClasses();
      return _this._setBaseClass();
    });
  };

  CheckboxButton.prototype._setBaseClass = function() {
    if (this._getValue()) {
      return this.element.addClass(this.CLASSES.YES);
    } else {
      return this.element.addClass(this.CLASSES.NO);
    }
  };

  CheckboxButton.prototype._clearClasses = function() {
    return this.element.removeClass(_.values(this.CLASSES).join(' '));
  };

  CheckboxButton.prototype.destroy = function() {
    return this._unbindEvents();
  };

  CheckboxButton.prototype._unbindEvents = function() {
    return this.element.off('mouseenter mouseleave click');
  };

  return CheckboxButton;

})();
