# views_components.coffee is for everything that extends JLView, regardless of
# which parts of our site currently use them. In other words, not top-level
# views. we probably want to break this up at some point.


class MembersView extends JLView
  className: "memberlist"

  initialize: (options) ->
    # `options` includes pageId, memberships, template
    @template = options.template
    @pageId = options.pageId

  _getMemberships: (pageId) =>
    # Fetch the memberships for this pageId
    arrayDfd = Database.modelDB(Membership).filterFetchBy('page_id', pageId)
    return $.Deferred((dfd) =>
      # There must be a better way to do this.
      arrayDfd.done((instanceList) =>
        dfd.resolve(new Memberships(instanceList)))
    )

  _cacheMembers: (memberships) =>
    # A Deferred that ensures we have User objects
    # in the DB for all Membership models passed in
    uids = memberships.pluck('user_id')
    return Database.modelDB(User).fetchList(uids)

  render: =>
    @$el.html(@template())
    @progress = @$('.progress')
    @memberList = @$('.memberlist')

    @_getMemberships(@pageId).done((memberships) =>
      @memberships = memberships
      @_cacheMembers(@memberships).done(@_initRenderList)
    )

  _initRenderList: =>
    log "initrenderlist"
    tokenValues = []
    udb = Database.modelDB(User)
    tokenValues = @memberships.map((m) =>
      u = udb.get(m.get('user_id'))
      return {
        id: u.id
        name: u.get('username')
        membership_id: m.id
      }
    )
    log "prepopulating with", tokenValues
    @memberList.tokenInput("/xhr/autocomplete_username/", {
      queryParam: 'term'
      searchDelay: 50
      prePopulate: tokenValues
      hintText: "Type in a username"
      theme: 'jotleaf'
      tokenLimit: 12
      preventDuplicates: true
      onAdd: @_addItem
      onDelete: @_deleteItem
    })

  _addItem: (item) =>
    log "adding", item
    
    # Setup
    username = item.name
    @progress.text("Adding #{username}...")
    # TODO: disable input?
    addDfd = $.Deferred()
    addDfd.done((m) =>
      assert m instanceof Membership
      item.membership_id = m.id # yay mutability
      @memberships.add(m)
      @progress.text("Added #{username}!")
    )
    addDfd.fail((opt_reason) =>
      msg = "Couldn't add '#{username}'"
      if opt_reason
        msg += ":  " + opt_reason
      @progress.text(msg)
    )
    addDfd.always( => 
      # Enable input?
    )

    # Create membership
    m = new Membership({
      user_id: item.id
      page_id: @pageId
    })
    m.save().done(=> addDfd.resolve(m)).fail(addDfd.reject)

  _deleteItem: (item) =>
    log "removing", item
    username = item.name
    
    # Setup
    @progress.text("Removing #{username}...")
    # TODO: disable input?
    remDfd = $.Deferred()
    remDfd.done((m) =>
      assert m instanceof Membership
      @progress.text("Removed #{username}")
    )
    remDfd.fail( =>
      msg = "ERROR: Couldn't remove '#{username}'"
      @progress.text(msg)
    )
    remDfd.always( => 
      # Enable input?
    )

    # Delete membership
    m = @memberships.where({user_id: item.id})[0]
    m.destroy({wait: true}).done(=> remDfd.resolve(m)).fail(remDfd.reject)


class OptionsView extends JLView
  className: "optionsbox-outer clearfix"

  initialize: (options) ->
    # `options` includes pageId, row
    pageDfd = Database.modelDB(Page).fetch(options.pageId)
    pageDfd.done(@_setPage).fail(@_errBack("Error loading! Refresh the page and try again."))

  render: =>
    @content = $('<div>').addClass('optionsbox').appendTo(@$el)
    if @page
      @_setContent()
    else
      @content.text('Loading...')
      @once('gotpage', @_setContent)
      return
    log "Rendered element", @$el

  _setPage: (page) =>
    @page = page
    @trigger('gotpage')


  _setContent: =>
    @content.html(ich.tpl_page_options())

    # Title
    title = @$('input.title')
    title.val(@page.get('title'))
    @listenTo(title, 'change keyup paste', =>
      @page.edit('title', title.val())
      @options.row.find('.page-title').text(title.val())
    )

    # Memberships
    members = @$findOne('.members')
    new MembersView({
      el: members
      pageId: @options.pageId
      template: ich.tpl_page_members
    }).render()

    # Text writability options
    
    text_writability = @$('select[name=text_writability]')
    text_writabilityVal = parseInt(@page.get('text_writability'))

    assert text_writabilityVal in _.values(PERMISSIONS)

    text_writability.val(text_writabilityVal)

    @listenTo(text_writability, 'change', =>
      newVal = parseInt(text_writability.val())
      log "text_writability val changed", newVal

      assert newVal in _.values(PERMISSIONS)

      @page.edit('text_writability', newVal)
    )

    # Image writability options
    
    image_writability = @$('select[name=image_writability]')
    image_writabilityVal = parseInt(@page.get('image_writability'))

    assert image_writabilityVal in _.values(PERMISSIONS)

    image_writability.val(image_writabilityVal)

    @listenTo(image_writability, 'change', =>
      newVal = parseInt(image_writability.val())
      log "image_writability val changed", newVal

      assert newVal in _.values(PERMISSIONS)

      @page.edit('image_writability', newVal)
    )

    publishedCheckbox = @$findOne('.published')
    @_checkBoxButton = new CheckboxButton(publishedCheckbox, {
      model: @page,
      attribute: 'published'
    })

    # Clear button
    clearBtn = @$findOne('input.clear')
    clearConfirm = @$findOne('.clear_confirm')
    clearProgress = @$findOne('.clear_progress')
    @listenTo(clearBtn,'click', =>
      clearBtn.hide()
      clearConfirm.show()
      clearProgress.hide()
    )
    clearConfirmYes = @$findOne('.clear_confirm .yes')
    @listenTo(clearConfirmYes, 'click', =>
      dfd = API.instanceMethod(@page, 'clear')
      clearConfirm.hide()
      clearProgress.text('Clearing...').show()
      dfd.fail( =>
        clearProgress.text("Couldn't clear the page. Please refresh and try again."))
      dfd.done( =>
        clearProgress.text("Page cleared!")
        clearBtn.show()
      )
    )
    clearConfirmNo = @$findOne('.clear_confirm .no')
    @listenTo(clearConfirmNo, 'click', =>
      clearBtn.show()
      clearConfirm.hide()
    )

    # Delete button
    deleteBtn = @$findOne('input.delete')
    deleteConfirm = @$findOne('.delete_confirm')
    @listenTo(deleteBtn, 'click', =>
      deleteBtn.hide()
      deleteConfirm.show()
    )
    deleteConfirmYes = @$findOne('.delete_confirm .yes')
    @listenTo(deleteConfirmYes,'click', =>
      @$el.empty().text('Deleting...')
      @page.destroy({
        success: =>
          @hide()
          @options.row.hide()
        error: @_errBack('Error deleting! Refresh the page and try again.')
      })
    )
    deleteConfirmNo = @$findOne('.delete_confirm .no')
    @listenTo(deleteConfirmNo, 'click', =>
      deleteBtn.show()
      deleteConfirm.hide()
    )

    # Close button
    closeBtn = @$('input[name=close]')
    @listenTo(closeBtn, 'click', @hide)

  _errBack: (msg) =>
    # Callback maker
    return ( =>
      @content.empty().text(msg)
    )

  show: =>
    @_visible = true
    if @_lastHeight
      target = @_lastHeight + 'px'
      speed = 'fast'
    else
      # First time opening
      target = '999px'
      speed = 'slow'
    @$el.animate({'max-height': target}, speed, 'linear')

  hide: =>
    @_visible = false
    @_lastHeight = @$el.outerHeight()
    @$el.css('maxHeight', @_lastHeight)
    @$el.animate({'max-height': '0px'}, 'fast', 'linear')

  toggle: =>
    if @_visible
      @hide()
    else
      @show()

  unbind: =>
    @_checkBoxButton?.destroy()

class MessagesView extends JLView
  showMessages: (messages, type) =>
    if not messages.length
      return
    log "messages view showing", messages
    content = ich.tpl_messages({
      messages: messages
    })
    @$el.empty().append(content).show()

class ClaimsView extends JLView
  initialize: ->
    claims = API.xhrMethod('get-claims')
    claims.done(@_gotClaims)
    @$el.toggle(JL.AuthState.isAuthenticated())
    @listenTo(JL.AuthState, 'change', =>
      log "TOGGLING!"
      @$el.toggle(JL.AuthState.isAuthenticated())
    )

  events: {
    'click span.add': 'claimPage'
    'click span.forget': 'forgetPage'
  }

  _gotClaims: (pages) =>
    if not pages.length
      return
    content = ich.tpl_claim_notifications({
      pages: pages
    })
    @$el.append(content).show()

  claimPage: (e) =>
    data = {page_id: $(e.target).data('page-id')}
    claim = API.xhrMethod('claim-yes', data)
    claim.done(=> 
      # jank
      window.location.pathname = URLs.pages
    )

  forgetPage: (e) =>
    data = {page_id: $(e.target).data('page-id')}
    claim = API.xhrMethod('claim-no', data)
    claim.done(=> 
      window.location.pathname = URLs.pages
    )


class ErrorsView
  DJANGO_NON_FIELD_KEY: '__all__'

  inputWithErrorsClass: 'input-with-errors'

  constructor: (formEl, nonFieldEl) ->
    # `nonFieldEl` is where non-field errors go
    @_fields = {}
    $(formEl).find('input').each((index, value) =>
      name = $(value).attr('name')
      if name
        @_fields[name] = $(value)
    )
    @_formEl = formEl
    @_nonFieldContainer = nonFieldEl  

  clearErrors: () =>
    $(@_nonFieldContainer).empty().hide()
    $(@_formEl).find('.errors').remove()
    $(@_formEl).find('input').removeClass(@inputWithErrorsClass)

  showErrors: (errors) =>
    if not errors
      return
    fieldErrors = _.omit(errors, [@DJANGO_NON_FIELD_KEY])
    @_showFieldErrors(fieldErrors)
    nonFieldErrors = errors[@DJANGO_NON_FIELD_KEY]
    if nonFieldErrors
      @_showNonFieldErrors(nonFieldErrors)

  _showFieldErrors: (errorMap) =>
    for fieldName, field_errors of errorMap
      inputEl =  @_fields[fieldName]
      assert inputEl.length, "could not find formfield #{fieldName}"
      inputEl.addClass(@inputWithErrorsClass)
      # Only show one error at a time per field
      errors_to_show = field_errors[..0]
      errorView = ich.tpl_errors(
        errors: errors_to_show
      )
      inputEl.parent().append(errorView)

  _showNonFieldErrors: (errorList) =>
    if not errorList and errorList.length
      return
    content = ich.tpl_errors(
      errors: errorList
    )
    $(@_nonFieldContainer).empty().append(content).show()

  requestFailed: (msg) =>
    errors = F.obj(@DJANGO_NON_FIELD_KEY, [msg])
    @showErrors(errors)

class YourPages extends JLView
  initialize: =>
    @$el.append(ich.tpl_your_pages())
    msg = @$findOne('.msg')
    messages = API.xhrMethod('my-pages')
    messages.done((response) =>
      if response.success
        pages = response.data
        if not pages.length
          msg.text('Create a page to get started')
          return
        context = {
          pages: pages
          truncatedContent: @contextToArg(@_truncatedContent)
          isYou: @contextToArg(@_isYou)
          viewsWord: -> (if (@view_count==1) then 'View' else 'Views')
        }
        @$el.empty()
        @$el.append(ich.tpl_your_pages_list(context))
        @$('.timeago').timeago()
      else if response.status_code == 403
        # User has been logged out somehow
        JL.AuthState.setUser(null)
        @options.topView.queueSuccessMessage("You have been logged out. Please login again.")
        router._redirect('account/login/')
    )


class NewsFeedBaseListingView extends JLView
  _getBaseContext: () =>
    context = {
      user: @model.get('user')
      time: @model.get('timestamp')
    }

  _getSpecificContext: () =>
    return {}

  render: =>
    baseContext = @_getBaseContext()
    specificContext = @_getSpecificContext()
    context = _.extend(baseContext, specificContext)
    log "rendering #{@model.get('type')} listing with context:", context
    listingEl = ich.tpl_news_feed_listing(context)
    @_listingContent = listingEl.findOne('.news-feed-listing-content')
    if @template
      @template(context).appendTo(@_listingContent)
    @setElement(listingEl)
    @
    
class NewsFeedTextListingView extends NewsFeedBaseListingView
  initialize: =>
    @template = ich.tpl_nf_content_text
    @listenTo(@model, 'change:data', @_updateTextContent)

  _getSpecificContext: =>
    textContext = {
      message: "wrote"
      truncatedContent: @_truncatedContent(@model.get('data'), 300)
      page: @model.get('page')
      contentUrl: @model.get('data').get_absolute_url
      isYou: @_isYou(@model.get('page'))
    }

  _updateTextContent: (model) =>
    log "updating text content", model
    textEl = @$el.findOne('.text-content')
    textEl.empty().append(model.changed.data.content)

