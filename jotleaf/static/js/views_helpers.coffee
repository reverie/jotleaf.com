makeFollowButton = (el, user) ->
  if JL.AuthState.isAuthenticated()
    currentUid = JL.AuthState.getUserId()
    followDB = Database2.modelDB(Follow)
    currentUserFollows = followDB.getCollection(currentUid)
    getFollow = F.partial(currentUserFollows.checkFollows, user)
    setFollow = F.partial(currentUserFollows.setFollows, user)
  else
    getFollow = -> false
    setFollow = -> router.internalNavigate(URLs.auth_login)

  new CheckboxButton(el, {
    getter: getFollow
    setter: setFollow
  })
