# views_home.coffee is for TopViews other than those that are related just to authentication/accounts and the leaf-viewer

class IndexView extends BaseRegistration
  @bodyClass: 'landing-page'

  documentTitle: 'Welcome to Jotleaf'

  render: =>
    context = @commonContext()
    content = ich.tpl_index(context)
    @setElement(content)
    @$findOne('.front-bg').show() #remove?


class HomeView extends TopView
  documentTitle: 'Home'

  @bodyClass: 'home'

  initialize: ->
    @makeMainWebsiteView('tpl_home')
    @_newsfeed = new NewsFeed()
    @_newsfeedView = @makeSubviewInContainer(NewsFeedView, '.news-feed',{ model: @_newsfeed})
    @_newsfeed.subscribe()
    @makeSubviewInContainer(SuggestedFollowsView, '.suggested-friends')
    setTimeout(=>
      @$findOne('input.title-input').focus()
    , 0)

  events: {
    'submit form.new-page': '_newPage'
  }

  unbind: =>
    @_newsfeed.unsubscribe()

  # TODO: DRY with pagesview somehow: identical
  _newPage: (e) =>
    e.preventDefault()
    form = @$findOne('form.new-page')
    form.find('input').attr('disabled', 'disabled')
    title = form.findOne('input[type=text]')
    button = form.findOne('input[type=submit]')
    error = @$findOne('div.new-page.error')
    origVal = button.val()
    error.hide()
    button.val('Creating...')
    data = {
      title: form.findOne('input[type=text]').val()
    }
    create = API.xhrMethod('new-page', data)
    create.done((response) =>
      if response.success
        mixpanel.track("Page created", {
          "Quick page": false
        })
        button.val('Created!')
        router.internalNavigate(response.data.get_absolute_url)
      else if response.status_code == 403
        # The user has been unexpectedly logged out
        JL.AuthState.setUser(null)
        @queueSuccessMessage("You have been logged out. Please login again.")
        router._redirect('account/login/')
    )
    create.fail((err) =>
      log "Creating page failed:", err
      button.val(origVal)
      form.find('input').attr('disabled', false)
      error.show()
    )

class PagesView extends TopView
  documentTitle: 'Pages'

  @bodyClass: 'pages'

  initialize: ->
    @makeMainWebsiteView('tpl_pages')
    @makeSubviewInContainer(YourPages, '.page-list')
    @makeSubviewInContainer(SuggestedFollowsView, '.suggested-friends')
    setTimeout(=>
      @$findOne('input.title-input').focus()
    , 0)

  events: {
    'submit form.new-page': '_newPage'
    'click .options-button': '_pageOptions'
  }

  _newPage: (e) =>
    e.preventDefault()
    form = @$findOne('form.new-page')
    form.find('input').attr('disabled', 'disabled')
    title = form.findOne('input[type=text]')
    button = form.findOne('input[type=submit]')
    error = @$findOne('div.new-page.error')
    origVal = button.val()
    error.hide()
    button.val('Creating...')
    data = {
      title: form.findOne('input[type=text]').val()
    }
    create = API.xhrMethod('new-page', data)
    create.done((response) =>
      if response.success
        mixpanel.track("Page created", {
          "Quick page": false
        })
        button.val('Created!')
        router.internalNavigate(response.data.get_absolute_url)
      else if response.status_code == 403
        # The user has been unexpectedly logged out
        JL.AuthState.setUser(null)
        @queueSuccessMessage("You have been logged out. Please login again.")
        router._redirect('account/login/')
    )
    create.fail((err) =>
      log "Creating page failed:", err
      button.val(origVal)
      form.find('input').attr('disabled', false)
      error.show()
    )

  _pageOptions: (e) =>
    KEY = 'optionsView'

    row = $(e.target).parents('.page-listing')
    assert row.length
    assert row.data('pageid')
    v = row.data(KEY)
    if v
      v.toggle()
    else
      v = new OptionsView(
        pageId: row.data('pageid') # comes from HTML template
        row: row # passed this so it can hide it when deleting
      )
      @addSubView(v)
      v.render()
      v.$el.insertAfter(row)
      v.show()
      row.data(KEY, v)

class ProfileView extends TopView
  @bodyClass: 'profile-page'

  documentTitle: ->
      return "#{@options.username}'s Profile"

  initialize: ->
    # TODO: canonicalize URL
    @makeMainWebsiteView('tpl_loading_msg')
    u = Database.modelDB(User).fetchBy('username', @options.username)
    u.fail(router.do404)
    u.done(@_gotUser)

  _gotUser: (user) =>
    log "got user", user
    @user = user
    isYou = user.get('id') == JL.AuthState.getUserId()
    if isYou
      $('body').addClass('myprofile')

    showFollow = not isYou

    API.xhrMethod('get-follows', {user_id: user.id}).done(@_gotFollows)

    @content.empty()
    @content.append(ich.tpl_show_user({
      username: user.get('username')
      bio: user.get('bio')
      showFollow: showFollow
    }))

    if showFollow
      @_checkBoxBtn = makeFollowButton(@$findOne('.follow'), user)


    @makeSubviewInContainer(ProfilePageListView, '.page-list-items',{user: user})

  unbind: =>
    log "unbinding", @
    @_checkBoxBtn?.destroy()

  _gotFollows: (models) =>
    log "Got models", models
    userDB = Database2.modelDB(User)
    followDB = Database2.modelDB(Follow)
    for u in models.user
      userDB.addObject(u)
    for f in models.follow
      followDB.addObject(f)
    friends = followDB.getCollection(@user.id)
    friendIds = friends.pluck('target_id')
    followers = followDB.search({target_id: @user.id})
    followerIds = (f.attributes.user_id for f in followers)

    # Render friends div
    if friendIds.length
      el = @$findOne('.friends')
      el.text("Following:")
      users = $('<div>')
      len = friendIds.length
      for uid, i in friendIds
        user = userDB.get(uid)
        username = user.get('username')
        profileLink = $('<a>').text(username).attr('href', user.profileUrl())
        users.append(profileLink)
        if i + 1 < len
          users.append(document.createTextNode(', '))
      el.append(users).show()
      
    # Render followers div
    # TODO: DRY with above
    if followerIds.length
      el = @$findOne('.followers')
      el.text("Followers:")
      users = $('<div>')
      len = followerIds.length
      for uid, i in followerIds
        user = userDB.get(uid)
        username = user.get('username')
        profileLink = $('<a>').text(username).attr('href', user.profileUrl())
        profileLink.attr('title', user.get('bio'))
        users.append(profileLink)
        if i + 1 < len
          users.append(document.createTextNode(', '))
      el.append(users).show()
