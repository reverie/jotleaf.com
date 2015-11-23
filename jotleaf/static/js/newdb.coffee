# Client-side model cache. Assumes there is one canonical collection
# for the model type.

makeModelCollection = (ModelCls, key) ->
  CollectionClass = ModelCls.CollectionClass or Backbone.Collection
  collection = new CollectionClass([], {key: key})
  if collection.model and collection.model != Backbone.Model
    assert collection.model == ModelCls
  else
    collection.model = ModelCls
  return collection

class ModelDatabase2
  constructor: (@modelCls) ->
    assert @modelCls.collectBy
    @_collections = {}

  getKey: (instance) ->
    if @modelCls.collectBy == '-'
      return ''
    else
      return instance.get(@modelCls.collectBy)

  getCollection: (key) ->
    if not @_collections[key]
      @_collections[key] = makeModelCollection(@modelCls, key)
    return @_collections[key]

  addInstance: (instance) =>
    key = @getKey(instance)
    collection = @getCollection(key)
    @_collections[key].add(instance, {merge: true})

  addObject: (obj) =>
    @addInstance(new @modelCls(obj))

  search: (params) =>
    collections = _.values(@_collections)
    matchLists = (c.where(params) for c in collections)
    return _.union(matchLists...)

  get: (id) =>
    for c in _.values(@_collections)
      if c.get(id)
        return c.get(id)

Database2 = new class
  # Thin wrapper/cache for model-specific databases
  constructor: ->
    @_models = {} # Model shortName -> ModelDatabase

  modelDB: (modelCls) =>
    key = modelCls.shortName
    assert key
    if not @_models[key]
      @_models[key] = new ModelDatabase2(modelCls)
    return @_models[key]
