# views_base.coffee is for the 'base' models that other Backbone.Views derive
# from, and methods/data shared between views

makeUrl = (content, render) ->
  assert URLs[content]
  URLs[content]

makeMessage = (msgName) ->
  assert msgs[msgName]
  msgs[msgName]


URLs = {
  registration_register: '/account/register/'
  auth_login: '/account/login/'
  settings: '/account/settings/'
  quick_page: '/new'
  home: '/home/'
  pages: '/pages/'
  explore: '#'
}

msgs = {
  password_reset_success: "We have sent you an email with a link to reset your password. Please check your email and click the link to continue."
  password_reset_confirm_success: "Your password has been reset! You may now log in."
  registration_success: "Congratulations, you have successfully registered!"
  registration_error: "Sorry, something went wrong with your request! Please try again."
  logout_success: "Successfully logged out!"
  logout_error: "Log out failed. Try reloading the page."
  page_claim_yes_success: "You have claimed the page."
  page_claim_no_success: "The page has been disowned into oblivion."
}

class JLView extends Backbone.View
  # JLView has our custom view methods that both top-level-page views, and
  # sub-component views, might both want to use
  $findOne: =>
    @$el.findOne(arguments...)

  # todo: rename 'commonContext'
  commonContext: =>
    return {
      STATIC_URL: JL_CONFIG.STATIC_URL
      url: -> makeUrl # is there a better way?
      isAuthenticated: JL.AuthState.isAuthenticated()
      username: JL.AuthState.getUsername()
    }

  # Useful for Moustache templates
  contextToArg: (method) =>
    return (a...) ->
      args = [@]
      args = args.concat(a)
      return method(args...)

  _truncatedContent: (ctx, maxLen=40) =>
    if ctx.content.length > maxLen
      return ctx.content.slice(0, maxLen) + '...'
    else
      return ctx.content

  _isYou: (ctx) =>
    return ctx.creator_id and (ctx.creator_id == JL.AuthState.getUserId())

  listenTo: (obj, name, callback) ->
    @_listeners ||= {}
    id = obj._listenerId || (obj._listenerId = _.uniqueId('l'))
    @_listeners[id] = [obj, name, callback]
    if obj instanceof jQuery
      obj.on(name, callback)
    else
      if name instanceof Object
        callback = @
      obj.on(name, callback, @)
    @

  stopListening: (obj, name, callback) ->
    if !@_listeners 
      return
    if obj
      if obj instanceof jQuery
        obj.off(name, callback)
      else
        if name instanceof Object
          callback = @
        obj.off(name, callback, @)
      if !(name || callback) 
        delete @_listeners[obj._listenerId]
    else
      if name instanceof Object
        callback = @
      for [obj, storedName, storedCallback] in _.values(@_listeners)
        if obj instanceof jQuery
          # limit scope of jquery off calls to events
          # and callback we have bound
          obj.off(storedName, storedCallback)
        else 
          obj.off(name, callback, @)
      @_listeners = {}
    @    

  destroy: =>
    log "destroying jlview", @
    log "calling unbind", @
    @unbind()
    @remove()    

  unbind: =>
    log "base unbind", @

