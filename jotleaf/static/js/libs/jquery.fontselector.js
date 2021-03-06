// Generated by CoffeeScript 1.4.0
var FontSelector,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

FontSelector = (function() {

  function FontSelector(element, options) {
    this.unbindEvents = __bind(this.unbindEvents, this);

    this.destroy = __bind(this.destroy, this);

    this.close = __bind(this.close, this);

    this.open = __bind(this.open, this);

    this.getSelected = __bind(this.getSelected, this);

    this.setSelected = __bind(this.setSelected, this);

    this.bindEvents = __bind(this.bindEvents, this);
    this.options = $.extend({
      selected: function(style) {},
      className: 'open'
    }, options);
    this.root = element;
    this.initial = this.root.findOne('.initial');
    this.ul = this.root.findOne("ul");
    this.root.data('fontselector', this);
    this.ul.hide();
    this._visible = false;
    this.setSelected(this.options.initial[1], this.options.initial[2]);
    this.ul.find("li").each(function() {
      var $t, family;
      $t = $(this);
      family = $t.data('font-family');
      return $t.css("font-family", family);
    });
    this.bindEvents();
  }

  FontSelector.prototype.bindEvents = function() {
    var _this = this;
    this.initial.click(this.open);
    this.ul.on('click', 'li', function(e) {
      var $t, displayName, family;
      $t = $(e.target);
      family = $t.data('font-family');
      displayName = $t.text();
      _this.setSelected(family, displayName);
      _this.root.trigger('fontChange', [family]);
      _this.options.selected(family);
      return _this.close();
    });
    return $("html").click(this.close);
  };

  FontSelector.prototype.setSelected = function(family, displayName) {
    var unquoted;
    unquoted = family.replace(/'/g, '');
    this._selected = unquoted;
    this.initial.css("font-family", family);
    return this.initial.text(displayName);
  };

  FontSelector.prototype.getSelected = function() {
    return this._selected;
  };

  FontSelector.prototype.open = function() {
    var _this = this;
    if (this._visible) {
      return;
    }
    this.root.addClass(this.options.className);
    this.ul.outerWidth(this.initial.outerWidth());
    return this.ul.slideDown("fast", function() {
      _this.ul.css('overflow', 'auto');
      _this.ul.css('overflow-y', 'auto');
      return _this._visible = true;
    });
  };

  FontSelector.prototype.close = function() {
    var _this = this;
    if (!this._visible) {
      return;
    }
    return this.ul.slideUp("fast", function() {
      _this.root.removeClass(_this.options.className);
      return _this._visible = false;
    });
  };

  FontSelector.prototype.destroy = function() {
    return this.unbindEvents();
  };

  FontSelector.prototype.unbindEvents = function() {
    var _ref;
    if ((_ref = this.ul) != null) {
      _ref.off('click', 'li');
    }
    $("html").off('click', this.close);
    return this.initial.off('click', this.open);
  };

  return FontSelector;

})();