class NewsFeedImageListingView extends NewsFeedBaseListingView
  initialize: =>
    @template = ich.tpl_nf_content_image

  _getSpecificContext: =>
    imageContext = {
      message: "posted an image"
      page: @model.get('page')
      contentUrl: @model.get('data').get_absolute_url
      src: @model.get('data').src
      isYou: @_isYou(@model.get('page'))
    }

class NewsFeedEmbedListingView extends NewsFeedBaseListingView
  initialize: =>
    @template = ich.tpl_nf_content_embed
    
  _getSpecificContext: =>
    embedly_data = JSON.parse(@model.get('data').embedly_data)
    provider = embedly_data.provider_name
    if provider
      msg = "posted a #{provider} embed"
    else
      msg = "posted an embed"
    embedContext = {
      message: msg
      page: @model.get('page')
      contentUrl: @model.get('data').get_absolute_url
      embedlyData: embedly_data
      isYou: @_isYou(@model.get('page'))
    }

class NewsFeedMembershipListingView extends NewsFeedBaseListingView
  initialize: =>
    @template = ich.tpl_nf_content_membership

  _getSpecificContext: =>
    membershipContext = {
      message: "added you as a member"
      page: @model.get('page')
    }

class NewsFeedFollowListingView extends NewsFeedBaseListingView
  initialize: =>
    @template = ich.tpl_nf_content_follow

  _getSpecificContext: =>
    followContext = {
      message: "is now following you"
      placeholder: "#{JL_CONFIG.STATIC_URL}images/screenshot/screenshot_placeholder.png"
    }

class NewsFeedPageListingView extends NewsFeedBaseListingView
  initialize: =>
    @template = ich.tpl_nf_content_page

  _getSpecificContext: =>
    pageContext = {
      message: "has published a new page"
      page: @model.get('page')
      newPage: true
    }

class NewsFeedView extends JLView
  initialize: =>
    @listenTo(@model, 'add', @_insertNewsListing)
    @listenTo(@model, 'remove', @_removeNewsListing)
    @$el.append(ich.tpl_news_feed())
    newsfeed = API.xhrMethod('news-feed')
    newsfeed.done((response)=>
      if response.success
        @news = response.data
        @$el.empty().append(ich.tpl_news_feed_list())
        @newsFeedList = @$findOne('.news-feed-list')
        for newsListing in @news
          @model.add(new NewsFeedListing(newsListing))
      else if response.status_code == 403
        # User has been logged out somehow
        JL.AuthState.setUser(null)
        @options.topView.queueSuccessMessage("You have been logged out. Please login again.")
        router._redirect('account/login/')
    )

  _insertNewsListing: (listing, collection, options) =>
    log "insert new listing", listing
    type = listing.get('type')
    switch type
      when 'text' then View = NewsFeedTextListingView
      when 'image' then View = NewsFeedImageListingView
      when 'embed' then View = NewsFeedEmbedListingView
      when 'membership' then View = NewsFeedMembershipListingView
      when 'follow' then View = NewsFeedFollowListingView
      when 'page' then View = NewsFeedPageListingView
      else
        log "Unknown news listing type", listing.type    
    
    if View
      listingView = new View({
          model: listing
        })
      listingEl = listingView.render().$el
      listing.view = listingView
      prepend = options.prepend
      if prepend
        numListings = collection.length
        insertedAt = collection.indexOf(listing)
        listingEl.css({maxHeight: 0})
        if numListings == 0 or insertedAt == 0
          @newsFeedList.prepend(listingEl)
        else
          previousListing = collection.at(insertedAt - 1)
          previousEl = previousListing.view?.$el
          if previousEl
            previousEl.after(listingEl)

        listingEl.animate({'max-height': '300px'}, 1000, 'linear')
      else
        @newsFeedList.append(listingEl)
      @$('.timeago').timeago()

  _removeNewsListing: (listing, collection, options) =>
    log "remove listing", listing
      
    view = listing.view
    if view
      view.$el.animate({'max-height': '0'}, 500, 'linear', =>
        view.remove()
      )
  
class ProfilePageListView extends JLView
  initialize: ->
    @$el.append(ich.tpl_loading_msg())
    data = {user_id: @options.user.id}
    pages = API.xhrMethod('get-user-pages', data)
    pages.fail( =>
      @$findOne('.msg').text('Error loading — please refresh')
    )
    pages.done(@_gotPages)

  _gotPages: (pages) =>
    # can't use a collection with model:Page,
    # because then it will try to use Page.parse,
    # which is all tangled up with the viewer...
    @$el.empty()

    if not pages.length
      username = @options.user.get('username')
      msg = $('<h3>').text("#{username} hasn't created any pages yet")
      msg.appendTo(@$el)

    for context in pages
      context.viewsWord = -> 
        if (@view_count==1) 
          'View' 
        else 
          'Views'
      @$el.append(ich.tpl_show_user_page_row(context))

