class JotLeafModel extends Backbone.Model
  initialize: ->
    @on 'edit', @_autosave
    @_currentSync = null

  urlRoot: =>
    return "/api/v2/#{@constructor.shortName}/"

  url: =>
    # Modified version of Backbone's url() that simply adds a slash at the end
    if _.isString(@urlRoot)
      base = @urlRoot
    else
      base = @urlRoot()
    if @isNew()
      return base
    return base + encodeURIComponent(@id) + '/'

  sync: (method, model, options) =>
    # extend Backbone.sync such that:
    # always add our 'meta' channel of data, and pass
    # model data under the 'model' key.
    if method != 'read'
      options.contentType = 'application/json'
      data = {
        meta: API.getClientData()
      }
      if method in ['create', 'update']
        data.model = model.toJSON()
      options.data = JSON.stringify(data)

      syncAndRemove = =>
        @_currentSync = Backbone.sync(method, model, options).then(=> 
          @_currentSync = null
        )

      # Queue up successive syncs if a request is in progress  
      if @_currentSync
        @_currentSync.always(syncAndRemove)
      else
        syncAndRemove()
    else
      Backbone.sync(method, model, options)

  getN: (attrs...) ->
    # helper for getting multiple attributes at once,
    # intended for use with destructuring assignment
    return (@attributes[a] for a in attrs)

  # TODO: update Backbone and get rid of this
  once: (events, callback) =>
    # Bind callback to events such that it is triggered
    # at most once, with the binding being removed after
    # the first call.
    wrapped = =>
      @off(events, wrapped)
      callback.apply(@, arguments)
    @on(events, wrapped)
    return wrapped

  edit: (attribute, value, options) =>
    # We distinguish 'edit' and 'set' events. An 'edit' is when
    # the current client has modified a value of the model. A
    # 'set' is any time the attribute on the model. Every edit
    # is a set, but not every set is an edit. This allows us
    # to bind autosave to the 'edit' event, but not worry about
    # it firing when we e.g. receive updates from the server,
    # which would result in a generic 'set' event. (Those updates
    # can't be {silent: true}, because then the UI wouldn't update.)
    log 'editing', attribute, value
    if value == @get(attribute)
      log 'edit skipping out'
      return
    @trigger('edit')
    @trigger("edit:#{attribute}", value)
    @set(attribute, value, options)

  _autosave: =>
    autoSaveId = @cid
    $.doTimeout autoSaveId, 300, =>
      log "Autosaving object", @
      @save()
      return false

  destroy: (options) =>
    @_destroyed = true
    
    # Copied over from backbone implementation 0.9.10
    # Backbone thinks that if a model doesn't
    # have an id yet, that it is new and therefore 
    # a destroy call on it shouldn't persist to the server
    # This is good and all, but it doesn't take into account
    # if there is a save request in progress.  Thus creating
    # and destroying in quick succession doesn't persist the
    # destroy to the server. 
    options = if options then _.clone(options) else {}
    model = @
    success = options.success

    destroy = ->
      model.trigger('destroy', model, model.collection, options)
    
    options.success = (model, resp, options) ->
      if options.wait || model.isNew()
       destroy()
      if success 
        success(model, resp, options)

    # Modified here
    if not @_currentSync and @isNew()
      options.success(@, null, options)
      return false

    xhr = @sync('delete', @, options)
    if not options.wait 
      destroy()
    return xhr

  save: =>
    if @_destroyed
      log "canceling save -- destroyed"
      return

    # Don't duplicate items if save is called twice in succession
    if not @id
      if @_saving
        @once('change:id', => @save())
        return
      else
        @_saving = true
    super

class User extends JotLeafModel
  @shortName: 'user'
  @collectBy: '-'

  profileUrl: =>
    assert @id
    return '/' + @get('username') + '/'

class Membership extends JotLeafModel
  @shortName: 'membership'

class Memberships extends Backbone.Collection
  model: Membership

class ItemSet extends Backbone.Collection
  byType: (type) =>
    # TODO: DRY
    assert type in ['textitem', 'imageitem', 'embeditem']
    return @filter((m) -> m.constructor.shortName == type)

# Assigns values on 'page' that come from
# xhr-get-page, i.e. the items, owner, and
# membership attributes.
appendExtraPageAttributes = (page, response) ->
  # Parse and assign Owner
  page.owner = new User(response.owner)

  # Parse and assign Items
  itemTypes = [
    # attribute,  class
    ['textitems', TextItem]
    ['embeditems', EmbedItem]
    ['imageitems', ImageItem]
  ]
  items = []
  for [attrName, Cls] in itemTypes
    itemList = response[attrName]
    for item in itemList
      # TODO: combine with receiveUpdate
      items.push(new Cls(item))
  page.items =  new ItemSet(items)
  for item in items
    item.page = page

  # Parse and assign memberships
  # TODO: don't assign this here, but stick them in clientDB instead,
  # and check there in getAffiliations too
  page.memberships = new Memberships(response.memberships)

