GlobalError = () ->
  log "API error", arguments
  throw new Error "API Error"

API = new class
  constructor: ->
    @pusher = new Pusher JL_CONFIG.PUSHER_KEY
    @_channels = {} # channel-id -> Pusher.Channel object
    @WINDOW_ID = String(parseInt(Math.random() * Math.pow(2, 32), 10))

  subscribePage: (pageId, receiver) =>
    channelName = "private-page-#{pageId}"
    channel = @_subscribeToChannel(channelName)
    boundEvent = [
      'item-add',
      'item-update',
      'item-delete',
      'page-update',
      'page-delete',
      'multi-event'
    ]
    _.each boundEvent, (eventName) =>
      channel.bind eventName, (data) ->
        log "calling receiver for #{eventName}"
        receiver(eventName, data)
    return channel

  _subscribeToChannel: (channelName) =>
    if @_channels[channelName]
      return @_channels[channelName]
    channel = @_channels[channelName] = @pusher.subscribe(channelName)

  _unsubscribeFromChannel: (channelName, receiver) =>
    channel = @_channels[channelName]
    if channel
      channel.unbind(channelName, receiver)
      @pusher.unsubscribe(channelName)
      channel = null
      delete @_channels[channelName]

  subscribePresence: (pageId, receiver) =>
    channelName = "presence-page-#{pageId}"
    channel = @_subscribeToChannel(channelName)
    channel.bind_all(receiver)
    return channel

  subscribeUser: (userId, receiver) =>
    channelName = "private-user-#{userId}"
    channel = @_subscribeToChannel(channelName)
    boundEvent = [
      'nf-follow',
      'nf-page',
      'nf-text',
      'nf-image',
      'nf-embed',
      'nf-membership',
      'nf-delete'
    ]

    _.each(boundEvent, (eventName) =>
      channel.bind(eventName, (data) ->
        log "calling receiver for #{eventName}"
        receiver(eventName, data)
      )
    )
    return channel

  unsubscribeUser: (userId, receiver) =>
    channelName = "private-user-#{userId}"
    @_unsubscribeFromChannel(channelName, receiver)

  unsubscribePage: (pageId, receiver) =>
    channelName = "private-page-#{pageId}"
    @_unsubscribeFromChannel(channelName, receiver)

  unsubscribePresence: (pageId, receiver) =>
    channelName = "presence-page-#{pageId}"
    @_unsubscribeFromChannel(channelName, receiver)
    
  socketID: =>
    return @pusher?.connection?.socket_id

  getClientData: =>
    window_id: @WINDOW_ID
    socket_id: @socketID()

  search: (modelName, searchParams) =>
    # TODO: DRY with JotLeafModel.sync
    data = JSON.stringify({
      search_params: searchParams
      meta: API.getClientData()
    })
    return $.ajax
      type: 'POST'
      url: "/api/v2/#{modelName}/search/"
      contentType: 'application/json'
      data: data

  instanceMethod: (instance, methodName) =>
    # TODO: DRY api stuff
    url = instance.url() + methodName + '/'
    data = JSON.stringify({
      meta: API.getClientData()
    })
    return $.ajax
      type: 'POST'
      url: url
      contentType: 'application/json'
      data: data

  xhrMethod: (methodName, data=null) =>
    # top-level API methods, i.e. /api/v2/<methodName>/
    # might conflict with model names... we should do
    # something about that
    ##data.meta = @getClientData()
    $.ajax({
      type: 'POST'
      url: "/xhr/#{methodName}/"
      data: data
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8'
      dataType: 'json'
    })

#Pusher.log = (msg) => log "PUSHER:", msg

