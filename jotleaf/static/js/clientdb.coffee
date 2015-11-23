NotImplemented = new Error("NotImplemented")

# TODO: split up get- and filter-type views, and use Collections
# for the latter? Or: Have a single collection for each type. no more id-based views, just use Collection.get

class DBView
  # Represents one "view" on the set of models we've seen so far.
  # This is kind of like a database index, but it also knows how
  # to fetch models from the server based on the key. Each DBView
  # is one way of getting/filter items: e.g. by id, by username,
  # or by a foreign key value. Supports 'get', which asserts
  # that there is exactly one value, and 'filter', which can
  # return multiple values.

  constructor: (@modelCls, @modelDB) ->
    @_instances = {} # maps key -> instanceList

  getAll: =>
    return _.union(_.values(@_instances))

  _mergeKey: (key) =>
    # turn `key` into a canonical form
    return key

  _rawKeyFromModel: (instance) =>
    # get this view's key from an instance
    throw NotImplemented

  _keyFromModel: (instance) =>
    key = @_rawKeyFromModel(instance)
    return @_mergeKey(key)

  _getValue: (key) =>
    if not @_instances[key]
      @_instances[key] = []
    value = @_instances[key]
    assert _.isArray(value)
    return value

  addInstance: (instance) =>
    # The ModelDatabase is responsible for ensuring that addInstance is
    # called exactly once for each model that the client is tracking.
    key = @_keyFromModel(instance)
    assert (instance not in @_getValue(key))
    @_getValue(key).push(instance)

  softGet: (key) =>
    key = @_mergeKey(key)
    matches = @_getValue(key)
    if not matches.length
      return
    if (matches.length > 1)
      throw new Error("get-method encountered more than one matching model")
    return matches[0]

  get: (key) =>
    instance = @softGet(key)
    if instance
      return instance
    else
      throw new Error("Instance not found", @, "via", key)

  getList: (keyList) =>
    return _.map(keyList, @get)

  _keyToDeferredInstance: (key) =>
    throw NotImplemented

  fetch: (key) =>
    # Fetch the model from the server if it isn't present. Returns
    # a deferred. Should not call addInstance directly, but rather
    # notify the ModelDatabase about the new item so that it can 
    # add it to all the other views as well.
    #
    # If you override this, be careful to include 
    # the @modelDB.addInstance bit.
    instance = @softGet(key)
    if instance
      log "fetch shortcutting"
      return $.when(instance)
    iDfd = @_keyToDeferredInstance(key)
    return $.Deferred((dfd) =>
      # Can we use $.Deferred.pipe here? I think we can't
      # because we want to guarantee that addInstance happens
      # before anything else.
      iDfd.done((i) =>
        @modelDB.addInstance(i)
        dfd.resolve(i))
      iDfd.fail((err) =>
        dfd.reject(err)))

  fetchList: (keyList) =>
    return $.when.apply($, _.map(keyList, @fetch))

  # `Filter`-type methods, used by DBViews that expect more than
  # one result.

  _keyToDeferredFilter: (key) =>
    NotImplemented = new Error("NotImplemented")

  filterFetch: (key) =>
    # Fetch matching models from the server if they aren't
    # present. Returns a deferred Array of models.  a
    # deferred. Similar caveats to @fetch above. Always
    # results in a query; otherwise, use filterFetchOnce.
    filterDfd = @_keyToDeferredFilter(key)
    return $.Deferred((dfd) =>
      filterDfd.done((instanceList) =>
        for i in instanceList
          @modelDB.addInstance(i)
        dfd.resolve(instanceList))
      filterDfd.fail((err) =>
        dfd.reject(err)))

  # TODO: filterFetchOnce, to ensure that we fetch at most
  # once, with the subsequent updates presumably being handled
  # by Pusher. This is necessary because, with a plain
  # filterFetch, we have no way of knowing whether the query
  # has been done before.

  filter: (key) =>
    return @_getValue(key)

  removeInstance: (instance) =>
    key = @_keyFromModel(instance)

    # hack
    # removing assert, for not-done-syncing Follow objects...
    #assert (instance in @_getValue(key))

    array = @_getValue(key)
    index = array.indexOf(instance)
    array.splice(index, 1)

