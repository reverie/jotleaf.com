// Generated by CoffeeScript 1.4.0
var Assets, BGPattern, Font, FontRegistry, ImageAtURL, PatternRegistry, bg_textures, fonts, loadGoogleFonts, _fontCmp,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

fonts = [['builtin', 'Arial', 'Arial'], ['builtin', 'Courier New', 'Courier New'], ['builtin', 'Comic Sans MS', 'Comic Sans'], ['builtin', 'Impact', 'Impact'], ['builtin', 'Verdana', 'Verdana', false], ['google', 'Open Sans', 'Open Sans'], ['google', 'Kreon', 'Kreon'], ['google', 'Lobster', 'Lobster'], ['google', 'Crafty Girls', 'Crafty'], ['google', 'Philosopher', 'Philosopher'], ['google', 'Marck Script', 'Marck Script'], ['google', 'Shadows Into Light', 'Shadows Into Light'], ['google', 'Lato', 'Lato', false]];

bg_textures = [["light_wool_alpha.png", [190, 191], false], ["clean_textile_alpha.png", [420, 420], false], ["arab_tile_alpha.png", [110, 110], false], ["gplaypattern_alpha.png", [188, 178], false], ["wall4_alpha.png", [300, 300], false], ["light_wood_alpha.png", [512, 512], false], ["green_dust_alpha.png", [592, 600], false], ["old_mathematics_alpha.png", [200, 200], false], ["greyfloral_alpha.png", [150, 124], false], ["custom-white-linen_alpha.png", [482, 490], false], ["carbon_fibre_alpha.png", [24, 22], false], ["light_wool_invalpha.png", [190, 191], false], ["clean_textile_invalpha.png", [420, 420], false], ["arab_tile_invalpha.png", [110, 110], false], ["gplaypattern_invalpha.png", [188, 178], false], ["wall4_invalpha.png", [300, 300], false], ["light_wood_invalpha.png", [512, 512], false], ["green_dust_invalpha.png", [592, 600], false], ["old_mathematics_invalpha.png", [200, 200], false], ["greyfloral_invalpha.png", [150, 124], false], ["custom-white-linen_invalpha.png", [482, 490], false], ["carbon_fibre_invalpha.png", [24, 22], false], ["custom-white-linen_midalpha.png", [482, 490], true], ["light_wool_midalpha.png", [190, 191], true], ["clean_textile_midalpha.png", [420, 420], true], ["arab_tile_midalpha.png", [110, 110], true], ["gplaypattern_midalpha.png", [188, 178], true], ["wall4_midalpha.png", [300, 300], true], ["light_wood_midalpha.png", [512, 512], true], ["green_dust_midalpha.png", [592, 600], true], ["old_mathematics_midalpha.png", [200, 200], true], ["greyfloral_midalpha.png", [150, 124], true], ["carbon_fibre_midalpha.png", [24, 22], true]];

loadGoogleFonts = function(familyList) {
  var args, f, link, url;
  familyList = (function() {
    var _i, _len, _results;
    _results = [];
    for (_i = 0, _len = familyList.length; _i < _len; _i++) {
      f = familyList[_i];
      _results.push(f.replace(' ', '+'));
    }
    return _results;
  })();
  args = familyList.join('|');
  url = "http://fonts.googleapis.com/css?family=" + args;
  link = $("<link rel='stylesheet' href='" + url + "' type='text/css' />");
  return $("head").append(link);
};

Font = (function() {

  function Font(category, family, displayName, isPageOption) {
    this.category = category;
    this.family = family;
    this.displayName = displayName;
    this.isPageOption = isPageOption != null ? isPageOption : true;
  }

  return Font;

})();

_fontCmp = function(a, b) {
  if ((a.family === '') || (a.displayName < b.displayName)) {
    return -1;
  }
  if ((b.family === '') || (b.displayName < a.displayName)) {
    return 1;
  }
  return 0;
};

