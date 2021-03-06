// Generated by CoffeeScript 1.4.0
var HomeView, IndexView, PagesView, ProfileView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

IndexView = (function(_super) {

  __extends(IndexView, _super);

  function IndexView() {
    this.render = __bind(this.render, this);
    return IndexView.__super__.constructor.apply(this, arguments);
  }

  IndexView.bodyClass = 'landing-page';

  IndexView.prototype.documentTitle = 'Welcome to Jotleaf';

  IndexView.prototype.render = function() {
    var content, context;
    context = this.commonContext();
    content = ich.tpl_index(context);
    this.setElement(content);
    return this.$findOne('.front-bg').show();
  };

  return IndexView;

})(BaseRegistration);

HomeView = (function(_super) {

  __extends(HomeView, _super);

  function HomeView() {
    this._newPage = __bind(this._newPage, this);

    this.unbind = __bind(this.unbind, this);
    return HomeView.__super__.constructor.apply(this, arguments);
  }

  HomeView.prototype.documentTitle = 'Home';

  HomeView.bodyClass = 'home';

  HomeView.prototype.initialize = function() {
    var _this = this;
    this.makeMainWebsiteView('tpl_home');
    this._newsfeed = new NewsFeed();
    this._newsfeedView = this.makeSubviewInContainer(NewsFeedView, '.news-feed', {
      model: this._newsfeed
    });
    this._newsfeed.subscribe();
    this.makeSubviewInContainer(SuggestedFollowsView, '.suggested-friends');
    return setTimeout(function() {
      return _this.$findOne('input.title-input').focus();
    }, 0);
  };

  HomeView.prototype.events = {
    'submit form.new-page': '_newPage'
  };

  HomeView.prototype.unbind = function() {
    return this._newsfeed.unsubscribe();
  };

  HomeView.prototype._newPage = function(e) {
    var button, create, data, error, form, origVal, title,
      _this = this;
    e.preventDefault();
    form = this.$findOne('form.new-page');
    form.find('input').attr('disabled', 'disabled');
    title = form.findOne('input[type=text]');
    button = form.findOne('input[type=submit]');
    error = this.$findOne('div.new-page.error');
    origVal = button.val();
    error.hide();
    button.val('Creating...');
    data = {
      title: form.findOne('input[type=text]').val()
    };
    create = API.xhrMethod('new-page', data);
    create.done(function(response) {
      if (response.success) {
        mixpanel.track("Page created", {
          "Quick page": false
        });
        button.val('Created!');
        return router.internalNavigate(response.data.get_absolute_url);
      } else if (response.status_code === 403) {
        JL.AuthState.setUser(null);
        _this.queueSuccessMessage("You have been logged out. Please login again.");
        return router._redirect('account/login/');
      }
    });
    return create.fail(function(err) {
      log("Creating page failed:", err);
      button.val(origVal);
      form.find('input').attr('disabled', false);
      return error.show();
    });
  };

  return HomeView;

})(TopView);

PagesView = (function(_super) {

  __extends(PagesView, _super);

  function PagesView() {
    this._pageOptions = __bind(this._pageOptions, this);

    this._newPage = __bind(this._newPage, this);
    return PagesView.__super__.constructor.apply(this, arguments);
  }

  PagesView.prototype.documentTitle = 'Pages';

  PagesView.bodyClass = 'pages';

  PagesView.prototype.initialize = function() {
    var _this = this;
    this.makeMainWebsiteView('tpl_pages');
    this.makeSubviewInContainer(YourPages, '.page-list');
    this.makeSubviewInContainer(SuggestedFollowsView, '.suggested-friends');
    return setTimeout(function() {
      return _this.$findOne('input.title-input').focus();
    }, 0);
  };

  PagesView.prototype.events = {
    'submit form.new-page': '_newPage',
    'click .options-button': '_pageOptions'
  };

  PagesView.prototype._newPage = function(e) {
    var button, create, data, error, form, origVal, title,
      _this = this;
    e.preventDefault();
    form = this.$findOne('form.new-page');
    form.find('input').attr('disabled', 'disabled');
    title = form.findOne('input[type=text]');
    button = form.findOne('input[type=submit]');
    error = this.$findOne('div.new-page.error');
    origVal = button.val();
    error.hide();
    button.val('Creating...');
    data = {
      title: form.findOne('input[type=text]').val()
    };
    create = API.xhrMethod('new-page', data);
    create.done(function(response) {
      if (response.success) {
        mixpanel.track("Page created", {
          "Quick page": false
        });
        button.val('Created!');
        return router.internalNavigate(response.data.get_absolute_url);
      } else if (response.status_code === 403) {
        JL.AuthState.setUser(null);
        _this.queueSuccessMessage("You have been logged out. Please login again.");
        return router._redirect('account/login/');
      }
    });
    return create.fail(function(err) {
      log("Creating page failed:", err);
      button.val(origVal);
      form.find('input').attr('disabled', false);
      return error.show();
    });
  };

  PagesView.prototype._pageOptions = function(e) {
    var KEY, row, v;
    KEY = 'optionsView';
    row = $(e.target).parents('.page-listing');
    assert(row.length);
    assert(row.data('pageid'));
    v = row.data(KEY);
    if (v) {
      return v.toggle();
    } else {
      v = new OptionsView({
        pageId: row.data('pageid'),
        row: row
      });
      this.addSubView(v);
      v.render();
      v.$el.insertAfter(row);
      v.show();
      return row.data(KEY, v);
    }
  };

  return PagesView;

})(TopView);

