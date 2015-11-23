# views_leaf.coffee is for leaf-viewing TopViews

class OuterPageView extends TopView
  @bodyClass: 'page-view'
  # Wraps a whole page viewer, including both the canvas (PageView)
  # and control elements (misc)
  className: 'page'

  documentTitle: ->
    @page?.get('title') or 'Jotleaf'

  initialize: =>
    @$el.addClass('loading')
    @nav = ich.tpl_navbar(@commonContext()).appendTo(@$el)

    if @options.pageId
      data = {page_id: @options.pageId}
    else
      assert @options.username and @options.pageIdentifier
      data = {
        username: @options.username
        page_identifier: @options.pageIdentifier
      }

    pageGet = API.xhrMethod('get-page', data)
    pageGet.always( =>
      @$el.removeClass('loading')
    )
    pageGet.fail((response) =>
      router.do500()
    )
    pageGet.done((response) =>
      if response.success
        page = new Page(response.data.page, {parse: true})
        appendExtraPageAttributes(page, response.data)
        @_gotPage(page)
      else if response.status_code == 403
        router.do403(@options.username)
      else if response.status_code == 404
        router.do404()
      else
        router.do500()
    )

  unbind: =>
    @page?.unsubscribe()
    if @_presenceChannel
      API.unsubscribePresence(@page.id, @receivePresence)

    @rview?.unbind()
    @_pageView = null
    @minimap = null
    @pageOptionsView = null
    @itemEditor = null



  wantsToHandle: (options) =>
    if not @page
      # We don't even have our page yet. Just quit and 
      # let the next one render stuff.
      return false
    if options.pageId
      return options.pageId == @options.pageId
    else
      return (options.username == @options.username and
        options.pageIdentifier == @options.pageIdentifier)

  handleNewOptions: (options) =>
    assert @wantsToHandle(options)
    # Let the page view scroll to new location
    @_pageView.handleNewLocation(options)

  _gotPage: (page) =>
    @page = page
    @listenTo(page, 'change:title', =>
      @trigger('change-title', page.get('title'))
    )
    @trigger('change-title', page.get('title'))
    page.subscribe()
    @_presenceChannel = API.subscribePresence(page.id, @receivePresence)
    mixpanel.track("Jotleaf Page view", {page_id: page.id})
    pageView = @_pageView = new PageView({
      model: page
      parent: @$el
      parentView: @
      fullscreen: @options.fullscreen
      initX: @options.initX or 0
      initY: @options.initY or 0
      initId: @options.initId
    })

    @addSubView(pageView)

    pageView.render()

    minimapEl = ich.tpl_minimap()
    minimapEl.appendTo(@$el)

    @minimap = new MiniMapView({
      el: minimapEl
      pageView: pageView
    })

    @addSubView(@minimap)

    canEditPage = Permissions.currentUserCanEditPage(page)

    # Re-render navbar
    @nav.remove()
    ctx = @commonContext()
    ctx.showPageOptions = canEditPage
    @nav = ich.tpl_navbar(ctx).appendTo(@$el)
    @_renderInfobar()
    @listenTo(page, 'change:title', @_renderInfobar)

    if canEditPage
      # Set up dropdown menu
      dropdown = @$findOne('.page-options-dropdown')
      dropdownToggle = dropdown.findOne('.dropdown-toggle')
      dropdownToggle.dropdown()
      toggleMenu = -> dropdownToggle.dropdown('toggle')
      showLoginToClaim = canEditPage and not JL.AuthState.isAuthenticated()
      @rview = rivets.bind(dropdown, {
        # rivets hax
        canEditPage: {val: -> canEditPage}
        showLoginToClaim: {val: -> showLoginToClaim}

      })
      @pageOptionsView = new PageOptionsView({
        model: page
        parent: @$el
      })
      @addSubView(@pageOptionsView)
      
      itemEditorEl = ich.tpl_item_editor()
      itemEditorEl.appendTo(@$el)

      @itemEditor = new ItemEditor({
        el: itemEditorEl
        pageView: pageView
        parent: @$el
      })
      @addSubView(@itemEditor)
      
      pageOptionsBtn = dropdown.findOne('.options-btn')
      itemOptionBtn = dropdown.findOne('.item-options-btn')
      tutorialBtn = dropdown.findOne('.tutorial-btn')
      
      @listenTo(pageOptionsBtn, 'click', =>
        @toggleShowingOptions()
        toggleMenu()
      )
      @listenTo(itemOptionBtn, 'click', =>
        @toggleShowingTextOptions()
        toggleMenu()
      )
      @listenTo(tutorialBtn, 'click', =>
        @addSubView(new TutorialView(@$el, page, pageView.surface))
        tutorialBtn.hide()
      )

      # Show the options panel right away if the page is new
      createdAt = new Date(page.get('created_at'))
      msAgo = new Date().getTime() - createdAt.getTime()
      createdInLastMinute = (msAgo/1000) < 60
      if createdInLastMinute and not page.items.length
        @toggleShowingOptions()

      # Handle tutorial
      if JL.AuthState.getUser().get('wants_tutorial') or not JL.AuthState.isAuthenticated()
        @addSubView(new TutorialView(@$el, page, pageView.surface))
      else
        dropdown.findOne('.tutorial-btn').show()

    # To prevent canvas dragging events from being 
    # blocked by the minimap, dropdown, and menus
    @listenTo(@_pageView.$el, 'start-drag', => 
      @nav.addClass('ignore-mouse')
      @minimap.$el.addClass('ignore-mouse')
      @pageOptionsView?.$el.addClass('ignore-mouse')
      @itemEditor?.$el.addClass('ignore-mouse')
      @_numOnline?.addClass('ignore-mouse')
    )
    @listenTo(@_pageView.$el, 'stop-drag', => 
      @nav.removeClass('ignore-mouse')
      @minimap.$el.removeClass('ignore-mouse')
      @pageOptionsView?.$el.removeClass('ignore-mouse')
      @itemEditor?.$el.removeClass('ignore-mouse')
      @_numOnline?.removeClass('ignore-mouse')
    )

  _renderInfobar: =>
    page = @page
    infobar = @nav.findOne('.infobar').empty()
    title = $.trim(page.get('title')) or 'A Jotleaf Page'
    owner_username = page.owner.get('username')
    if owner_username
      title += ', by '
      infobar.text(title)
      userLink = $('<a>').text(owner_username)
      userLink.attr('href', "/#{owner_username}/") # todo: reverse
      infobar.append(userLink)
    else
      infobar.text(title)

  receivePresence: (type, data) =>
    @_numOnline ||= $('<div class="num-online">').appendTo(@$el)
    numOnline = @_presenceChannel.members.count
    @_numOnline.text("#{numOnline} online")
    @_numOnline.toggle(numOnline > 1)

  toggleShowingOptions: =>
    @itemEditor.hide()
    @pageOptionsView.toggle()
    return false

  toggleShowingTextOptions: =>
    @pageOptionsView.hide()
    @itemEditor.toggle()
    return false
