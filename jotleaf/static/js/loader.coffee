window.JL ||= {}

class AuthState
  constructor: (userAttributes) ->
    _.extend(@, Backbone.Events)
    @setUser(userAttributes)

  setUser: (userAttributes) =>
    @_user = new User(userAttributes)
    @trigger('change', @_user)

  getUser: =>
    assert @_user instanceof User
    return @_user

  isAuthenticated: =>
    !!(@_user.id)

  getUserId: =>
    return @_user?.get('id')

  getUsername: =>
    return @_user?.get('username')

hijackLinkBehavior = ->
  $(document).on('click', 'a', (e) -> 
    log "hijackLinkBehavior"

    a = $(@)

    # Special case for logout links to prevent CSRF
    if a.hasClass('authorized-logout')
      e.preventDefault()
      router.doLogout()
      return

    # Let it open in a new window if that's what it wants
    if a.attr('target') == '_blank'
      return
    
    # Ignore fake A tag -- someone else is on it
    if $(e.target).attr('href') == '#'
      return

    fullUrl = @href

    # If this link is to an external site, return, 
    # letting the default link action happen.
    if not testSameOrigin(fullUrl)
      return

    # Let them use browser keyboard shortcuts on internal links
    if e.metaKey or e.ctrlKey or e.altKey
        return

    # Now we're handling an internal URL
    e.preventDefault()
    log "link hijacked"
    path = @pathname
    router.internalNavigate(path)
  )

trackMixpanelUser = ->
  user = JL.AuthState.getUser()
  if user?.id
    mixpanel.identify(user.id)
    mixpanel.people.set({
      $username: user.get('username')
      $email: user.get('email')
    })

extractPageRouteOptions = (routeName, args...) ->
  switch routeName
    when 'showPage'
      [username, pageIdentifier] = args
      return {
        username: username
        pageIdentifier: pageIdentifier
      }
    when 'showPageId'
      [pageId] = args
      return {pageId: pageId}
    when 'showPageIdAtItem'
      [pageId, itemId] = args
      return{
        pageId: pageId
        initId: itemId
      }  
    when 'showPageAtItem'
      [username, pageIdentifier, itemId] = args
      return{
        username: username
        pageIdentifier: pageIdentifier
        initId: itemId
      }
    else
      throw new Error("Unknown page view #{routeName}")