FontRegistry = (function() {

  function FontRegistry() {
    this.getByFamily = __bind(this.getByFamily, this);

    this.list = __bind(this.list, this);

    this.ensureAllLoaded = __bind(this.ensureAllLoaded, this);

    this.add = __bind(this.add, this);
    this._fonts = {};
    this._loaded = {};
  }

  FontRegistry.prototype.add = function(font) {
    assert(!this._fonts[font.family]);
    return this._fonts[font.family] = font;
  };

  FontRegistry.prototype.ensureAllLoaded = function() {
    var familiesToLoad, family, font, _ref;
    familiesToLoad = [];
    _ref = this._fonts;
    for (family in _ref) {
      font = _ref[family];
      if (this._loaded[family]) {
        continue;
      }
      this._loaded[family] = true;
      if (font.category === 'builtin') {
        continue;
      }
      assert(font.category === 'google');
      familiesToLoad.push(family);
    }
    return loadGoogleFonts(familiesToLoad);
  };

  FontRegistry.prototype.list = function() {
    fonts = _.values(this._fonts);
    fonts = _.filter(fonts, F.get('isPageOption'));
    fonts.sort(_fontCmp);
    return fonts;
  };

  FontRegistry.prototype.getByFamily = function(family) {
    return this._fonts[family];
  };

  return FontRegistry;

})();

BGPattern = (function() {

  function BGPattern(name, size, showOption) {
    this.name = name;
    this.size = size;
    this.showOption = showOption;
    assert(/^[\w_-]+\.png$/.test(this.name));
    this.url = "" + JL_CONFIG.STATIC_URL + "patterns/" + this.name;
    this.id = this.name;
  }

  return BGPattern;

})();

ImageAtURL = (function() {

  function ImageAtURL(url, size, showOption) {
    this.url = url;
    this.size = size;
    this.showOption = showOption;
    this.id = url;
  }

  ImageAtURL.prototype.ensureSize = function(callback) {
    var i,
      _this = this;
    if (this.size) {
      return callback(this);
    } else {
      i = $('<img>').css({
        position: 'absolute',
        top: -10000,
        left: -1000
      });
      i.load(function() {
        _this.size = [i.width(), i.height()];
        i.remove();
        return callback(_this);
      });
      return i.appendTo($('body')).attr('src', this.url);
    }
  };

  return ImageAtURL;

})();

PatternRegistry = (function() {

  function PatternRegistry() {
    this.hasKey = __bind(this.hasKey, this);

    this.get = __bind(this.get, this);

    this.list = __bind(this.list, this);

    this.add = __bind(this.add, this);
    this._imgs = {};
    this._imgList = [];
  }

  PatternRegistry.prototype.add = function(img) {
    assert(!this._imgs[img.id]);
    this._imgs[img.id] = img;
    return this._imgList.push(img);
  };

  PatternRegistry.prototype.list = function() {
    var img;
    return (function() {
      var _i, _len, _ref, _results;
      _ref = this._imgList;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        img = _ref[_i];
        if (img.showOption) {
          _results.push(img);
        }
      }
      return _results;
    }).call(this);
  };

  PatternRegistry.prototype.get = function(imgId) {
    assert(this._imgs[imgId]);
    return this._imgs[imgId];
  };

  PatternRegistry.prototype.hasKey = function(imgId) {
    return this._imgs[imgId];
  };

  return PatternRegistry;

})();

Assets = new ((function() {

  function _Class() {
    this.isCustomPattern = __bind(this.isCustomPattern, this);

    var args, _i, _j, _len, _len1;
    this.Fonts = new FontRegistry();
    for (_i = 0, _len = fonts.length; _i < _len; _i++) {
      args = fonts[_i];
      this.Fonts.add((function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(Font, args, function(){}));
    }
    setTimeout(this.Fonts.ensureAllLoaded, 0);
    this.BGPatterns = new PatternRegistry();
    for (_j = 0, _len1 = bg_textures.length; _j < _len1; _j++) {
      args = bg_textures[_j];
      this.BGPatterns.add((function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(BGPattern, args, function(){}));
    }
  }

  _Class.prototype.isCustomPattern = function(url) {
    return url.indexOf('/') !== -1;
  };

  return _Class;

})());