ProfileView = (function(_super) {

  __extends(ProfileView, _super);

  function ProfileView() {
    this._gotFollows = __bind(this._gotFollows, this);

    this.unbind = __bind(this.unbind, this);

    this._gotUser = __bind(this._gotUser, this);
    return ProfileView.__super__.constructor.apply(this, arguments);
  }

  ProfileView.bodyClass = 'profile-page';

  ProfileView.prototype.documentTitle = function() {
    return "" + this.options.username + "'s Profile";
  };

  ProfileView.prototype.initialize = function() {
    var u;
    this.makeMainWebsiteView('tpl_loading_msg');
    u = Database.modelDB(User).fetchBy('username', this.options.username);
    u.fail(router.do404);
    return u.done(this._gotUser);
  };

  ProfileView.prototype._gotUser = function(user) {
    var isYou, showFollow;
    log("got user", user);
    this.user = user;
    isYou = user.get('id') === JL.AuthState.getUserId();
    if (isYou) {
      $('body').addClass('myprofile');
    }
    showFollow = !isYou;
    API.xhrMethod('get-follows', {
      user_id: user.id
    }).done(this._gotFollows);
    this.content.empty();
    this.content.append(ich.tpl_show_user({
      username: user.get('username'),
      bio: user.get('bio'),
      showFollow: showFollow
    }));
    if (showFollow) {
      this._checkBoxBtn = makeFollowButton(this.$findOne('.follow'), user);
    }
    return this.makeSubviewInContainer(ProfilePageListView, '.page-list-items', {
      user: user
    });
  };

  ProfileView.prototype.unbind = function() {
    var _ref;
    log("unbinding", this);
    return (_ref = this._checkBoxBtn) != null ? _ref.destroy() : void 0;
  };

  ProfileView.prototype._gotFollows = function(models) {
    var el, f, followDB, followerIds, followers, friendIds, friends, i, len, profileLink, u, uid, user, userDB, username, users, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1;
    log("Got models", models);
    userDB = Database2.modelDB(User);
    followDB = Database2.modelDB(Follow);
    _ref = models.user;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      u = _ref[_i];
      userDB.addObject(u);
    }
    _ref1 = models.follow;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      f = _ref1[_j];
      followDB.addObject(f);
    }
    friends = followDB.getCollection(this.user.id);
    friendIds = friends.pluck('target_id');
    followers = followDB.search({
      target_id: this.user.id
    });
    followerIds = (function() {
      var _k, _len2, _results;
      _results = [];
      for (_k = 0, _len2 = followers.length; _k < _len2; _k++) {
        f = followers[_k];
        _results.push(f.attributes.user_id);
      }
      return _results;
    })();
    if (friendIds.length) {
      el = this.$findOne('.friends');
      el.text("Following:");
      users = $('<div>');
      len = friendIds.length;
      for (i = _k = 0, _len2 = friendIds.length; _k < _len2; i = ++_k) {
        uid = friendIds[i];
        user = userDB.get(uid);
        username = user.get('username');
        profileLink = $('<a>').text(username).attr('href', user.profileUrl());
        users.append(profileLink);
        if (i + 1 < len) {
          users.append(document.createTextNode(', '));
        }
      }
      el.append(users).show();
    }
    if (followerIds.length) {
      el = this.$findOne('.followers');
      el.text("Followers:");
      users = $('<div>');
      len = followerIds.length;
      for (i = _l = 0, _len3 = followerIds.length; _l < _len3; i = ++_l) {
        uid = followerIds[i];
        user = userDB.get(uid);
        username = user.get('username');
        profileLink = $('<a>').text(username).attr('href', user.profileUrl());
        profileLink.attr('title', user.get('bio'));
        users.append(profileLink);
        if (i + 1 < len) {
          users.append(document.createTextNode(', '));
        }
      }
      return el.append(users).show();
    }
  };

  return ProfileView;

})(TopView);