router = new class extends Backbone.Router
  initialize: ->
    @container = $('#spa_container')

  routes: {
    '': 'index'
    'account/login/': 'login' 
    'home/': 'home'
    'pages/': 'pages'
    'new': 'quickPage' 
    'new/': 'quickPage' 
    'account/settings/': 'settings'
    'account/settings/unsubscribe/:emailType/:code/': 'unsubscribe'
    'account/register/': 'registration'
    'account/password/reset/': 'password_reset'
    'account/password/reset/confirm/:tokens/': 'password_reset_confirm'
    'account/password/reset/confirm/:tokens/': 'password_reset_confirm'
    ':username/': 'showUser'

    # Page viewers
    'page/:pageId/': 'showPageId'
    'page/:pageId/item-:itemId/': 'showPageIdAtItem'
    ':username/:pageIdentifier/': 'showPage'
    ':username/:pageIdentifier/item-:itemId/': 'showPageAtItem'

    '*path': 'default'
  }

  doPageRoute: (routeName, args...) =>
    # todo: canonicalize URLs
    options = extractPageRouteOptions(routeName, args...)
    router._doOuterPageView(options)

  showPage: (args...) => @doPageRoute('showPage', args...)
  showPageAtItem: (args...) => @doPageRoute('showPageAtItem', args...)
  showPageId: (args...) => @doPageRoute('showPageId', args...)
  showPageIdAtItem: (args...) => @doPageRoute('showPageIdAtItem', args...)

  # Used for internal navigation -- keep this updated and/or DRY w/above
  pageViews: ['showPageId', 'showPageIdAtItem', 'showPage', 'showPageAtItem']

  _getRouteName: (path) =>
    for pattern, routeName of @routes
      routeRegex = @_routeToRegExp(pattern)
      if routeRegex.test(path)
        return [routeRegex, routeName]
    throw new Error("unmatched internal route")

  _routeStripper: /^[#\/]|\s+$/g
  internalNavigate: (path) =>
    # Strip off slashes, hashes, spaces, etc. Taken from BB source.
    path = path.replace(@_routeStripper, '')

    # Called on intercepted internal links. We may want to do some special
    # behavior, such as scrolling to an item instead of reloading the page.
    [routeRegex, routeName] = @_getRouteName(path)

    # So far only page views have special handling:
    if routeName not in @pageViews
      @navigate(path, {trigger: true})
      return

    # Ok, now we're at the page view
    args = @_extractParameters(routeRegex, path)
    options = extractPageRouteOptions(routeName, args...)

    assert @_view, "internalNavigate without an existing view?"
    if @_view.wantsToHandle(options)
      # todo: option to replace URL or not?
      @_view.handleNewOptions(options)
    else
      @navigate(path, {trigger: true})
      return

  index: ->
    if JL.AuthState.isAuthenticated()
      @_redirect('home/')
    else
      @_setView(IndexView)
    
  login: ->
    if JL.AuthState.isAuthenticated()
      @_redirect('home/')
    else
      @_setView(LoginView)

  doLogout: ->
    # Special case for logging out.
    # There is intentionally no route mapped here.
    logout = API.xhrMethod('account/logout')
    logout.done((response) =>
      # hacky. todo: pull out QueuedMessage clas?
      @_view.queueSuccessMessage(makeMessage('logout_success'))
      JL.AuthState.setUser({})
      @_redirect(URLs.auth_login)
    )
    logout.fail((err) =>
      @_view.showErrorMessage(makeMessage('logout_error'))
    )

  home: ->
    if not JL.AuthState.isAuthenticated()
      @_redirect('account/login/')
    else
      @_setView(HomeView)

  pages: ->
    if not JL.AuthState.isAuthenticated()
      @_redirect('account/login/')
    else
      @_setView(PagesView)

  quickPage: ->
    quickPage = API.xhrMethod('quick-page')
    quickPage.done((response) =>
      if response.success
        mixpanel.track("Page created", {
          "Quick page": true
        })
        path = response.data.pageUrl
        @_redirect(path)
      else if response.status_code == 404
        @do404()
      else
        @do500()
    )
    quickPage.fail(@do500)

  settings: ->
    if not JL.AuthState.isAuthenticated()
      @_redirect('account/login/')
    else
      @_setView(SettingsView)

  unsubscribe: (emailType, token) ->
    @container.empty().text('Unsubscribing...')
    next = '/account/settings/'
    token = decodeURIComponent(token)
    [uid, username, xs...] = token.split('|')

    trackEvent = (success) ->
      mixpanel.track("Unsubscribe via email", {
        emailType: emailType
        success: success
      })

    refetchAndRedirect = =>
      u = JL.AuthState.getUser()
      u.fetch().always(=> @_redirect(next))

    r = API.xhrMethod('unsubscribe', {
      emailType: emailType
      token: token
    })
      
    r.done( =>
      trackEvent(true)
      # Note that user from email might be different from logged-in user. No better solution for now.
      if uid == JL.AuthState.getUserId()
        name = 'You'
      else
        name = username
      JL.queuedMessages.push({
        tags: 'success-message'
        text: "#{name} successfully unsubscribed."
      })
      refetchAndRedirect()
    )

    r.fail( =>
      trackEvent(false)
      refetchAndRedirect()
    )

  registration: ->
    @_setView(RegistrationView)

  password_reset: ->
    @_setView(PasswordResetView)

  password_reset_confirm: (tokens) ->
    @_setView(PasswordResetConfirmView, {tokens: tokens})

  showUser: (username) ->
    @_setView(ProfileView, {username: username})

  #showPageAtCoordinates: (x,y) =>
    #  # todo: I don't have a route :(
    #  # and i'm broke.
    #  appView = new OuterPageView({id: id, initX: x, initY: y, parent: @container})
    #  log "go to coords ",x,y, appView
    #  @_setView appView

  do403: (opt_username) =>
    @_setView(Error403, {
      username: opt_username
    })

  default: ->
    # Remove search queries, if there are any
    if window.location.search
      @_redirect(window.location.pathname)
    else
      $('body').text('Something went wrong :( Try reloading.')

  do404: =>
    # Call this method to replace the body with a 404 msg
    @_setView(Error404)

  do500: =>
    # TODO: use a view class
    @container.empty().text('500')

  _setView: (ViewClass, options) =>
    # Store old view
    oldView = @_view

    # Set body class, render, and insert into DOM
    $('body').removeClass().addClass(ViewClass.bodyClass)
    view = @_view = new ViewClass(options)
    @container.empty().append(view.el)
    view.trigger('dom-insert')

    # Set document.title
    oldView?.off('change-title', @_setTitle)
    oldView?.destroy()
    view.on('change-title', @_setTitle)
    @_setTitle(_.result(view, 'documentTitle'))

    # Reload Twitter & FB Widgets
    if window.twttr
      setTimeout( ->
        window.twttr.widgets.load() # undocumented yay
      , 0)
    if window.FB
      setTimeout( ->
        FB.XFBML.parse()
      , 0)

  _redirect: (path) =>
    @navigate(path, {trigger: true, replace:true})

  _doOuterPageView: (options) =>
    defaults = {
      fullscreen: true
    }
    options = _.extend(defaults, options)
    @_setView(OuterPageView, options)

  _setTitle: (newTitle) =>
    document.title = newTitle or 'Jotleaf'

JL_init = ->
  hijackLinkBehavior() 
  JL.queuedMessages = []
  JL.AuthState = new AuthState(JL_CONFIG.USER)
  trackMixpanelUser()
  JL.AuthState.on('change', trackMixpanelUser)

  followDB = Database2.modelDB(Follow)
  for f in JL_CONFIG.FOLLOWS
    followDB.addInstance(new Follow(f))

  Backbone.history.start({pushState: true, hashChange: false})

$(JL_init)