class ItemView extends JLView
  @STATES =
    ENGAGED: 'engaged'
    VIEW: 'view'
    EDIT: 'edit'
    ADMIN: 'admin'
    DELETED: 'deleted'

  initialize: =>
    @state = @constructor.STATES.VIEW
    @$el.data('view', @)
    @listenTo(@model, 'change:x change:y', @updatePosition)
    @events = _.extend({}, ItemView.prototype.events, @events)

  events: {
    'click a': '_handleHREF'
  }

  render: =>
    # Common bindings
    @listenTo(@model, 'change:width', @_processWidth)
    @listenTo(@model, 'change:height', @_processHeight)

    # Add an on-hover selector button. Otherwise, there's no way for
    # the user to edit the item after making it a link.
    if Permissions.canEditItem(@model)
      # equivalent IoC version of @$el.hover
      @listenTo(@$el, 'mouseenter', @_showEditButton)
      @listenTo(@$el, 'mouseleave', @_hideEditButton)
      # @$el.hover(@_showEditButton, @_hideEditButton)

  _handleHREF: (e) =>
    if @state != @constructor.STATES.VIEW
      e.preventDefault()

  _setState: (newstate) =>
    oldstate = @state
    if oldstate == newstate
      return
    if oldstate == @constructor.STATES.DELETED
      # We are dead. Ignore the request.
      return
    @state = newstate
    @trigger 'setstate', newstate, oldstate

  getState: =>
    return @state

  setStateAdmin: =>
    @_setState @constructor.STATES.ADMIN

  setStateEdit: =>
    @_setState @constructor.STATES.EDIT

  setStateView: =>
    @_setState @constructor.STATES.VIEW

  setStateDeleted: =>
    @_setState @constructor.STATES.DELETED

  setStateEngaged: =>
    @_setState @constructor.STATES.ENGAGED

  delete: (destroyModel=true) =>
    log 'delete called', @
    if destroyModel
      @model.destroy()
    @pageView.model.items.remove(@model)
    @$el.fadeOut(400, =>
      @remove()
      @setStateDeleted()
    )

  _getFeatureMap: =>
    # Maps feature names to applicable states
    # (String -> [State...])
    return {}

  _getTransitionHandlers: =>
    # Associate handlers with state transitions. Should
    # be used sparingly relative to _getFeatureMap above,
    # because level-triggered is better than edge-triggered.

    # Maps method name strings to [initialState, endState] pairs,
    # where states can also be 'any'. 'any' does not match on 
    # the initial setstate, when the initial state is 'null'.

    # The method name must be present on the View object itself,
    # i.e. @[name]
    return {}

  _reverseFeatureMap: (featureMap) =>
    # Returns a map from a state (view, edit...) to 
    # a set (i.e. map str -> true) of all the features
    # active on that state
    rmap = {}
    for featureName, stateList of featureMap
      for state in stateList
        rmap[state] ||= {}
        rmap[state][featureName] = true
    return rmap

  bindStateChangeHandlers: =>
    # Bind feature setters:
    features = @_getFeatureMap()
    stateToFeatures = @_reverseFeatureMap features
    @listenTo(@, 'setstate', (newstate) =>
      stateFeatures = stateToFeatures[newstate] or {}
      for f, _ of features
        if stateFeatures[f]
          @_featureSwitch f, 'on'
        else
          @_featureSwitch f, 'off'
    )
    # Bind special transition for finalizing:
    transitions = @_getTransitionHandlers()
    @listenTo(@, 'setstate', (newstate, oldstate) =>
      assert newstate != oldstate
      if not oldstate 
        # this happens on init
        return
      for methodName, [handlerOldState, handlerNewState] of transitions
        if handlerOldState != 'any' and handlerOldState != oldstate
          continue
        if handlerNewState != 'any' and handlerNewState != newstate
          continue
        @[methodName]()
    )

  updatePosition: (item, newVal, options) =>
    delta = [0, 0]
    delta[0] = item.get('x') - item.previousAttributes()['x']
    delta[1] = item.get('y') - item.previousAttributes()['y']
    
    currOffset = @$el.position()
    newTop = currOffset.top + delta[1]
    newLeft = currOffset.left + delta[0]
    if options.instant
      @$el.css({
        top: newTop
        left: newLeft
      })
    else
      # This doTimeout is needed for debouncing the position changes
      # Since change:x and change:y usually happen together, we get two events
      # because we have them as two separate attributes.  However, we only 
      # want to trigger one css offset, so we debounce the two events
      $.doTimeout("#{item.id}-move", 100, =>
        @$el.animate({
          top: newTop
          left: newLeft
        }, 300, 'swing')
      )

  updateView: =>
    @setStateView()

  addDeleteBtn: =>
    if @deleteBtn
      return
    @deleteBtn = ich.tpl_delete_btn(@commonContext())
    @$el.append(@deleteBtn)
    @deleteBtn.css(
      marginRight: -(@deleteBtn.outerWidth()/2)
      marginTop: -(@deleteBtn.outerHeight()/2)
    ).attr('title', 'Delete')

  removeDeleteBtn: =>
    @deleteBtn?.remove()
    @deleteBtn = null

  onresizestop: (e, ui) =>
    log "onresizestop"
    @model.edit('height', ui.size.height)
    @model.edit('width', ui.size.width)

  ondragstop: (e, ui) =>
    log "ondragstop"
    $pv = @pageView.$el
    [newScreenX, newScreenY] = [ui.offset.left - $pv.offset().left, 
                                ui.offset.top - $pv.offset().top]
    [x, y] = @pageView.surface.screenPixelsToCoords(newScreenX, newScreenY)
    # We don't want to trigger the change event on the model because the 
    # dragging already handles the ui position updates.  This
    # allows us to distinguish between externally triggered positions updates
    # and client introduces position updates
    @model.edit('x', x, {silent: true})
    @model.edit('y', y, {silent: true})



  # split into two separate handlers because they are called separately anyway
  # a change of height and width simultaneously still results in two calls that
  # do redundant work
  _processSize: =>
    @_processHeight()
    @_processWidth()

  _processHeight: =>
    @$el.height(@model.get('height') or '')

  _processWidth: =>
    # Sets height, width and [with|no]-width class.
    content = @$('.content')
    width = @model.get('width')
    @$el.width(width or '')
    hasWidth = Boolean(width) # value of 0: behavior undefined
    content.toggleClass('with-width', hasWidth)
    content.toggleClass('no-width', not hasWidth)


  _processLinkToURL: =>
    url = $.trim(@model.get('link_to_url'))
    if url and not url.match(/^https?:\/\//)
      # Make it safe, i.e. prevent other protocols like JS
      url = 'http://' + url
    content = @$('.content')
    aClass = 'link-to-url'
    link = content.parent('.' + aClass)
    if url
      if link.length
        link.attr('href', url)
      else
        aTag = $("<a href='#{url}' class='#{aClass}'>")
        if not testSameOrigin(url)
          aTag.attr('target', '_blank')
        content.wrap(aTag)
      content.attr('title', "Link to #{url}")
    else if link.length
      content.attr('title', '')
      content.unwrap()

  _showEditButton: =>
    if @state != @constructor.STATES.VIEW
      return
    #if @pageView.selectedIV # a bit hacky to be accessing this
    #  return
    @_hideEditButton()

    btn = @_editButton = $("<img class='edit-btn'>")

    # Size & v-Positioning
    # TODO: align bottom with text baseline 
    if @model.constructor.shortName == 'textitem'
      border = parseInt(@$el.css('border-bottom-width'))
      padding = parseInt(@$el.css('padding-bottom'))
      size = @$el.height() - 2*padding - 2*border
      bottom = padding
    else
      size = @$el.height()
      bottom = 0
    size = clamp(size, 12, 36)
    btn.height(size).width(size)
    btn.css('bottom', bottom)

    # h-Positioning:
    # Calculate right position. It switches from fully outside
    # the element to fully inside the element as the element gets
    # taller.
    sizeRatio = size/@$el.height()
    if sizeRatio <= 1/3
      right = 0 # Fully inside
    else
      right = -size # Fully outside
    btn.css('right', right)

    # Color:
    @pageView.getLuminance((l) =>
      color = if l < .3 then 'white' else 'black'
      src = "#{JL_CONFIG.STATIC_URL}images/nounproject/gear_1241_#{color}_shadowed.png"
      btn.attr('src', src)
      btn.hide()
      @$el.append(btn)
      btn.delay(150).fadeIn()
    )

  _hideEditButton: =>
    @_editButton?.remove()

  _makeDraggable: =>
    if @_grip
      return
    g = @_grip = $("<div class='grip item-ctrl'></div>")
    g.attr('title', 'Click & Drag')
    g.width(18) # looks good
    @$el.append(g)
    g.css({
      left: -(g.width() + 2)
    })
    @$el.draggable({
      handle: g
      start: -> g.css('cursor', 'move')
      stop: -> g.css('cursor', 'pointer')
    })

  _rmDraggable: =>
    @_grip?.remove()
    @_grip = null

    # Needed check for new jqueryui 1.10.0
    # Throws an error when an uninitialized item is destroyed
    if @$el.data('uiDraggable')
      @$el.draggable "destroy"
    
  unbind: =>
    @_rmDraggable()
    

class TextItemView extends ItemView
  # special events:
  #  - setstate [newstate, opt_oldstate]
  #
  # the outer view (Page) is responsible for
  # determining this view's state transition edges,
  # because only it can keep track of the complicated
  # states involved in determining what a click means.
  className: "item textitem"

  events:
    'click .delete-btn': 'delete'
    'resizestop': 'onresizestop'
    'dragstop': 'ondragstop'
    'keydown': 'keydown'
    'keyup': '_postModify'
    'paste': 'paste'


  isNew: =>
    m = @model
    return (m.isNew() and
            not $.trim(m.get('content')) and
            not m._saving and
            @$content.text() == '')

  updateView: =>
    @_setViewContent(@model.get('content'))
    super
    
  unbind: =>
    @rview?.unbind()

  render: =>
    super
    contentDiv = @$content = ich.tpl_text_item().empty()
    @$el.empty().append(contentDiv)
    @_processSize()

    # Set up container
    assert @$el.text() == ''

    # Render text
    @_setViewContent(@model.get('content'))

    # Add styling...
    page = @model.page
    @rview = rivets.bind(@$el, {
      page: page
      item: @model
      view: @
    })

    # Handle links
    @listenTo(@model, 'change:link_to_url', @_processLinkToURL)
    @_processLinkToURL()

    @bindStateChangeHandlers()
    setTimeout(@_maybeImageBtn, 0)
    @trigger('setstate', @state)
    return @

  _finalize: =>
    log 'finalize called', @
    if @isNew() or not @_getViewContent()
      @delete()
    else
      @_publishContent()
      # We need this _hideImageBtn call here for a very special
      # case. If you type only one letter and click out really 
      # quickly, the view gets deselected before the `keyup`
      # handler can fire, so _postModify never gets called. If
      # _postModify accrues more functions, we should stick those
      # here too.
      @_hideImageBtn()

  _featureSwitch: (featureName, onOrOff) =>
    assert onOrOff in ['on', 'off']
    onOffBool = (onOrOff == 'on')
    switch featureName
      when 'classSelected'
        @$el.toggleClass 'selected', onOffBool
      when 'classAdmin'
        @$el.toggleClass 'adminning', onOffBool
      when 'draggable'
        if onOffBool
          @_makeDraggable()
        else
          @_rmDraggable()
      when 'resizeable'
        if onOffBool
          @$el.resizable({
            maxHeight: 1000
            maxWidth: 1000
            handles: 'se, e, s'
          })
        else
          # Needed check for new jqueryui 1.10.0
          # Throws an error when an uninitialized item is destroyed
          if @$el.data('uiResizable')
            @$el.resizable "destroy"
          
      when 'deletebtn'
        if onOffBool
          @addDeleteBtn()
        else
          @removeDeleteBtn()
      when 'editing'
        # hmm....
        if onOffBool
          if @_editing
            return
          @_editing = true
          @$content.text(@$content.text()) # Remove links
          @$content.attr('contenteditable', true)
          @$content.focus()
        else 
          @_editing = false
          @$content.attr('contenteditable', false)

          # hideous workaround for firefox compatibility. jquery.text()
          # doesn't seem to interpret <br> elements as '\n' to preserve
          # whitespace For chrome this is not an issue because a newline is
          # inserted as a newline character as the string content of the text
          # node.  Firefox, however, implements the newline by inserting a <br>
          # element.  Jquery.text() ignores this and we lose our newlines.
          # Thus we override firefox's behavior by manually swapping his
          # inserted BR's with \n's and then proceeding as usual. see
          # plugins2.coffee for br2nl implementation.
          @$content.text(@$content.br2nl().text())
          @$content.linkify({target: '_blank'})
      else
        throw new Error("Unknown feature " + featureName)

  _getFeatureMap: =>
    s = @constructor.STATES
    return {
      classAdmin: [s.ADMIN]
      classSelected: [s.ADMIN, s.EDIT]
      draggable: [s.ADMIN]
      resizeable: [s.ADMIN]
      deletebtn: [s.ADMIN]
      editing: [s.ADMIN, s.EDIT]
    }

  _getTransitionHandlers: =>
    s = @constructor.STATES
    return {
      '_finalize': ['any', s.VIEW]
      '_hideEditButton': [s.VIEW, 'any']
    }

  useAdminStyle: =>
    page = @model.page
    if not page.get 'use_custom_admin_style'
      return false
    return @model.getCreatorAffiliation() == AFFILIATIONS.OWNER

  getStyleValue: (propIfCustomStyle='', propIfAdmin, propIfNone, defaultVal='') =>
    page = @model.page
    itemLevelValue = if propIfCustomStyle then @model.get(propIfCustomStyle) else null
    pageLevelAttribute = if @useAdminStyle() then propIfAdmin else propIfNone
    return itemLevelValue or page.get(pageLevelAttribute) or defaultVal

  getColor: =>
    return @getStyleValue 'color','admin_textitem_color', 'default_textitem_color','rgb(0,0,0)'

  getBGColor: =>
    return @getStyleValue 'bg_color','admin_textitem_bg_color', 'default_textitem_bg_color'

  getFontSize: =>
    # in pixels
    return @getStyleValue 'font_size', 'admin_textitem_font_size', 'default_textitem_font_size'

  getFontFace: =>
    # For now, we don't support admin-custom fonts.
    # As opposed to colors, it should default to the same as
    # other users' font.
    #return @getStyleValue 'admin_textitem_font', 'default_textitem_font'
    # we use 'inherit' for the font, because otherwise Chrome on OSX seems to be magically
    # getting 'Lucida Grande' from nowhere.
    return @getStyleValue 'font','default_textitem_font', 'default_textitem_font', 'inherit'

  _preModify: =>
    if @isNew()
      @_setViewContent('')

  _postModify: =>
    @_publishContent()
    @_checkForImageURL()
    @_checkForEmbedURL()
    @_maybeImageBtn()

  _getViewContent: =>
    if @isNew()
      return ''
    else
      return @$content.text()

  _setViewContent: (s) =>
    @$content.empty().text(s)

  _publishContent: =>
    content = @_getViewContent()
    # If the model hasn't been saved yet, only save it
    # if we have real content.
    if @model.id or content
      @model.edit('content', content)

  keydown: (e) =>
    @_preModify()
    if e.which is $.ui.keyCode.ENTER and e.shiftKey
      # Let the default behavior of inserting a newline occur.
      return
    else if e.which in [$.ui.keyCode.ENTER, $.ui.keyCode.ESCAPE]
      @setStateView()
      e.preventDefault()
      @$content.blur() # remove focus from the contentEditable
      @pageView.unselectItem() # good enough for now
      # Prevent these events from hitting the PageView
      e.preventDefault()
      e.stopPropagation()

  paste: (e) =>
    @pageView.surface._pasteHappened = true
    @_preModify()
    # this event fires before the content is inserted, so wait
    # until the current thread finishes, then process the paste
    setTimeout(( =>
      # Remove rich formatting from pasted content, like if it
      # was copied from a website. The guard prevents us from
      # losing cursor position in the common case.
      if @$content.html() != @$content.text()
        # Add manual newlines because we don't get \n's with .text()
        # .innerText's behavior is what we want, but FF doesn't support
        # it. We can't use <BR>'s and br2nl because .text() still
        # won't see those \ns if they're somewhere in the HTML that
        # they'd be ignored.
        @$content.find(':header').prepend('<div>\n</div>')
        content = $.trim(@$content.text())
        content = $.trim(content)
        @_setViewContent(content)
      @_postModify()
      
      # SUPER HACKY: The scroll gets triggered after a paste event completes
      # but a paste doesn't always trigger a scroll, so we need some delay
      # for unsetting the flag to allow the scroll event to 'see' the flag before
      # we unset it 
      setTimeout(=>
        @pageView.surface._pasteHappened = false
      , 50)
    ), 0)

  _maybeImageBtn: =>
    page = @model.page
    if @isNew() and Permissions.currentUserCanInsertImageItem(page)
      @_showImageBtn()
    else
      @_hideImageBtn()

  _addButton: (el) =>
    # There are two cases where we hover a button to the right of the text
    # elements:
    #  - the content is an image URL, and we're prompting to convert to
    #  ImageItem
    #  - the content is empty, and there's a button for if they want to insert
    #  an image item directly.
    #
    # These two cases have a lot in common, so this method factors that out.
    #
    # XX Actually, only used for the former now. todo fix me up.
    c = @$('.content')
    v = c.parent()
    el.css({
      position: 'absolute'
      lineHeight: c.css('lineHeight')
      top: v.position().top + parseInt(v.css('borderTopWidth'))
      left: v.position().left + v.outerWidth() + 2
      margin: c.css('margin')
      padding: c.css('padding')
      backgroundColor: 'rgba(255, 255, 255, .8)'
      color: 'black'
      zIndex: 1000
      whiteSpace: 'nowrap'
    })

    # prevents button click from putting item in view mode
    el.addClass('item-ctrl') 

    el.appendTo(v.parent())

  _addPopup: (el) =>
    c = @$('.content')
    v = c.parent()
    el.css({
      marginTop: v.outerHeight()
    })
    el.addClass('item-ctrl') 
    @pageView.getLuminance((l) ->
      if l < .4
        el.addClass('lightness-10')
    )
    el.appendTo(v)
    el.css({
      marginLeft: -el.outerWidth()/2
    })

  _positionImageBtn: =>  
    c = @$('.content')
    v = c.parent()
    
    css = {
      top: v.position().top + parseInt(v.css('borderTopWidth'))
      left: v.position().left + v.outerWidth() + 2
    }
    @_imageBtn.css(css)
    @_imageBtn.height(c.outerHeight())
  

  _showImageBtn: =>
    @_hideImageBtn()

    b = @_imageBtn = ich.tpl_insert_img_btn(@commonContext())
    c = @$content
    v = @$el

    padding = parseInt(c.css('paddingTop'))
    border = parseInt(@$el.css('borderTopWidth'))

    # yes include content's padding, but subtract an extra 2 because it looks better
    # to be a bit smaller than the content div
    b.height(v.outerHeight() - 2*border - 2) 

    b.attr('title', 'Insert image')
    b.css({
      top: @$el.position().top + border + 1 # the -1 corresponds to the -2 explained above
      left: v.position().left + v.outerWidth() + 2
    })
    b.appendTo(v.parent())
    b.click( =>
      imgDfd = fpPickImage()
      imgDfd.done( (fpfile) =>
        b.remove()
        [x, y] = @model.getN('x', 'y')
        @pageView.createImageFromFPFile(fpfile, x, y)
      )
      imgDfd.fail((fperr) =>
        # fperr.code == 101, probably (they closed it)
        #  -> refocus the text field, so that the cursor
        #  blinks and they can type in it
        @$content.focus()
      )
    )

    @listenTo(@model, 'destroy', => b.remove())
    @listenTo(@model, 'change:height change:width change:font_size change:content', @_positionImageBtn)

  _hideImageBtn: =>
    @model.off('change:height change:width change:font_size change:content', @_positionImageBtn)
    @_imageBtn?.remove()

  _checkForImageURL: =>
    # Does the content of this field look like an image URL? If so, prompt to
    # convert this item to a textitem.
    page = @model.page
    if not Permissions.currentUserCanInsertImageItem(page)
      return
    content = @_getViewContent()
    if not content.match(/^https?:\/\/.*\.(jpe?g|gif|png|)$/i)
      return

    # We have a match. Confirm conversion.
    log "Confirming conversion"

    # TODO: better solution for multiple triggers. Currently gets hit three
    # times, once for every keyup! Also, tests.
    @_pendingConfirm?.reject() # Remove any previous. 
    c = @$('.content')
    v = c.parent()
    confirm = ich.tpl_confirm_text_to_image({itemType: 'image'})
    @_addPopup(confirm)

    # Bind handlers
    dfd = $.Deferred()
    dfd.done(@_convertToImage)
    dfd.always( =>
      confirm.remove()
    )
    # TODO: clicking 'no' after deselecting inserts a new pending textitem
    confirm.find('.yes').click( => dfd.resolve())
    confirm.find('.no').click( => dfd.reject())
    @model.once('change:content', => dfd.reject())
    @_pendingConfirm = dfd

  _checkForEmbedURL: =>
    # Does the content of this field look like an embed URL? If so, prompt to
    # convert this item to an embeditem.
    page = @model.page
    if not Permissions.currentUserCanInsertImageItem(page)
      return
    content = @_getViewContent()

    # Generated by embedly http://embed.ly/tools/generator
    # (youtube, vimeo, soundcloud, bandcamp)
    # # manually added "s?" to initial http
    embedUrl = /((https?:\/\/(.*youtube\.com\/watch.*|.*\.youtube\.com\/v\/.*|youtu\.be\/.*|.*\.youtube\.com\/user\/.*|.*\.youtube\.com\/.*#.*\/.*|m\.youtube\.com\/watch.*|m\.youtube\.com\/index.*|.*\.youtube\.com\/profile.*|.*\.youtube\.com\/view_play_list.*|.*\.youtube\.com\/playlist.*|www\.vimeo\.com\/groups\/.*\/videos\/.*|www\.vimeo\.com\/.*|vimeo\.com\/groups\/.*\/videos\/.*|vimeo\.com\/.*|vimeo\.com\/m\/#\/.*|player\.vimeo\.com\/.*|soundcloud\.com\/.*|soundcloud\.com\/.*\/.*|soundcloud\.com\/.*\/sets\/.*|soundcloud\.com\/groups\/.*|snd\.sc\/.*|.*\.bandcamp\.com\/|.*\.bandcamp\.com\/track\/.*|.*\.bandcamp\.com\/album\/.*))|(https:\/\/(.*youtube\.com\/watch.*|.*\.youtube\.com\/v\/.*|www\.vimeo\.com\/.*|vimeo\.com\/.*|player\.vimeo\.com\/.*)))/i

    if not content.match(embedUrl)
      return

    # We have a match. Confirm conversion.

    # TODO: better solution for multiple triggers. Currently gets hit three
    # times, once for every keyup! Also, tests.
    @_pendingConfirm?.reject() # Remove any previous. 
    c = @$('.content')
    v = c.parent()
    confirm = ich.tpl_confirm_text_to_image({itemType: 'embed'})
    @_addPopup(confirm)

    # Bind handlers
    dfd = $.Deferred()
    dfd.done(@_convertToEmbed)
    dfd.always( =>
      confirm.remove()
    )
    # TODO: clicking 'no' after deselecting inserts a new pending textitem
    confirm.find('.yes').click( => dfd.resolve())
    confirm.find('.no').click( => dfd.reject())
    @model.once('change:content', => dfd.reject())
    @_pendingConfirm = dfd

  _convertToEmbed: =>
    # Delete the text item
    [x, y] = @model.getN('x', 'y')
    @delete()

    # Create new embed item
    url = @_getViewContent()
    log "converting to embed with url #{url}"
    @pageView.createEmbed(x, y, url)

  _convertToImage: =>
    [x, y] = @model.getN('x', 'y')
    loadingDfd = @pageView._displayLoadingIndicator(x, y)
    # Delete the text item
    @delete()

    # Create new image item
    url = @_getViewContent()
    dfd = fpStoreUrl(url)
    # TODO: error handling for storeUrl
    dfd.done((fpfile) =>
      @pageView.createImageFromFPFile(fpfile, x, y)
    ).always(
      loadingDfd.resolve()
    )

class ImageItemView extends ItemView
  className: "item imageitem"

  events: {
    'dragstart .content': (e) => e.preventDefault()
    'click .delete-btn': 'delete'
    'resizestop': 'onresizestop'

    # This ensures that height/width get set right away when resizing
    # begins, which sets the 'with-width' class necessary for correct
    # image size rendering.
    'resizestart': 'onresizestop' 

    'dragstop': 'ondragstop'
  }

  render: =>
    super
    # Add content
    @content = ich.tpl_imageitem_content({src: @model.get('src')})
    @$el.empty().append(@content)

    # Style & feature handlers
    @_processSize()
    @bindStateChangeHandlers()
    @trigger('setstate', @state)
    @listenTo(@model, 'change:link_to_url', @_processLinkToURL)
    @_processLinkToURL()
    @listenTo(@model, 'change:border_color change:border_width change:border_radius', @_processBorder)
    @_processBorder()

    # Loading image
    @$el.addClass('loading')
    @$findOne('img').load(@doneLoading)
    return @

  doneLoading: =>
    @$el.removeClass('loading')

  _processBorder: =>
    # NB border affects image positioning, we don't 
    # compensate for it. (change this?)
    @content.css({
      'border-color': @model.get('border_color')
      'border-width': @model.get('border_width') or 0
      'border-radius': @model.get('border_radius')
    })

  _getFeatureMap: =>
    # for image items, we don't need a distinction
    # between ADMIN and EDIT states (yet?)
    s = @constructor.STATES
    return {
      'classSelected': [s.ADMIN, s.EDIT]
      'draggable': [s.ADMIN, s.EDIT]
      'resizeable': [s.ADMIN, s.EDIT]
      'deletebtn': [s.ADMIN, s.EDIT]
    }

  _featureSwitch: (featureName, onOrOff) =>
    # TODO: DRY with TextItemView._featureSwitch
    assert onOrOff in ['on', 'off']
    onOffBool = (onOrOff == 'on')
    switch featureName
      when 'classSelected'
        @$el.toggleClass 'selected', onOffBool
      when 'draggable'
        if onOffBool
          @_makeDraggable()
        else
          @_rmDraggable()
      when 'resizeable'
        if onOffBool
          @$el.resizable({
            maxHeight: 1000
            maxWidth: 1000
            handles: 'se, e, s'
          })
        else
          # Needed check for new jqueryui 1.10.0
          # Throws an error when an uninitialized item is destroyed
          if @$el.data('uiResizable')
            @$el.resizable "destroy"
      when 'deletebtn'
        if onOffBool
          @addDeleteBtn()
        else
          @removeDeleteBtn()
      else
        throw new Error("Unknown feature " + featureName)

class EmbedItemView extends ItemView
  className: "item embeditem"

  events: {
    'dragstart .content': (e) => e.preventDefault()
    'click .delete-btn': 'delete'
    'resizestop': 'onresizestop'

    # This ensures that height/width get set right away when resizing
    # begins, which sets the 'with-width' class necessary for correct
    # image size rendering.
    'resizestart': 'onresizestop' 
    'dragstop': 'ondragstop'
  }

  render: =>
    super

    # Add content
    embedlyData = JSON.parse(@model.get('embedly_data'))
    providerName = embedlyData.providerName
    @content = ich.tpl_embeditem_content()
    @content.addClass(providerName)
    @embed = $(embedlyData.html)
    @invisibleLayer = @content.findOne('.invisible-layer')
    
    @content.append(@embed)

    @$el.empty().append(@content)

    @$el.addClass('loading')
    @embed.load(=> @$el.removeClass('loading'))

    # Style & feature handlers
    @_processSize()
    @bindStateChangeHandlers()
    @trigger('setstate', @state)

    # prevent iframe from intercepting mousemove events needed
    # by both draggable and resizable widgets
    @listenTo(@$el, 'resizestart dragstart', => @invisibleLayer.show())
    @listenTo(@$el, 'resizestop dragstop', => @invisibleLayer.hide())

    return @

  _getFeatureMap: =>
    # for image items, we don't need a distinction
    # between ADMIN and EDIT states (yet?)
    s = @constructor.STATES
    return {
      'classSelected': [s.ADMIN, s.EDIT]
      'engaged': [s.ADMIN, s.EDIT, s.ENGAGED]
      'draggable': [s.ADMIN, s.EDIT]
      'resizeable': [s.ADMIN, s.EDIT]
      'deletebtn': [s.ADMIN, s.EDIT]
    }

  _featureSwitch: (featureName, onOrOff) =>
    # TODO: DRY with TextItemView._featureSwitch
    assert onOrOff in ['on', 'off']
    onOffBool = (onOrOff == 'on')
    switch featureName
      when 'classSelected'
        @$el.toggleClass 'selected', onOffBool
      when 'engaged'
        @$el.toggleClass 'engaged', onOffBool
        @invisibleLayer.toggle(!onOffBool)
      when 'draggable'
        if onOffBool
          @_makeDraggable()
        else
          @_rmDraggable()
      when 'resizeable'
        if onOffBool
          @$el.resizable({
            aspectRatio: true
            maxHeight: 1000
            minWidth: 200
            maxWidth: 1000
            handles: 'se, e, s'
          })
        else
          # Needed check for new jqueryui 1.10.0
          # Throws an error when an uninitialized item is destroyed
          if @$el.data('uiResizable')
            @$el.resizable "destroy"
      when 'deletebtn'
        if onOffBool
          @addDeleteBtn()
        else
          @removeDeleteBtn()
      else
        throw new Error("Unknown feature " + featureName)


class ActivityView extends JLView
  className: 'activity-notification'
  events: {
    'click' : '_goToItem'
  }

  initialize: =>

    @item = @options.item
    @itemX = @item.get('x')
    @itemY = @item.get('y')

    iv = @item.view.$el
    @itemW = iv.outerWidth()
    @itemH = iv.outerHeight()

    #Store the center of element
    @itemCenterY = @itemY + (@itemH/2)
    @itemCenterX = @itemX + (@itemW/2)

    @listenTo(@options.surface, 'set-center', @_positionActivityArrow)

    activityEl = ich.tpl_activity_notification({
      username: @options.username or "Someone"
    })
    @options.pageView.getLuminance((l) ->
      if l < .4
        activityEl.addClass('lightness-10')
    )
    activityEl.hide()
    @setElement(activityEl)
    activityEl.appendTo(@options.parent)
        
    @$el.fadeIn()
    [x, y] = @options.surface.getCenter()
    @_positionActivityArrow(x, y, 0)
    setTimeout(@_destroy, 5000)

  _positionActivityArrow: (centerX, centerY)  =>
    y = @itemCenterY - centerY
    x = @itemCenterX - centerX

    absY = Math.abs(y)
    absX = Math.abs(x)

    h = @options.parent.height()
    w = @options.parent.width()
    # calculate the y/x ratio to compare to the ratio's of the screen edges
    # we need this to determine to which side of the screen the vector is pointing 
    ratio = if absX then absY/absX else absY
    cornerRatio = if w then h/w else h

    isVerticalEdge = ratio > cornerRatio
    isInside = @options.surface.isBoxInView(@itemX, @itemY, @itemW, @itemH)
    if isVerticalEdge
      if y > 0
        edge = 'bottom'
      else 
        edge = 'top'
    else
      if x > 0
        edge = 'right'
      else 
        edge = 'left'

    @_displayOnEdge(edge, x, y, h, w, isInside)

  _goToItem: =>
    if @options.item
      [x, y] = @options.pageView.mapElementToCoordinates(@options.item)
      @options.surface.initScrollToCoords(x,y)

  _displayOnEdge: (position, x, y, h, w, isInside)=>
    if @_previousClass != position or @_wasInside != isInside
      if @_previousClass
        @$el.removeClass(@_previousClass)

      @$el.toggleClass('inside', isInside)
      
      @_previousClass = position
      @_wasInside = isInside

      @$el.addClass(position)
   
    @w = @$el.outerWidth()
    @h = @$el.outerHeight()
    css = {
        left: ''
        right: ''
        bottom: ''
        top: ''
        marginLeft: ''
        marginTop: ''
      }
    if not isInside
      if position is 'top'
        css.left = (-h * x) / (2 * y) + (w / 2)
        css.top = 40
        css.marginLeft = -@w/2
      else if position is 'bottom'
        css.left = (h * x) / (2 * y) + (w / 2)
        css.bottom = 0
        css.marginLeft = -@w/2
      else if position is 'right'
        css.top = (w * y) / (2 * x) + (h / 2)
        css.right = 0
        css.marginTop = -@h/2
      else if position is 'left'
        css.top = (-w * y) / (2 * x) + (h / 2)
        css.marginTop = -@h/2
    else #isInside
      css.top = h/2 + y
      css.left = w/2 + x
      if position is 'top'
        css.marginTop = 12 + @itemH/2
        css.marginLeft = -@w/2
      else if position is 'bottom'
        css.marginTop = -(@h + 12 + @itemH/2 + 2)
        css.marginLeft = -@w/2
      else if position is 'right'
        css.marginTop = -@h/2
        css.marginLeft = -(@w + 12 + @itemW/2 + 2)
      else if position is 'left'
        css.marginTop = -@h/2
        css.marginLeft = @itemW

    @$el.css(css)

  _destroy: () =>
    if @_destroying
      return
    @_destroying = true
    @$el.fadeOut(500, =>
      @stopListening(@options.surface, 'set-center')
      @remove()
      @trigger('destroyed')
    )

class PageView extends JLView
  className: 'page-view'


  initialize: ->
    log "pageview initialize on", @, arguments
    @surface = new TilingCanvas(@$el)
    @listenTo(@model.items, 'add', @insertOneItem)

    # Unselect an item when it is destroyed. Otherwise, it takes
    # 2 clicks instead of 1 to insert (for example), because the
    # first click is still unselecting the destroyed item.
    @listenTo(@model.items, 'destroy', (model) =>
      if model == @selectedIV?.model
        @unselectItem()
    )

    @listenTo(@model, 'change:bg_color change:bg_texture change:bg_fn', @updateBackground)
    @listenTo(@model, 'page-deleted', @_displayPageDeleted)
    @updateBackground()
    @selectedIV = null
    @listenTo(@model, 'external-item-added external-item-updated', @_externalItemAdded)

    @_activityNotifications = {}
    # Must be initialized also for page members, moved from PageOptionsView
    filepicker.setKey(JL_CONFIG.FILEPICKER_KEY)
    $.embedly.defaults.key = JL_CONFIG.EMBEDLY_KEY
    @listenTo($(window), 'keydown', @onkeydown)

    @listenTo(@model, 'change:bg_color change:bg_texture', =>
      @getLuminance((l) =>
        lumThreshold = .45
        $('.arrow-box').toggleClass('lightness-10', l < lumThreshold)
      )
    )

  remove: =>
    log "in pageview remove", @
    @surface.remove()
    super

  unbind: =>
    @dragToScroll?.destroy()
    @$el.unmousewheel()

  _displayLoadingIndicator: (x, y, message) =>
    loading = ich.tpl_loading_indicator()
    loading.hide()
    @surface.addItem(x, y, loading)
    @getLuminance((l) ->
      if l < .4
        loading.addClass('lighter-bg')
    )
    opts = {
      lines: 13
      length: 10
      width: 4
      radius: 12
      corners: 1
      rotate: 0
      color: '#fff'
      speed: 1
      shadow: false
      trail: 60
      className: 'spinner'
      zIndex: 2e9
    }

    # spinner = new Spinner(opts).spin()
    spinner = new Spinner(opts).spin()
    loading.fadeIn()
    loading.append(spinner.el)
    dfd = $.Deferred()
    dfd.always(=>
      
      loading.fadeOut(500, =>
        spinner.stop()
        loading.remove()
      )
    )
    return dfd

  _displayErrorMessage: (x, y, message) =>
    error = ich.tpl_leaf_error_message({message: message})

    error.hide()
    @surface.addItem(x, y, error)
    @getLuminance((l) ->
      if l < .4
        error.addClass('lightness-10')
    )
    error.css({
      marginTop: -error.outerHeight()/2
    })
    error.fadeIn()
    setTimeout(->
      error.fadeOut(500, =>
       error.remove()
      )
    , 2500)

  _externalItemAdded: (item, username, user_identifier) =>
    # log "External item added", item, username, user_identifier
    x = item.get('x')
    y = item.get('y')
     
    iv = item.view.$el
      
    w = iv.width()
    h = iv.height()
      
    if not @surface.isBoxInView(x, y, w, h)
      itemId = item.id
      @_activityNotifications[user_identifier]||=[]
      notifications = @_activityNotifications[user_identifier]
      for notification in notifications
        if notification.item.id == itemId
          return 

      for notification in notifications
        notification._destroy()          

      newNotification = new ActivityView({
        surface: @surface
        pageView: @
        item: item
        parent: @options.parent
        username: username
        user_id: user_identifier
      })

      @listenTo(newNotification, 'destroyed', =>
        idx = notifications.indexOf(newNotification)
        if idx > -1
          notifications.splice(idx, 1)
      )

      notifications.push(newNotification)
     
  _extractOptionsPosition: (options) =>
    initX = options.initX or 0
    initY = options.initY or 0
    if options.initId
      item = @model.items.get(options.initId)
      if not item
        return false
      [initX, initY] = @mapElementToCoordinates(item)
    return [initX, initY]

  handleNewLocation: (options) =>
    coords = @_extractOptionsPosition(options)
    if coords
      [x, y] = coords
      @surface.initScrollToCoords(x, y)

  _displayPageDeleted: =>
    # Remove all visible items from pageview
    # The page has been deletec, no one should be able to see
    # what was there
    @model.items.each((item)=>
      item.view.remove())
    overlay = ich.tpl_page_deleted()
    overlay.hide()
    @options.parent.append(overlay)
    overlay.fadeIn()
    
    # Disable arrow keys from exploring the deleted page
    $(window).off('keydown')

  _insertItem: (item) =>
    if item instanceof TextItem then View = TextItemView
    else if item instanceof ImageItem then View = ImageItemView
    else if item instanceof EmbedItem then View = EmbedItemView
    assert View, "Unknown view class for item" + item
    view = item.view = new View(model:item).render()

    # Item type order: media > text > image; admin > other
    # The tilingcanvas default is 2 (DRY this somehow). 
    # These values must be done before using surface.addItem, 
    # which overwrites the z-index to # it's internal system...
    baseZ = 2
    if item.getCreatorAffiliation() == AFFILIATIONS.OWNER
      baseZ += 4
    if item instanceof EmbedItem
      baseZ += 2
    else if item instanceof TextItem
      baseZ += 1
    view.$el.css('zIndex', baseZ)

    @surface.addItem(item.get('x'), item.get('y'), view.$el)
    view.pageView = @
    return view
  
  insertOneItem: (item) =>
    assert item instanceof Item
    view = @_insertItem item
    # view.select; view.focus
 
  render: =>
    log "rendering pageview", @model, @el
    @options.parent.append(@$el)
    if @options.fullscreen
      # We must set a size on a parent element before calling
      # @surface.render(), or else the surface gets quite upset.
      # @surface.render must also be called before @surface.resize.
      @_setParentSize()
    @surface.render()
    @listenTo($(window), 'resize', @resize)

    @dragToScroll = new DraggableSurface(@$el, (dX, dY) =>
      # Invert coordinates. Scroll-position direction  is the opposite of the direction elements move,  and TilingCanvas uses the latter. 
      @surface.moveContentBy -dX, -dY
    )
    @$el.mousewheel (e, d, dX, dY) =>
      # One "unit" is one click. We choose the distance meaning.  use ceil b/c scrollpad can give units of .025
      dX = -Math.ceil(dX*20)
      dY = Math.ceil(dY*20)
      @surface.moveContentBy dX, dY
      # Prevent browser navigation:
      e.preventDefault()
    @dragToScroll.enable()

    # Add home button
    log  "ADDING HOME BUTTON"
    i = $('<img class="home-button">')
    i.attr('src', "#{JL_CONFIG.STATIC_URL}images/home-icon-bw.png")
    i.hide() # To be revealed when we scroll away
    @options.parent.append(i)
    @listenTo(i, 'click',  => @surface.initScrollToCoords(0, 0))

    @listenTo(@surface, 'set-center', (xPosition, yPosition) =>
      distanceToCenter = vectorLen(xPosition, yPosition)
      if distanceToCenter > 1000 # 1000px is "far from home"
        i.fadeIn()
      else
        i.fadeOut()
    )

    # Finally render the items. Do this in a separate thread,
    # so that we can get the background displayed ASAP.
    setTimeout( =>
      @model.items.each(@_insertItem)
      coords = @_extractOptionsPosition(@options)
      # Move to a non zero initial position
      if coords
        [initX, initY] = coords
        # Invert direction for convention 
        # MoveContentBy shifts elements in direction opposite to coordinate positive
        # position coordinate increases down and right
        # If we want to move the view down and right, we must move
        # the content up and to the left
        @surface.moveContentBy(-initX, -initY)
    , 0)

  mapElementToCoordinates: (element) =>
    assert element 

    x = element.get('x')
    y = element.get('y')

    # Get the element for this item
    view = element.view.$el

    # Try to get the center of the item
    h = view.height()
    w = view.width()

    # get real center of odd elements
    h += (h % 2)
    w += (w % 2)

    initX = x + (w / 2)
    initY = y + (h / 2)

    return [initX, initY]

  _setParentSize: =>
    height = $(window).height()
    width = $(window).width()
    @options.parent.height(height)
    @options.parent.width(width)

  resize: (e=false) =>
    # jquery ui's resize event was triggering this, hence making sure target isn't window.
    # and its no longer instance of Window, because that varies across browsers
    if e?.target is window or e is false
      if @options.fullscreen
        log 'pageview resizing'
        @_setParentSize()
        @surface.resize()

  updateBackground: =>
    log "updateBackground"
    textureName = @model.get 'bg_texture'
    color = @model.get 'bg_color'
    @$el.css 'background-color', color or 'white'
    if textureName
      if Assets.BGPatterns.hasKey textureName
        texture = Assets.BGPatterns.get textureName
        @surface.setBackground(texture.url, texture.size)
      else
        # Hacky. Should store h/w server-side after first save.
        # Also, non-DRY with setBGImageFromFilePicker.
        i = new ImageAtURL(textureName)
        i.ensureSize =>
          Assets.BGPatterns.add i
          @surface.setBackground(i.url, i.size)
    else
      @surface.clearBackground()

  setSelectedIV: (itemView) =>
    log 'selecting', itemView
    @_prevSelected = @selectedIV
    if itemView == @selectedIV
      return
    @selectedIV?.setStateView()
    @selectedIV = itemView
    if itemView
      # Guess what? This .disable() is critical. Without it,
      # the DraggableSurface cancels all mousedowns that reach
      # it, which prevents text selection and movement inside
      # of a TextItem's contenteditable. (We happened to have the line
      # here before that for UX/aesthetic reasons.)
      @dragToScroll.disable()
    else
      @dragToScroll.enable()
      # Wow, this blur. It makes sure there's no blue outline around
      # the item after you deselect it. But also! It's magically
      # critical for performance on Chrome on really full pages.
      # See the note in DraggableSurface referencing 
      # http://code.google.com/p/chromium/issues/detail?id=103148.
      # Without it, scrolling around is fast at first, but when
      # you select and deselect an item, it gets slow. With this blur
      # in place, selecting and deselecting maintains the scroll
      # speed. Doesn't make much sense, since the item is getting
      # blurred either way, but it's the truth.
      # In IE9 hitting enter while editing a text item switches focus to any
      # other window that is open.  Adding this check avoids that undesired behavior
      # Though this behavior is not replicated in ie9 inside andrew's virtual machine
      if document.activeElement.tagName != 'BODY'
        $(document.activeElement).blur()
    @.trigger('set-selected-itemview', @selectedIV)

  unselectItem: =>
    log 'unselecting', @selectedIV
    @setSelectedIV(null)

  onmousedown: (event) =>
    # Things we might want to do:
    # - select an item to edit
    # - click and drag to scroll
    # - click to insert a new item
    # This event handler keep track of which we should do on mousemove/up.
    log 'mousedown', event

    # Cancel any auto-scrolling
    @surface.cancelScrolling()

    # Some click events are fully handled by the item's view
    target = $(event.target)
    if target.hasClass('item-ctrl') or target.parents('.item-ctrl').length
      log "Page letting item handle item-ctrl mouse event"
      return true
    if (target.prop('tagName') == 'A') or target.parents('a').length
      # Let links handle their own clicks. Items which are links
      # are responsible for providing another way to select them.
      return true

    # If the item view had already put itself back into 'view'
    # mode -- e.g., by pushing ENTER to finalize an edit --
    # then don't treat this click as an unselect. Instead, 
    # update @selectedIV and proceed as though nothing was
    # selected when the user mousedown'ed. We may want to do this
    # somewhere else, like by listening for a self-unselect event.
    if @selectedIV and (@selectedIV.getState() == TextItemView.STATES.VIEW)
      @unselectItem()

    # Set up
    user = JL.AuthState.getUser()
    page = @model
    itemView = $(event.target).parents('.item').andSelf().data('view')
    item = itemView?.model
    isAdmin = Permissions.currentUserCanEditPage(page)
    canEditItem = isSelectedItem = false
    if itemView
      canEditItem = Permissions.canEditItem(item)
      isSelectedItem = (itemView == @selectedIV)

    log "Processing mousedown with state:", user, page, itemView, item, isAdmin, canEditItem, isSelectedItem, @selectedIV

    # If we clicked on an item that we can do something to, that
    # action takes priority
    if item
      if @selectedIV
        if isSelectedItem
          # Do nothing -- let item view handle all clicks, for e.g.
          # setting cursor position or selecting text.
          true
        else
          # We clicked a different item than the one we're editing.
          # Unselect the one we're editing.
          @unselectItem()
          if $(event.target).hasClass('edit-btn')
            @_pendingSelection = {
              itemView: itemView
              type: 'admin'
            }
      else 
        # A non admin that can edit the item should have admin state
        # on that item.
        if isAdmin or canEditItem
          # The item was not selected, and we're admins. 
          # Put it in admin mode.
          @_pendingSelection = {
            itemView: itemView
            type: 'admin'
          }
        else
          @_pendingSelection = {
            itemView: itemView
            type: 'engaged'
          }
        # else if canEditItem
        #   # We aren't admins, but we can edit this item. Go
        #   # to edit mode.
        #   @_pendingSelection = {
        #     itemView: itemView
        #     type: 'edit'
        #   }
        # HERE is where you'd create a pendingInsert if you want to let people click
        # and write on top of each other directly. What to do?
      return

    assert not item
    @_pendingSelection = null

    # Check if we have a previously selected item that we're clicking
    # 'out' of to deselect
    if @selectedIV
      @unselectItem()
      # Return, because it's annoying to create immediately when
      # you're just trying to unselect something.
      return

    # Or, finally, we might be clicking to insert a new item
    canInsert = Permissions.currentUserCanInsertTextItem(page)
    if canInsert
      assert not @_pendingSelection
      @_pendingInsert = {
        time: new Date().getTime()
        x: event.screenX
        y: event.screenY
      }
   
  onmousemove: (event) =>
    @_pendingSelection = null
    @_pendingInsert = null

  onmouseup: (event) =>
    if @_pendingSelection
      itemView = @_pendingSelection.itemView
      type = @_pendingSelection.type
      log 'selecting', itemView, 'with mode', type
      @_pendingSelection = null
      @setSelectedIV(itemView)
      switch type
        when 'admin'
          itemView.setStateAdmin()
          if $(event.target).hasClass('edit-btn')
            # hax
            @options.parentView.pageOptionsView.hide()
            @options.parentView.itemEditor.show()
            itemView._hideEditButton() # hax
        when 'edit'
          itemView.setStateEdit()
        when 'engaged'
          itemView.setStateEngaged()
        else
          throw new Error("Unknown selection type", type)
    else if @_pendingInsert
      log 'insert at ', @_pendingInsert
      @insertPending(event)

  _createItem: (itemClass, attrs) =>
    # NB doesn't save the item
    $.extend(attrs, {
      creator_id: JL.AuthState.getUserId()
    })
    item = new itemClass(attrs)
    item.page = @model
    @model.items.add(item)
    assert item.view
    view = item.view
    @setSelectedIV(view)
    view.setStateEdit()
    item.once('change:id', =>
      mixpanel.track("Item created", {type: itemClass.shortName})
    )
    return item

  createImageFromFPFile: (fpfile, x, y) =>
    # creates an image from a filepicker file
    # TODO: make view 'pending' until save-to-server successful
    # all image creation is expected to go through here
    item = @_createItem(ImageItem, {
      x: x
      y: y
      src: fpfile.url
    })
    getImageSize(fpfile.url, (width, height) =>
      [width, height] = scaleBoxSize(width, height, 1000) # limit items to 1000 h/w
      item.set('width', width)
      item.set('height', height)
      item.save()
    )

  createEmbed: (x, y, url) =>
    # TODO: DRY with _createItem
    loadingDfd = @_displayLoadingIndicator(x, y)
    item = new EmbedItem({
      x: x
      y: y
      original_url: url
    })
    item.page = @model
    dfd = item.save().always(=>
      loadingDfd.resolve()
    ).done( =>
      mixpanel.track("Item created", {type: EmbedItem.shortName})
      @model.items.add(item)
      assert item.view
      view = item.view
      @setSelectedIV(view)
      view.setStateEdit()
    ).fail( =>
      @_displayErrorMessage(x, y, "Couldn't convert URL to embed. Check your link and try again.")
      log "Couldn't convert URL to embed"
    )
    return dfd

  _insertNewText: (x, y, options={}) =>
    # Create and insert a brand new item
    log "inserting new text item at coordinates", x, y
    attributes = _.extend({x: x, y:y}, options)
    @_createItem(TextItem, attributes)

    # Hide the cursor when you're first inserting. Otherwise, it covers up the
    # insertion caret, which is confusing and unpretty.
    @$el.css('cursor', 'none')
    # Why do we need this setTimeout 250? I don't know.  A mysterious mousemove
    # event is triggered on the text item content div when it is created.
    # Somehow, 100ms is not enough time.
    setTimeout( =>
      @$el.one('mousemove', (e) =>
        @$el.css('cursor', '')
      )
    , 250)


  insertPending: (e) =>
    # insert the pending pending item
    if not @_pendingInsert then return

    # Get surface coordinates for insertion
    # TODO: do we have clientX/clientY here?
    log e.pageX, '-',  @$el.offset().left
    screenX = e.pageX - @$el.offset().left
    screenY = e.pageY - @$el.offset().top
    [x, y] = @surface.screenPixelsToCoords screenX, screenY

    # Compensate for padding and cursor so that you insert in the middle
    # of where you clicked
    itemPadding = 2 # NB coupled with page.less
    lineHeight = 13 # TODO: get from app
    x -= itemPadding
    y -= itemPadding
    y -= Math.floor(lineHeight/2)

    @_insertNewText(x, y)

  insertPendingNewline: =>
    if @selectedIV or (@_prevSelected not instanceof TextItemView)
      return
    mixpanel.track("Enter-to-insert")
    x = @_prevSelected.model.get('x')
    # We need the minus-2 to account for the 1-pixel
    # border that's currrently around items. (It's
    # transparent unless you're adminning the item.)
    # coupled with page.less. The goal here is to get
    # them to touch seamlessly.
    y = @_prevSelected.model.get('y') + @_prevSelected.$el.outerHeight() - 2
    @_insertNewText(x, y, {font_size: @_prevSelected.model.get('font_size')})
    
  onkeydown: (e) =>
    log 'keydown', e, e.which
    if document.activeElement.tagName != 'BODY'
      # We are in a form field; keys probably do something to it
      return
    item = @selectedIV?.model
    d = 42
    switch e.which
      when $.ui.keyCode.DOWN
        if e.altKey or e.shiftKey 
          item?.edit('y', item.get('y') + 1, {instant: true})
        else
          @surface.moveContentBy 0, -d
      when $.ui.keyCode.UP
        if e.altKey or e.shiftKey 
          item?.edit('y', item.get('y') - 1, {instant: true})
        else
          @surface.moveContentBy 0, d
      when $.ui.keyCode.LEFT
        if e.altKey or e.shiftKey 
          item?.edit('x', item.get('x') - 1, {instant: true})
        else
          @surface.moveContentBy d, 0
      when $.ui.keyCode.RIGHT
        if e.altKey or e.shiftKey 
          item?.edit('x', item.get('x') + 1, {instant: true})
        else
          @surface.moveContentBy -d, 0
      when $.ui.keyCode.PAGE_DOWN
        @surface.moveContentBy 0, -d*5
      when $.ui.keyCode.PAGE_UP
        @surface.moveContentBy 0, d*5
      when $.ui.keyCode.HOME
        @surface.initScrollToCoords(0, 0)
      when $.ui.keyCode.ESCAPE
        @unselectItem()
      when $.ui.keyCode.ENTER
        e.preventDefault() # Don't insert into new field
        @insertPendingNewline()
      when $.ui.keyCode.DELETE
        @selectedIV?.delete()
      when $.ui.keyCode.BACKSPACE
        e.preventDefault() # stop navigation
        @selectedIV?.delete()

  events:
    'mousedown .tilingcanvas-canvas': 'onmousedown'
    'mousemove .tilingcanvas-canvas': 'onmousemove'
    'mouseup .tilingcanvas-canvas': 'onmouseup'
    'dragover': (e) -> e.preventDefault() # prevent navigation on drop
    'drop': 'ondrop'


  ondrop: (e) =>
    # TODO: some kind of "loading..." indicator
    e.preventDefault()
    e = e.originalEvent
    f = e.dataTransfer.files[0]
    if f.type.indexOf('image/') != 0
      return
    [windowX, windowY] = [e.clientX, e.clientY]
    [x, y] = @surface.screenPixelsToCoords(windowX, windowY)
    loadingDfd = @_displayLoadingIndicator(x, y)
    fpStore(f).done((fpfile) =>
      loadingDfd.resolve()
      @createImageFromFPFile(fpfile, x, y)
    )

  getLuminance: (callback) =>
    bg_color = @model.get('bg_color')
    textureName = @model.get('bg_texture')
    # TODO: DRY with @updateBackground
    if textureName 
      if Assets.BGPatterns.hasKey(textureName)
        texture = Assets.BGPatterns.get textureName
        url = texture.url
      else
        url = textureName
    Color.getBGLuminance(bg_color, url, callback)

class Pane extends JLView
  toggle: =>
    @_visible = not @_visible
    @$el.css('overflow-y', 'hidden')
    $('.page-options-dropdown').addClass('toggling')
    @$el.toggle('slide', {
        direction: "right", 
        speed: 'fast'
      }, ( => 
        @$el.css('overflow-y', 'auto')
        $('.page-options-dropdown').removeClass('toggling')
      )
    )

  hide: =>
    if @_visible
      @toggle()    

  show: =>
    if not @_visible
      @toggle()   

  events:
    'click .bootstrap-close' : 'toggle'


class PageOptionsView extends Pane
  initialize: =>
    @$el = ich.tpl_page_viewer_options().appendTo(@options.parent)
    @_visible = false
    new TabbedPane(@$el)
    @_bindStyleOptions()
    @_bindSettingsOptions()

  unbind: =>
    @_checkBoxButton?.destroy()
    @rview?.unbind()
    @_fontSelector?.destroy()

  _bindStyleOptions: =>
    model = @model
    @fontOptions = (
      {
        # hacky workaround for rivets trying to bind
        font: font
      } for font in Assets.Fonts.list()
    )
    @bgTextureOptions = (
      {
        val: texture.name
        src: texture.url
      } for texture in Assets.BGPatterns.list()
    )

    
    # If the user chooses 'Custom', and no custom texture is already selected,
    # open the chooser
    @_customBGLabel = $('.custom-texture-radio').css('background-size', '100%')
    @_customBGInput = $('.custom-texture-radio input')
    @_customBGChange = $('.custom-texture-change')
    @listenTo(@_customBGLabel, 'click',  =>
      # 'on' is .value for valueless, checked radios.
      hasValue = @_customBGInput.val() and @_customBGInput.val() != 'on'
      if hasValue
        model.edit('bg_texture', @_customBGInput.val())
      else
        @chooseCustomBG()
    )

    # If they click 'change', let them select a new custom texture
    @listenTo(@_customBGChange, 'click', @chooseCustomBG)
    # Check 'Custom' by default if the BG isn't in our known set, and set the .value of the radio,
    # and use it as the bg image
    url = model.get('bg_texture')
    if Assets.isCustomPattern url
      @_customBGInput.attr('checked', 'checked').attr('value', url)
      @_customBGLabel.css('background-image', "url('#{url}')")
      @_customBGChange.show()
    else
      @_customBGChange.hide()
    @rview = rivets.bind @$el,
        page: model
        view: @


    pageOptionsColorPicker = $('.pageOptions .colorPickerInput').colorpicker()
    @listenTo(pageOptionsColorPicker, 'changeColor', (ev) ->
      colorFormat = $(@).data('color-format')
      if colorFormat == 'rgba'
        rgb = ev.color.toRGB()
        colorString = "rgba(#{rgb.r}, #{rgb.g}, #{rgb.b}, #{rgb.a})"
      else
        colorString = ev.color.toHex()
      path = $(@).data('rv-value')
      path = path.split('.')[1]
      model.edit(path, colorString)
    )

    # Manual binding on font selector
    initialFontFamily = model.get('default_textitem_font')
    if initialFontFamily == ''
      initialFont = ['builtin', '', 'default']
    else
      initialFont = ['google', initialFontFamily, initialFontFamily]
    @_fontSelector = new FontSelector($('.pageOptions .fontselector'), {
      initial: initialFont
      selected: (style) =>
        log "picked", style
        style = style.replace(/'/g, '')
        model.edit('default_textitem_font', style)
    })

  chooseCustomBG: => 
    fpPickImage().done(@setBGImageFromFilePicker)

  _bindSettingsOptions: =>
    # Title
    title = @$('input.title')
    title.val(@model.get('title'))
    @listenTo(title, 'change keyup paste', =>
      @model.edit('title', title.val())
    )

    # Memberships
    members = @$findOne('.members')
    new MembersView({
      el: members
      pageId: @model.get('id')
      template: ich.tpl_page_viewer_members
    }).render()
    members.show('slideDown')

    # Text writability options
    
    text_writability = @$('select[name=text_writability]')
    text_writabilityVal = parseInt(@model.get('text_writability'))

    assert text_writabilityVal in _.values(PERMISSIONS)

    text_writability.val(text_writabilityVal)

    @listenTo(text_writability, 'change', =>
      newVal = parseInt(text_writability.val())
      log "text_writability val changed", newVal

      assert newVal in _.values(PERMISSIONS)

      @model.edit('text_writability', newVal)
      
    )

    # Image writability options
    
    image_writability = @$('select[name=image_writability]')
    image_writabilityVal = parseInt(@model.get('image_writability'))

    assert image_writabilityVal in _.values(PERMISSIONS)

    image_writability.val(image_writabilityVal)

    @listenTo(image_writability, 'change', =>
      newVal = parseInt(image_writability.val())
      log "image_writability val changed", newVal

      assert newVal in _.values(PERMISSIONS)

      @model.edit('image_writability', newVal)
      
    )

    publishedCheckbox = @$findOne('.published')
    @_checkBoxButton = new CheckboxButton(publishedCheckbox, {
      model: @model
      attribute: 'published'
    })

    # Clear button
    clearBtn = @$findOne('input.clear')
    clearConfirm = @$findOne('.clear_confirm')
    clearProgress = @$findOne('.clear_progress')
    @listenTo(clearBtn, 'click', =>
      clearBtn.hide()
      clearConfirm.show()
      clearProgress.hide()
    )
    clearConfirmYes = @$findOne('.clear_confirm .yes')
    @listenTo(clearConfirmYes, 'click', =>
      dfd = API.instanceMethod(@model, 'clear')
      clearConfirm.hide()
      clearProgress.text('Clearing...').show()
      dfd.fail( =>
        clearProgress.text("Couldn't clear the page. Please refresh and try again."))
      dfd.done( =>
        clearProgress.text("Page cleared!")
        clearBtn.show()
      )
    )
    clearConfirmNo = @$findOne('.clear_confirm .no')
    @listenTo(clearConfirmNo, 'click', =>
      clearBtn.show()
      clearConfirm.hide()
    )

    # Delete button
    deleteBtn = @$el.findOne('input.delete')
    deleteConfirm = @$el.findOne('.delete_confirm')
    @listenTo(deleteBtn, 'click', =>
      deleteBtn.hide()
      deleteConfirm.show()
    )
    deleteConfirmYes = @$findOne('.delete_confirm .yes')
    @listenTo(deleteConfirmYes, 'click', =>
      @$el.empty().text('Deleting...')
      @model.destroy({
        success: =>
          @hide()
        error: @_errBack('Error deleting! Refresh the page and try again.')
      })
    )
    deleteConfirmNo = @$findOne('.delete_confirm .no')
    @listenTo(deleteConfirmNo, 'click', =>
      deleteBtn.show()
      deleteConfirm.hide()
    )

  _errBack: (msg) =>
    # Callback maker
    return ( =>
      @$el.empty().text(msg)
    )
  setBGImageFromFilePicker: (fpfile) =>
    url = fpfile.url
    log "setBGImageFromFilePicker called with", url
    # Update 'Custom radio'
    @_customBGInput.attr('checked', 'checked').attr('value', url)
    @_customBGLabel.css('background-image', "url('#{url}')")
    @_customBGChange.show()
    if Assets.BGPatterns.hasKey url
      @model.edit('bg_texture', url)
      return
    else
      i = new ImageAtURL(url)
      i.ensureSize =>
        Assets.BGPatterns.add i
        @model.edit('bg_texture', url)

class ImageItemOptionsView extends JLView
  initialize: ->
    @setElement(ich.tpl_image_item_options())
    @$el.appendTo(@options.parent)

    @$('.colorPickerInput').colorpicker()

    t = @_tendon = new Tendon.Tendon(@$el, {})
    t.useBundle(Tendon.colorPickerBundle, ['item', 'border_color', '.colorPickerInput'])
    t.useBundle(Tendon.twoWay, ['item', 'link_to_url', '.linkInput'])
    t.useBundle(Tendon.twoWayInt, ['item', 'border_width', '.border-width'])

    # Direct link
    @listenTo(@$findOne('textarea.direct-link'), 'click', ->@.select())
    t.useBinding(Tendon.makePull, [
      'item', 'change:id', F.caller('getAbsoluteUrl'), 
      'textarea.direct-link', Tendon.setValue
    ])

    @listenTo(@options.pageView, 'set-selected-itemview', @_updateSourceMap)
    @_updateSourceMap()

  _updateSourceMap: =>
    item = @options.pageView.selectedIV?.model
    if not (item instanceof ImageItem)
      item = null
    @_tendon.updateSourceMap({
      item: item
    })

  unbind: =>
    @_tendon.unbind()

class EmbedItemOptionsView extends JLView
  initialize: ->
    @setElement(ich.tpl_embed_item_options())
    @$el.appendTo(@options.parent)

    t = @_tendon = new Tendon.Tendon(@$el, {})

    # Direct link
    @listenTo(@$findOne('textarea.direct-link'), 'click', ->@.select())
    t.useBinding(Tendon.makePull, [
      'item', 'change:id', F.caller('getAbsoluteUrl'), 
      'textarea.direct-link', Tendon.setValue
    ])

    @listenTo(@options.pageView, 'set-selected-itemview', @_updateSourceMap)
    @_updateSourceMap()

  _updateSourceMap: =>
    item = @options.pageView.selectedIV?.model
    if not (item instanceof EmbedItem)
      item = null
    @_tendon.updateSourceMap({
      item: item
    })

  unbind: =>
    @_tendon.unbind()

class TextItemOptionsView extends JLView
  _updateSourceMap: =>
    itemView = @options.pageView.selectedIV
    if itemView instanceof TextItemView
      item = itemView.model
    else
      item = itemView = null
    @_tendon.updateSourceMap({
      item: item
      itemView: itemView
    })

  initialize: =>
    # Render
    @setElement(ich.tpl_text_item_editor({
      fonts: Assets.Fonts.list()
      itemLink: 'http://www.example.com/'
    }))
    @$el.appendTo(@options.parent)
    @$('.colorPickerInput').colorpicker()

    # Set up bindings
    @_tendon = new Tendon.Tendon(@$el, {
      page: @options.pageView.model
      optionsView: @
    })
    @listenTo(@options.pageView, 'set-selected-itemview', @_updateSourceMap)
    @_updateSourceMap()

    #
    # Create bindings
    #
    #
    
    # Direct link
    @listenTo(@$findOne('textarea.direct-link'), 'click', ->@.select())
    @_tendon.useBinding(Tendon.makePull, [
      'item', 'change:id', F.caller('getAbsoluteUrl'), 
      'textarea.direct-link', Tendon.setValue
    ])

    # Color pickers
    @_tendon.useBundle(Tendon.fancyColorPickerBundle, ['item', 'page', 'itemView', 'color', '.colorPickerInput.fg-color', F.caller('getColor'), @$el])

    @_tendon.useBundle(Tendon.fancyColorPickerBundle, ['item', 'page', 'itemView', 'bg_color', '.colorPickerInput.bg-color', F.caller('getBGColor'), @$el])

    # Font size spinner
    @_tendon.useBundle(Tendon.fancyFontSizeBundle, ['item', 'page', 'itemView', 'font_size', '.fontSizeSpinner'])

    # Font chooser
    # TODO: move 'initial' into markup (modify lib)
    # so we don't need to specify it at create-time
    fontEl = @$el.findOne('.fontselector')
    @_fontSelector = new FontSelector(fontEl, {
      initial: ['builtin', '', 'default']
    })
    @_tendon.useBinding(Tendon.bbPush, ['item', 'font', '.fontselector', Tendon.getFontPicker, 'fontChange'])
    fontFaceEventMap = Tendon.fancyStyleValueEventMap('item', 'page', 'font')
    fontFaceHandler = (itemView) =>
      fontFamily = itemView.getFontFace()
      # hack around 'inherit'
      if fontFamily == 'inherit'
        fontFamily = 'Arial'
      fullFont = Assets.Fonts.getByFamily(fontFamily)
      @_fontSelector.setSelected(fullFont.family, fullFont.displayName)
    fontFacePuller = new Tendon.Binding(fontFaceEventMap, ['itemView'], fontFaceHandler, true)
    @_tendon.addBinding(fontFacePuller)

    # Link-to-URL
    @_tendon.useBundle(Tendon.twoWay, ['item', 'link_to_url', '.linkInput'])

  unbind: =>
    @_tendon.unbind()
    @_fontSelector.destroy()


class ItemEditor extends Pane
  initialize: ->
    @_visible = false
    @_default = @$el.findOne('.default-content')
    @textItemEditor = new TextItemOptionsView({
      pageView: @options.pageView
      parent: @options.parent
    })
    @imageItemEditor = new ImageItemOptionsView({
      pageView: @options.pageView
      parent: @options.parent
    })
    @embedItemEditor = new EmbedItemOptionsView({
      pageView: @options.pageView
      parent: @options.parent
    })
    content = @$el.findOne('.editor-content')
    content.append(@textItemEditor.$el)
    content.append(@imageItemEditor.$el)
    content.append(@embedItemEditor.$el)
    @listenTo(@options.pageView, 'set-selected-itemview', @_setItemView)
    @_setItemView(@options.pageView.selectedIV)

  _setItemView: (itemView) =>
    item = itemView?.model
    if not item
      @textItemEditor.$el.hide()
      @imageItemEditor.$el.hide()
      @embedItemEditor.$el.hide()
      @_default.show()
    else if item instanceof TextItem
      @textItemEditor.$el.show()
      @embedItemEditor.$el.hide()
      @imageItemEditor.$el.hide()
      @_default.hide()
    else if item instanceof ImageItem
      @textItemEditor.$el.hide()
      @embedItemEditor.$el.hide()
      @imageItemEditor.$el.show()
      @_default.hide()
    else 
      assert instanceof EmbedItem
      @textItemEditor.$el.hide()
      @embedItemEditor.$el.show()
      @imageItemEditor.$el.hide()
      @_default.hide()

class MiniMapView extends JLView

  events: {
    'click .minimap-inner': 'click'
    'click .minimap-right': 'toggleMinimize'
    # 'mouseup':   
  }

  initialize: ->
    @pageView = @options.pageView
    @surface = @pageView.surface
    @items = @pageView.model.items
    
    @miniMapWidth = 184
    @miniMapHeight = 150
    @_PADDING = 1000
    @_visible = true
    @_minimized = true
    
    # Initialize the canvas
    canvas = @$findOne('canvas.minimap-canvas')[0]
    @context = canvas.getContext('2d')
    canvas.width = @miniMapWidth
    canvas.height = @miniMapHeight

    @viewRect = @$findOne('div.view-rect')
    @homeRect = @$findOne('div.home-rect')

    @minimizeBtn = @$('div.minimap-minimize-btn')
    @_minimapContainer = @$findOne('div.minimap-container')
    @_calculatePageBounds()

    # Allow the items to be rendered by the page view
    # so that the item views exist already and we can 
    # access their height and width
    setTimeout(=>
      @_renderAllItems()
      @_bindItemListeners()
    , 0)

    @listenTo(@surface, 'set-center', @_positionViewWindow)
    @listenTo(@surface, 'resize', @_resizeViewWindow)
    @listenTo(@pageView.model, 'change:bg_color change:bg_texture', @_changeBackgroundAppearance)

    [centerX, centerY] = @surface.getCenter()
    
    # Local copy of surface viewable window size and position
    @surfaceWindow = {
      centerX: centerX
      centerY: centerY
      width: @surface.width
      height: @surface.height
    }
 
    @_changeBackgroundAppearance()
    @_positionViewWindow(@surfaceWindow.centerX, @surfaceWindow.centerY)
    @_resizeViewWindow(@surfaceWindow.width, @surfaceWindow.height)
    @_makeDraggable()

  _changeBackgroundAppearance: =>
    @pageView.getLuminance((l) =>
      log "got luminance", l
      maxAlpha = .3
      lumThreshold = .45
      alpha = 0 
      if l < lumThreshold 
        alpha = maxAlpha * (1 - l/lumThreshold)
      bg = "rgba(255, 255, 255, #{alpha})"
      log "setting bg to", bg
      @_minimapContainer.css({backgroundColor: bg})
    )

  _renderAllItems: =>
    @context.clearRect(0, 0, @miniMapWidth, @miniMapHeight)
    for item in @items.models
      @_renderItem(item) 
    # log "translating to #{@translation}"
    @$findOne('canvas.minimap-canvas').css({
      left: @translation[0]
      top: @translation[1]
      })

  toggleMinimize: (e) =>
    @$el.toggleClass('minimized', !@_minimized)
    @_minimized = !@_minimized      

    content = if @_minimized then '&raquo;' else '&laquo;'
    @minimizeBtn.empty().html(content)
   
  toggleVisible: (e) =>
    @$el.toggleClass('hidden', @_visible)
    @_visible = !@_visible

  _bindItemListeners: =>
    @listenTo(@items, 'add remove change:content edit:x edit:y change:x change:y change:width change:height', @_itemChanged)

  _itemChanged: (item) =>
    @_calculatePageBounds()
    @_renderAllItems()
    @_positionViewWindow(@surfaceWindow.centerX, @surfaceWindow.centerY)
    @_resizeViewWindow(@surfaceWindow.width, @surfaceWindow.height)

  _renderItem: (item) =>
    if not item
      return
    itemPoint = item.getPoint()

    [x, y] = @_mapPagePointToMini(itemPoint)
    height = 2 
    width = 2
    if item.view
      height = item.view.$el.height()
      width = item.view.$el.width()

    scaledHeight = Math.ceil(height * @scale)
    scaledWidth = Math.ceil(width * @scale)

    h = Math.max(scaledHeight, 2)
    w = Math.max(scaledWidth, 2)

    @context.fillStyle = "rgba(0, 0, 0, 0.5)"
    @context.fillRect(x, y, w, h)

  _calculatePageBounds: =>
    # The coordinates of the upper left point of the rendered universe
    @translation = [0, 0]
    @topLeft = [0, 0]
    @bottomRight = [0, 0]
    for item in @items.models
      itemPoint = item.getPoint()
      for dim in [0,1]
        if itemPoint[dim] < @topLeft[dim]
          @topLeft[dim] = itemPoint[dim]
        else if itemPoint[dim] > @bottomRight[dim]
          @bottomRight[dim] = itemPoint[dim]
      
    @topLeft[0] -= @_PADDING
    @topLeft[1] -= @_PADDING
    @bottomRight[0] += @_PADDING
    @bottomRight[1] += @_PADDING

    @_calculateScale()

  # We need to decide if we scale to the horizontal or vertical dimension
  # to make the whole view fit inside the minimap, which has a fixed aspect
  # ratio.
  _calculateScale: =>
    minimapAspectRatio = @miniMapWidth/@miniMapHeight
    canvasAspectRatio = (@bottomRight[0] - @topLeft[0])/(@bottomRight[1] - @topLeft[1])
    
    # horizontal canvas dimension is larger, needs vertical centering
    if minimapAspectRatio < canvasAspectRatio
      # log "wider than tall"
      @scale = @miniMapWidth/(@bottomRight[0] - @topLeft[0])
      extraSpace = @miniMapHeight - (@scale * (@bottomRight[1] - @topLeft[1]))
      @translation[1] = extraSpace/2
    # vertical dimension is larger, needs horizontal centering
    else
      # log 'taller than wide'
      @scale = @miniMapHeight/(@bottomRight[1] - @topLeft[1])
      extraSpace = @miniMapWidth - (@scale * (@bottomRight[0] - @topLeft[0]))
      @translation[0] = extraSpace/2

  _mapPagePointToMini: (point) =>
    # offset origin to be top left point 
    newX = Math.round(@scale * (point[0] - @topLeft[0]))
    newY = Math.round(@scale * (point[1] - @topLeft[1]))
    return [newX, newY]

   _mapMiniPointToPage: (point) =>
    newX = Math.round(point[0] / @scale + @topLeft[0])
    newY = Math.round(point[1] / @scale + @topLeft[1])
    return [newX, newY]

  _resizeViewWindow: (w, h) =>

    @surfaceWindow.height = h
    @surfaceWindow.width = w
    newHeight = Math.ceil(h * @scale)
    newWidth = Math.ceil(w * @scale)
    
    @viewRect.height(newHeight)
    @viewRect.width(newWidth)

    @homeRect.height(newHeight)
    @homeRect.width(newWidth)

  _positionViewWindow: (centerX, centerY) =>
    @surfaceWindow.centerX = centerX
    @surfaceWindow.centerY = centerY
    # ignore the set-center events from surface, since we're moving the viewRect
    if @_dragging
      return
    surfaceTopLeftX = @surfaceWindow.centerX - @surfaceWindow.width/2
    surfaceTopLeftY = @surfaceWindow.centerY - @surfaceWindow.height/2
    topLeftView = [surfaceTopLeftX, surfaceTopLeftY]
    topLeftViewTranslated = @_mapPagePointToMini(topLeftView)

    homeViewTopLeft = [-@surfaceWindow.width/2, -@surfaceWindow.height/2]
    homeViewTopLeftTranslated = @_mapPagePointToMini(homeViewTopLeft)
    @homeRect.css({
      top: Math.ceil(@translation[1] + homeViewTopLeftTranslated[1])
      left: Math.ceil(@translation[0] + homeViewTopLeftTranslated[0])
    })

    # The translation shifts the viewRect div to the correct display
    # position, corresponding to the margin added to the canvas
    @viewRect.css({
      top: Math.ceil(@translation[1] + topLeftViewTranslated[1])
      left: Math.ceil(@translation[0] + topLeftViewTranslated[0])
    })

  _movePageToMiniPoint: (miniX, miniY) =>
    [pageX, pageY] = @_mapMiniPointToPage([miniX, miniY])
    @surface.moveContentBy(@surfaceWindow.centerX-pageX, @surfaceWindow.centerY-pageY)

  click: (e) =>
    containerOffset = $(e.currentTarget).offset()
    relX = e.pageX - containerOffset.left
    relY = e.pageY - containerOffset.top

    # compensate for viewRect translation.  The coordinate systems are shifted
    # by the transliation for the viewRect.  This subtraction realigns
    # the coordinate systems.
    relX -= @translation[0]
    relY -= @translation[1]
    @_movePageToMiniPoint(relX, relY)

  _dragSurface: (e, ui) =>
    # center the coords
    miniX = ui.position.left + @viewRect.width()/2
    miniY = ui.position.top + @viewRect.height()/2
    # compensate for viewRect translation.  The coordinate systems are shifted
    # by the transliation for the viewRect.  This subtraction realigns
    # the coordinate systems.
    miniX -= @translation[0]
    miniY -= @translation[1]
    @_movePageToMiniPoint(miniX, miniY)

  _makeDraggable: =>
    @viewRect.draggable({
      handle: @viewRect 
      containment: 'parent'
      start: =>  
        @_dragging = true; 
        @viewRect.css('cursor', 'move')
      stop: => 
        @_dragging = false; 
        @viewRect.css('cursor', 'pointer')
      drag: @_dragSurface
    })

class SuggestedFollowView extends JLView
  events: {
    'click .reject-btn':  '_rejectFollowSuggestion'
  }

  render: =>
    @$el.empty()
    @$el.append(ich.tpl_suggested_follow(
      username: @model.get('username')
      profileUrl: @model.profileUrl()
      )
    )
    makeFollowButton(@$el.findOne('button'), @model)
    return @

  _rejectFollowSuggestion: (item, collection, options) =>
    log "Rejecting this guy", item
    rejection = new RejectedFollowSuggestion({
      user_id: JL.AuthState.getUserId()
      target_id: @model.id
    })
    rejection.save().done(
      @remove()
    )


class SuggestedFollowsView extends JLView
  initialize: ->
    @$el.hide()
    API.xhrMethod('get-suggested-follows').done((response) =>
      if response.success
        @_gotSuggestedFollows(response.data)
      )

  _gotSuggestedFollows: (users) =>
    log "Got users", users

    # Render friends div
    if users.length
      el = @$findOne('.users-list')
      for user in users
        view = new SuggestedFollowView({model:new User(user)})
        viewEl = view.render().$el
        el.append(viewEl)
      el.show()
      @$el.show()
    
class TutorialView extends JLView
  className: 'tutorial'

  # A tutorial step has three components:
  #  copy: Text explaining what to do
  #  checker: a function that determines whether the step
  #   has been successfully completed
  #  triggers: a list of (object, event) pairs to listen to
  #   to recalculate the `checker` value
  #  optionally, noUncheck (default:false), whether the completed
  #   value can never be unset once it has been set
  makeSteps: (page, surface) =>
    return [
      {
        copy: "To write, click anywhere on the page and start typing."
        checker: => 
          textItems = page.items.byType('textitem')
          return _.any(textItems, (i) -> i.get('content')?.length)
        triggers: [
          [page.items, 'add']
          [page.items, 'remove']
          [page.items, 'change:content']
        ]
      }

      {
        copy: "Click and drag your mouse to scroll around. Your page is as big as you need it to be."
        checker: => 
          # Waiting for just 1 pixels feels too fast,
          # so we wait for a 20 pixel distance.
          return Vec.len(surface.getCenter()) > 20
        triggers: [
          [surface, 'set-center']
        ]
        noUncheck: true
      }

      {
        copy: "Customize the background color or image of your page. To open or close the options menu, click the gear icon at the top right of the screen and choose 'Page options' from the dropdown."
        checker: =>
          # TODO: not DRY with models
          isDefaultColor = page.get('bg_color') == '#F5EDE1'
          isDefaultImage = page.get('bg_texture') == 'light_wool_midalpha.png'
          return not (isDefaultColor and isDefaultImage)
        triggers: [
          [page, 'change:bg_color']
          [page, 'change:bg_texture']
        ]
        noUncheck: true
      }

      {
        copy: """
        Add an image to your page. There are two ways to do this:
          <ul>
            <li>
              Click anywhere on the page, then click on the image icon
              that pops up. You'll be able to pick a file from
              your computer, from a URL, or your Dropbox.
            </li>
            <li>
              Copy an image URL from somewhere else, and paste
              it into your page as text. You'll be prompted to
              convert it to an image. Here's a sample URL you
              can use:
              <input type="text" readonly value="https://s3.amazonaws.com/jotleaf-bno/brandnewotter.jpg" onclick="this.select();">
            </li>
          </ul>
        """
        checker: => page.items.byType('imageitem').length
        triggers: [ [page.items, 'add'] ]
        noUncheck: true
      }

      {
        copy: """
        Style a text or image item individually.
        There are two ways to do this:
        <ul>
          <li>
            Click the gear icon at the top right of the screen and choose 'Item editor' from the dropdown. Then, click an item on your page
            to modify its style individually.
          </li>
          <li>
            Hover your mouse over an item on your page, like the
            text you added, until a gear icon appears next to it.
            Click it to open the Item Editor with that item already
            selected.
          </li>
        </ul>
        """
        checker: =>
          for item in page.items.models
            for attr in ['color', 'bg_color', 'font_size', 'font', 'border_width', 'border_color']
              if item.get(attr)
                return true
          return false
        triggers: [
          [page.items, 'change:color change:bg_color change:font_size change:font change:border_width change:border_color']
        ]
        noUncheck: true
      }

      {
        copy: """
        Add a multimedia embed to your page. To add media from 
        YouTube, Vimeo, SoundCloud, or BandCamp,
        copy a URL from one of those sites, then paste it into your page as
        text. You'll be prompted to convert it to a multimedia embed. Here's a
        sample URL you can use:
        <input type="text" readonly value="http://www.youtube.com/watch?v=epUk3T2Kfno" onclick="this.select();">
        """
        checker: => page.items.byType('embeditem').length
        triggers: [ [page.items, 'add'] ]
        noUncheck: true
      }
    ]

  initialize: (@parentEl, page, surface) =>
    assert page and surface
    ich.tpl_tutorial().appendTo(@$el)
    @$el.appendTo(@parentEl)
    @steps = @makeSteps(page, surface)
    # Include room for the final instructions step:
    @$findOne('.step-total').text(@steps.length + 1)
    @setCurrentStep(0)

    show = (el, val) => el.toggle(val)
    auth = { 
      checker: => JL.AuthState.isAuthenticated()
      events: [ [JL.AuthState, 'change'] ]
    }
    Tendon.Simple(@$findOne('.kill'), show, auth, _.bind(@listenTo, @))

  finalInstructions: =>
    if JL.AuthState.isAuthenticated()
      return """
      All done! Now, publish your page to the world, or
      add members from the Page Options menu. You can
      hide this tutorial with the link below.
      """
    else
      return """
      All done! 
      Now, <a href="#{URLs.registration_register}">sign up</a> and
      add this page to your account, start following people, and
      get jotting!
      """

  _allComplete: =>
    for step in @steps
      if not step.checker()
        return false
    return true

  setCurrentStep: (stepNum) =>
    @stopListening()
    @_currentStep = stepNum
    @$findOne('.step-num').text(stepNum + 1)
    if stepNum == @steps.length
      @$findOne('.checkbox').hide()
      @$findOne('.instructions').html(@finalInstructions())
      @$el.toggleClass('step-completed', @_allComplete())
    else
      @$findOne('.checkbox').show()
      @_activateStep(@steps[stepNum])
    @$el.toggleClass('has-prev', @_hasPrevStep())
    @$el.toggleClass('has-next', @_hasNextStep())

  _hasPrevStep: =>
    return @_currentStep > 0

  _hasNextStep: =>
    # NB there is one extra step, beyond @steps.length,
    # which contains the final instructions
    return @_currentStep < @steps.length

  events: {
    'click .prev-step': '_prevClicked'
    'click .next-step': '_nextClicked'
    'click .close'    : 'close'
    'click .kill'     : 'kill'
  }

  _prevClicked: =>
    if @_hasPrevStep()
      @setCurrentStep(@_currentStep - 1)
    
  _nextClicked: =>
    if @_hasNextStep()
      @setCurrentStep(@_currentStep + 1)

  _activateStep: (step) =>
    @$findOne('.instructions').html(step.copy)
    checkbox = @$findOne('.checkbox')
    doCheckbox = =>
      done = !!step.checker()
      if done and not checkbox.attr('checked')
        @$el.effect('highlight', {color: '#efe'}, 2000)
      checkbox.attr('checked', done)
      @$el.toggleClass('step-completed', done)
    doCheckbox()
    for [object, event] in step.triggers
      @listenTo(object, event, =>
        if checkbox.attr('checked') and step.noUncheck
          return
        doCheckbox()
      )

  close: =>
    remove = _.bind(@remove, @)
    @$el.hide('slide', {direction: 'left'}, remove)
    $('.tutorial-btn').show() # hax


  kill: =>
    if not JL.AuthState.isAuthenticated()
      log "killing tutorial without auth?!"
      @close()
      return
    JL.AuthState.getUser().edit('wants_tutorial', false)
    @close()