class Page extends JotLeafModel
  @shortName: 'page'

  toJSON: =>
    data = _.clone @attributes
    delete data.type
    delete data.items
    delete data.owner
    return data

  subscribe: =>
    if @id
      # TODO: unsubscribe at some point
      log "Page trying to subscribe"
      API.subscribePage(@id, @receiveUpdate)
    else
      log "Page waiting to subscribe"
      @once('change:id', =>
        API.subscribePage(@id, @receiveUpdate)
      )

  unsubscribe: =>
    log "Page trying to unsubscribe"
    API.unsubscribePage(@id, @receiveUpdate)

  receiveUpdate: (type, data) =>
    log "Page.receiveUpdate called with", type, data
    if type is 'multi-event'
      for singleEvent in data
        @receiveUpdate(singleEvent.type, singleEvent.data)
    else
      existing = @items.get(data.id)
      if type is 'item-update'
        if not existing
          return
        modelData = data.model_data
        existing.set(modelData)
        existing.view.updateView()
        @trigger('external-item-updated', existing, data.creator_username, data.creator_identifier)
      else if type is 'item-add'
        if existing
          # maybe we created it
          return
        Cls = {
          embed: EmbedItem
          text: TextItem
          image: ImageItem
        }[data.type]
        modelData = data.model_data
        item = new Cls(modelData)
        item.page = @
        @items.add(item)
        @trigger('external-item-added',item, data.creator_username, data.creator_identifier)
      else if type is 'item-delete'
        if not existing
          # maybe we deleted it
          return
        existing.view.delete(false)
      else if type is 'page-update'
        @set(data)
      else if type is 'page-delete'
        log "PAGE DELETED"
        @trigger 'page-deleted'
      else
        throw new Error "Unknown update type"

  getAffiliation: (user) =>
    # err, should this take into account the claim cookies? see Permissions.currentUserCanEditPage(). kind of confusing.
    if not user
      return AFFILIATIONS.NONE
    if not @owner # for temporary pages
      return AFFILIATIONS.NONE
    ownerId = parseInt(@owner.id)
    if user instanceof User
      userId = parseInt user.id
    else # it's a user ID
      assert _.isNumber(user)
      userId = user
    
    if ownerId == userId
      return AFFILIATIONS.OWNER
    
    # Check if member
    memberships = @memberships
    foundUser = memberships.where({user_id: userId})
    if foundUser.length
      return AFFILIATIONS.MEMBER
    else
      return AFFILIATIONS.NONE

  getAbsoluteUrl: =>
    # TODO: make absolute, not relative
    owner = @owner
    if owner?.id 
      pageIdentifier = @get('short_url') or @id
      username = owner.get('username')
      assert username
      path = "/#{username}/#{pageIdentifier}/"
    else
      path = "/page/#{@id}/"
    return qualifyURL(path)

class Item extends JotLeafModel
  toJSON: =>
    data = _.clone(@attributes)
    data.page_id = @page.id
    data.socket_id = API.socketID()
    return data

  getCreatorAffiliation: =>
    return @page.getAffiliation(@get('creator_id'))

  getAbsoluteUrl: =>
    if not @id
      return "No URL yet — save this item first."
    return @page.getAbsoluteUrl() + "item-#{@id}/"

  getPoint: =>
    return [@get('x'), @get('y')]

class TextItem extends Item
  @shortName: 'textitem'

class ImageItem extends Item
  @shortName: 'imageitem'

class EmbedItem extends Item
  @shortName: 'embeditem'

# A collection of all the users that a certain user follows
# i.e., there is one of these per-user.
class UserFollows extends Backbone.Collection
  model: Follow

  initialize: (models, @options) =>
    # @options.key is the user_id of all instances in this collection
    assert @options.key

  checkFollows: (user) =>
    return Boolean(@where({target_id: user.id}).length)

  setFollows: (user, value) =>
    assert @options.key
    target_id = user.id
    value = Boolean(value)
    
    # Try shortcutting
    if value == @checkFollows(user)
      return

    if value
      f = new Follow({
        user_id: @options.key
        target_id: target_id
      })
      f.save()
      mixpanel.track("Follow")
      @add(f)
    else
      for model in @where({target_id: target_id})
        model.destroy()

class Follow extends JotLeafModel
  @shortName: 'follow'
  @collectBy: 'user_id'
  @CollectionClass: UserFollows

class NewsFeedListing extends Backbone.Model
  initialize: (listing) =>
    @id = @_generatePseudoId(listing)

  _generatePseudoId: (listing) =>
    switch listing.type
      when 'text','image','embed','page'
        id = "#{listing.type}-#{listing.data.id}"
      when 'membership'
        id = "#{listing.type}-#{listing.data.page_id}"
      when 'follow'
        id = "#{listing.type}-#{listing.data.user_id}"
      else
        id = "#{listing.type}-#{listing.data.id}"

class NewsFeed extends Backbone.Collection
  model: NewsFeedListing

  comparator: (l1, l2) =>
    t1 = l1.get('timestamp')
    t2 = l2.get('timestamp')
    if t1 == t2
      return 0
    else if t1 > t2
      return -1
    else 
      return 1

  subscribe: =>
    assert JL.AuthState.isAuthenticated()
    userId = JL.AuthState.getUserId()
    API.subscribeUser(userId, @receiveUpdate)

  unsubscribe: =>
    userId = JL.AuthState.getUserId()
    log "Newsfeed unsubscribing from user-#{userId}"
    API.unsubscribeUser(userId, @receiveUpdate)

  receiveUpdate: (eventName, listing) =>
    newsFeedListing = new NewsFeedListing(listing)
    if eventName is 'nf-delete'
      @remove(newsFeedListing)
    else
      @update(newsFeedListing, { prepend: true, remove: false })

class RejectedFollowSuggestion extends JotLeafModel
  @shortName: 'rejectedfollowsuggestion'
