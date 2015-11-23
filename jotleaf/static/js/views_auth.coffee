# views_auth.coffee is for TopViews related to authentication and accounts

class PasswordResetView extends TopView
  @bodyClass: 'password_reset'

  documentTitle: 'Reset Your Password'

  events: {
    'submit form.password-reset-form': '_password_reset'
  }

  initialize: ->
    @makeMainWebsiteView('tpl_password_reset')

    errorContainer = @$findOne('.error-container')
    form = @$findOne('form.password-reset-form')
    @errorsView = new ErrorsView(form, errorContainer)
    setTimeout(=>
      form.findOne('input.email').focus()
    , 0)


  _password_reset: (e) =>
    e.preventDefault()

    form = $(e.target)
    form.find('input').attr('disabled', 'disabled') 
    email = form.findOne('input.email').val()
    button = form.findOne('input[type=submit]')
    origVal = button.val()

    @errorsView.clearErrors()
    button.val('Processing...')

    password_reset = $.ajax( {
      url: '/xhr/account/password/reset/',
      type: "POST",
      data: {
        email: email
      },
      dataType: "json"
      cache: false,
    })


    password_reset.done((response) =>
      button.val(origVal)
      form.find('input').attr('disabled', false)

      if response.success
        @queueSuccessMessage(makeMessage('password_reset_success'))
        Backbone.history.navigate('/', {trigger: true})
      else
        @errorsView.showErrors(response.data)

    )
    password_reset.fail((err)=>
      # TODO: show an error message
      button.val(origVal)
      form.find('input').attr('disabled', false)
    )     

class PasswordResetConfirmView extends TopView
  @bodyClass: 'password_reset_confirm'

  documentTitle: 'Confirm Resetting Your Password'

  events: {
    'submit form.password-reset-confirm-form': '_password_reset_confirm'
  }

  initialize: ->
    @makeMainWebsiteView('tpl_password_reset_confirm')

    errorContainer = @$findOne('.error-container')
    form = @$findOne('form.password-reset-confirm-form')
    @errorsView = new ErrorsView(form, errorContainer)
    setTimeout(=>
      form.findOne('input.new_password1').focus()
    , 0)

  _password_reset_confirm: (e) =>
    e.preventDefault()

    form = $(e.target)
    form.find('input').attr('disabled', 'disabled') 
    pass1 = form.findOne('input.new_password1').val()
    pass2 = form.findOne('input.new_password2').val()
    button = form.findOne('input[type=submit]')
    origVal = button.val()

    @errorsView.clearErrors()
    button.val('Setting password...')

    urlWithParams = "/xhr/account/password/reset/confirm/#{@options.tokens}/"

    password_reset_confirm = $.ajax( {
      url: urlWithParams,
      type: "POST",
      data: {
        new_password1: pass1,
        new_password2: pass2
      },
      dataType: "json"
      cache: false,
    })

    password_reset_confirm.done((response) =>
      button.val(origVal)
      form.find('input').attr('disabled', false)

      if response.success
        @queueSuccessMessage(makeMessage('password_reset_confirm_success'))
        Backbone.history.navigate('/', {trigger: true})
      else
        @errorsView.showErrors(response.data)

    )
    password_reset_confirm.fail((err)=>
      button.val(origVal)
      form.find('input').attr('disabled', false)
    )    

class LoginView extends TopView
  @bodyClass: 'login'

  documentTitle: 'Sign in to Jotleaf'

  events: {
    'submit form.login-form': '_login'
  }

  initialize: ->
    @makeMainWebsiteView('tpl_login')

    errorContainer = @$findOne('.error-container')
    form = @$findOne('form.login-form')
    @errorsView = new ErrorsView(form, errorContainer)
    setTimeout(=>
      form.findOne('input.username').focus()
    , 0)

  _login: (e) =>
    e.preventDefault()

    form = $(e.target)
    form.find('input').attr('disabled', 'disabled') 
    username = form.findOne('input.username').val()
    password = form.findOne('input.password').val()
    button = form.findOne('input[type=submit]')
    origVal = button.val()

    @errorsView.clearErrors()
    button.val('Authenticating...')

    login = $.ajax( {
      url: '/xhr/account/login/',
      type: "POST",
      data: {
        username: username,
        password: password
      },
      dataType: "json"
      cache: false,
    })

    login.done((response) =>
      if response.authenticated
        JL.AuthState.setUser(response.user)

        # ugh
        followDB = Database2.modelDB(Follow)
        for f in response.follows
          followDB.addInstance(new Follow(f))

        Backbone.history.navigate('/home/', {trigger: true})
      else
        @errorsView.showErrors(response.errors)
        button.val(origVal)
        form.find('input').attr('disabled', false)
    )
    login.fail((err)=>
      button.val(origVal)
      form.find('input').attr('disabled', false)
    )

class LoggedOutView extends TopView
  @bodyClass: 'logout'

  documentTitle: 'Signed out of Jotleaf'

  initialize: ->
    @makeMainWebsiteView('tpl_logout')

class RegistrationView extends BaseRegistration
  @bodyClass: 'register'

  documentTitle: 'Register a Jotleaf Account'

  render: =>
    @makeMainWebsiteView('tpl_registration')

class SettingsView extends TopView
  documentTitle: 'Jotleaf Account Settings'

  initialize: ->
    @makeMainWebsiteView('tpl_settings')
    @_tendon = new Tendon.Tendon(@$el, {
      user: JL.AuthState.getUser()
    })
    @_tendon.useBundle(Tendon.twoWayCheckbox,
      ['user', 'email_on_new_follower', 'input.email_on_new_follower', @$el])
    @_tendon.useBundle(Tendon.twoWayCheckbox,
      ['user', 'email_on_new_membership', 'input.email_on_new_membership', @$el])
    @_tendon.useBundle(Tendon.twoWay,
      ['user', 'bio', 'textarea.bio', @$el])

    submitBtn = @$findOne('input[type=submit]')
    @listenTo(submitBtn, 'click', =>
      router._redirect('')
    )

  unbind: =>
    @_tendon.unbind()

