// Generated by CoffeeScript 1.4.0
var makeFollowButton;

makeFollowButton = function(el, user) {
  var currentUid, currentUserFollows, followDB, getFollow, setFollow;
  if (JL.AuthState.isAuthenticated()) {
    currentUid = JL.AuthState.getUserId();
    followDB = Database2.modelDB(Follow);
    currentUserFollows = followDB.getCollection(currentUid);
    getFollow = F.partial(currentUserFollows.checkFollows, user);
    setFollow = F.partial(currentUserFollows.setFollows, user);
  } else {
    getFollow = function() {
      return false;
    };
    setFollow = function() {
      return router.internalNavigate(URLs.auth_login);
    };
  }
  return new CheckboxButton(el, {
    getter: getFollow,
    setter: setFollow
  });
};