class TopView extends JLView
  # TopView is the base for top-level page views, ie views that fill the
  # whole window, as opposed to sub-components.

  documentTitle: 'Jotleaf'

  wantsToHandle: (options) =>
    # Used by internal navigation system.
    # Does this (top-level) page view want to handle `options`, as opposed
    # to a new full-page navigation?
    log "can't handle it"
    return false
  
  handle: ->
    throw NotImplemented

  makeSubviewInContainer: (SubView, selector, options={}) =>
    options.el = @$findOne(selector)
    options.topView = @
    view = new SubView(options)
    @addSubView(view)
    return view

  addSubView: (subview) =>
    @subviews ||= []
    @subviews.push(subview) 

  makeMainWebsiteView: (tplName, context={}) =>
    baseContext = @commonContext()
    base = ich.tpl_main_website(baseContext)
    fullContext = _.extend(baseContext, context)
    content = ich[tplName](fullContext)
    @content = base.findOne('.content')
    @content.append(content)
    @setElement(base)

    @_messagesView = @makeSubviewInContainer(MessagesView, '.messages-container')
    @makeSubviewInContainer(ClaimsView, '.claim-notifications-container')
    if JL.queuedMessages.length
      @_messagesView.showMessages(JL.queuedMessages)
      JL.queuedMessages = []

  _stringsToMessages:(msgStrings, type) =>
    if not msgStrings.length
      return []
    messageObjects = []
    for msg in msgStrings
      messageObjects.push({
        tags: type,
        text: msg
      })
    return messageObjects

  queueSuccessMessages: (msgs) =>
    msgObjects = @_stringsToMessages(msgs, "success-message")
    JL.queuedMessages = _.union(JL.queuedMessages, msgObjects)

  showSuccessMessages: (msgs) =>
    @_messagesView.showMessages(@_stringsToMessages(msgs, "success-message"))

  queueErrorMessages: (msgs) =>
    msgObjects = @_stringsToMessages(msgs, "error-message")
    JL.queuedMessages = _.union(JL.queuedMessages, msgObjects)

  showErrorMessages: (msgs) =>
    @_messagesView.showMessages(@_stringsToMessages(msgs, "error-message"))

  queueSuccessMessage: (msg) =>
    @queueSuccessMessages([msg])

  showSuccessMessage: (msg) =>
    @showSuccessMessages([msg])

  queueErrorMessage: (msg) =>
    @queueErrorMessages([msg])

  showErrorMessage: (msg) =>
    @showErrorMessages([msg])

  setFirstFocus: (selector) =>
    @listenTo(@, 'dom-insert', =>
      if document.activeElement.tagName == 'BODY'
        @$findOne(selector).focus()
    )

  destroy: =>
    if @subviews
      while @subviews.length
        subview = @subviews.pop()
        subview.destroy()
    super

class BaseRegistration extends TopView
  initialize: =>
    @render()
    errorContainer = @$findOne('.error-container')
    form = @$findOne('form.registration-form')
    @errorsView = new ErrorsView(form, errorContainer)
    @setFirstFocus('input.username')

    # ywot transfer JS
    url = "#{JL_CONFIG.STATIC_URL}js/ywot_registration.js"
    $.getScript(url)

  render: =>
    # subclasses must implement this!
    throw NotImplemented

  events: {
    'submit form.registration-form': '_register'
  }

  _register: (e) =>
    log "Submit from registration form detected", e
    e.preventDefault()

    form = $(e.target)
    form.find('input').attr('disabled', 'disabled')
    username = form.findOne('input.username').val()
    email = form.findOne('input.email').val()
    password = form.findOne('input.password').val()

    button = form.findOne('input[type=submit]')
    origVal = button.val()

    @errorsView.clearErrors()
    button.val('Registering...')

    registration = $.ajax( {
      url: '/xhr/account/register/',
      type: "POST",
      data: {
        email: email,
        password: password,  
        username: username,
      },
      dataType: "json"
      cache: false,
    })

    registration.done((response) =>
      if response.registration_successful
        # mixpanel.alias call must come before setting AuthState, which
        # triggers trackMixpanelUser.
        assert response.user.id
        mixpanel.alias(response.user.id)
        mixpanel.track("New user signup")
        JL.AuthState.setUser(response.user)
        @queueSuccessMessage(makeMessage('registration_success'))
        router.navigate('/home/', {trigger: true})
      else
        log "registration errors", response.errors
        @errorsView.showErrors(response.errors)
        button.val(origVal)
        form.find('input').attr('disabled', false)
    )
    registration.fail((err)=>
      button.val(origVal)
      form.find('input').attr('disabled', false)
      @errorsView.requestFailed(makeMessage('registration_error'))
    )

