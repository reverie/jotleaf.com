// Generated by CoffeeScript 1.4.0
var Error403, Error404,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Error404 = (function(_super) {

  __extends(Error404, _super);

  function Error404() {
    return Error404.__super__.constructor.apply(this, arguments);
  }

  Error404.prototype.documentTitle = 'Page Not Found';

  Error404.prototype.initialize = function() {
    return this.makeMainWebsiteView('tpl_404');
  };

  return Error404;

})(TopView);

Error403 = (function(_super) {

  __extends(Error403, _super);

  function Error403() {
    return Error403.__super__.constructor.apply(this, arguments);
  }

  Error403.prototype.documentTitle = 'Permission Denied';

  Error403.prototype.initialize = function() {
    return this.makeMainWebsiteView('tpl_permission_denied', {
      username: this.options.username
    });
  };

  return Error403;

})(TopView);