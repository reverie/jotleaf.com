// Generated by CoffeeScript 1.4.0
var AFFILIATIONS, PERMISSIONS, Permissions,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

AFFILIATIONS = {
  OWNER: 1,
  MEMBER: 3,
  NONE: 5
};

PERMISSIONS = {
  OWNER: 1,
  MEMBER: 3,
  PUBLIC: 5
};

Permissions = new ((function() {

  function _Class() {
    this.canEditItem = __bind(this.canEditItem, this);

    this.currentUserCanInsertImageItem = __bind(this.currentUserCanInsertImageItem, this);

    this.currentUserIsItemCreator = __bind(this.currentUserIsItemCreator, this);

    this.currentUserCanInsertTextItem = __bind(this.currentUserCanInsertTextItem, this);

    this.currentUserCanEditPage = __bind(this.currentUserCanEditPage, this);

  }

  _Class.prototype.currentUserCanEditPage = function(page) {
    var expectedCookie, user;
    user = JL.AuthState.getUser();
    if (page.getAffiliation(user) === AFFILIATIONS.OWNER) {
      return true;
    }
    expectedCookie = 'claim-' + page.id;
    return Boolean($.cookie(expectedCookie));
  };

  _Class.prototype.currentUserCanInsertTextItem = function(page) {
    var affiliation, text_writability, user;
    if (this.currentUserCanEditPage(page)) {
      return true;
    }
    user = JL.AuthState.getUser();
    text_writability = page.get('text_writability');
    affiliation = page.getAffiliation(user);
    return text_writability >= affiliation;
  };

  _Class.prototype.currentUserIsItemCreator = function(item) {
    var itemCreatorId, itemWindowId, user, userId, windowId;
    user = JL.AuthState.getUser();
    windowId = API.WINDOW_ID;
    itemWindowId = item.get('creator_window_id');
    if (itemWindowId && (itemWindowId === windowId)) {
      return true;
    }
    userId = user.id;
    itemCreatorId = item.get('creator_id');
    if (!(itemCreatorId && userId)) {
      return false;
    }
    assert(_.isNumber(itemCreatorId));
    assert(_.isNumber(userId));
    return itemCreatorId === userId;
  };

  _Class.prototype.currentUserCanInsertImageItem = function(page) {
    var affiliation, image_writability, user;
    if (this.currentUserCanEditPage(page)) {
      return true;
    }
    user = JL.AuthState.getUser();
    image_writability = page.get('image_writability');
    affiliation = page.getAffiliation(user);
    return image_writability >= affiliation;
  };

  _Class.prototype.canEditItem = function(item) {
    var page, userCanInsertItem;
    page = item.page;
    if (this.currentUserCanEditPage(page)) {
      return true;
    }
    userCanInsertItem = true;
    if (item instanceof TextItem) {
      userCanInsertItem = this.currentUserCanInsertTextItem(page);
    } else if (item instanceof ImageItem || item instanceof EmbedItem) {
      userCanInsertItem = this.currentUserCanInsertImageItem(page);
    }
    if (userCanInsertItem && this.currentUserIsItemCreator(item)) {
      return true;
    }
  };

  return _Class;

})());