class IDView extends DBView
  _keyFromModel: (instance) =>
    return instance.id

  _keyToDeferredInstance: (id) =>
    i = new @modelCls({id: id})
    # Backbone.Model.fetch's deferred yields the XHR, not the model
    return i.fetch().promise().pipe(=> i)

class ModelDatabase
  constructor: (@modelCls) ->
    @_views = {}
    @addView('id', IDView) # This is the base index that we count on to exist

  addView: (name, viewCls) =>
    assert not @_views[name]
    view = new viewCls(@modelCls, @)
    @_views[name] = view
    if name != 'id' # DRY name w/above?
      # Add all known items to the index:
      for instance in @_views['id'].getAll()
        view.addInstance(instance)

  getBy: (viewName, key) =>
    return @_views[viewName].get(key)

  getListBy: (viewName, keyList) =>
    return @_views[viewName].getList(keyList)

  softGetBy: (viewName, key) =>
    return @_views[viewName].softGet(key)

  fetchBy: (viewName, key) =>
    return @_views[viewName].fetch(key)

  fetchListBy: (viewName, keyList) =>
    return @_views[viewName].fetchList(keyList)

  get: (id) =>
    return @getBy('id', id)

  getList: (ids) =>
    return @getListBy('id', ids)

  softGet: (id) =>
    return @softGetBy('id', id)

  fetch: (id) =>
    return @fetchBy('id', id)

  fetchList: (idList) =>
    return @fetchListBy('id', idList)

  addInstance: (instance) =>
    if @softGet(instance.id)
      # We already know about it
      return
    for _, view of @_views
      view.addInstance(instance)

  filterBy: (viewName, key) =>
    return @_views[viewName].filter(key)

  filterFetchBy: (viewName, key) =>
    assert key
    return @_views[viewName].filterFetch(key)

  delete: (instance) =>
    for _, view of @_views
      view.removeInstance(instance)
    instance.destroy()

Database = new class
  # Thin wrapper/cache for model-specific databases
  constructor: ->
    @_models = {} # Model shortName -> ModelDatabase

  modelDB: (modelCls) =>
    key = modelCls.shortName
    assert key
    if not @_models[key]
      @_models[key] = new ModelDatabase(modelCls)
    return @_models[key]

# Add a 'username' view to Users
class UsernameView extends DBView
  _rawKeyFromModel: (instance) =>
    return instance.get('username')

  _mergeKey: (username) =>
    return username.toLowerCase()

  _keyToDeferredInstance: (username) =>
    xhr = API.search('user', [['username', 'iexact', username]])
    return $.Deferred((dfd) =>
      xhr.done((result) =>
        log "UsernameView fetch got", result, "for", username
        if result.length == 0
          dfd.reject("User not found")
        else
          assert(result.length == 1)
          dfd.resolve(new User(result[0])))
      xhr.fail( =>
        log "UsernameView failed"
        dfd.reject("Error finding user. Please refresh and try again.")))

Database.modelDB(User).addView('username', UsernameView)

# A filter-type View to filter by page_id
class PageIDView extends DBView
  _rawKeyFromModel: (instance) =>
    return instance.get('page_id')

  _keyToDeferredFilter: (pageId) =>
    xhr = API.search(@modelCls.shortName, 
      [['page_id', 'exact', pageId]]
    )
    return $.Deferred((dfd) =>
      xhr.done((result) =>
        log "PageIDView fetch got", result, "for", pageId
        instances = (new @modelCls(dct) for dct in result)
        dfd.resolve(instances)
      )
      xhr.fail( =>
        log "Error in PageIDView"
        dfd.reject("Error fetching matches for #{pageId}")
      )
    )

Database.modelDB(Membership).addView('page_id', PageIDView)
