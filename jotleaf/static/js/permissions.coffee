AFFILIATIONS = 
  # Copied from XMPP
  OWNER: 1
  #ADMIN: 2
  MEMBER: 3
  #OUTCAST: 4
  NONE: 5

PERMISSIONS = 
  OWNER: 1
  #ADMIN: 2
  MEMBER: 3
  PUBLIC: 5

Permissions = new class
  currentUserCanEditPage: (page) =>
    # "Edit" meaning edit settings, i.e. Admin
    user = JL.AuthState.getUser()
    if page.getAffiliation(user) == AFFILIATIONS.OWNER
      return true
    expectedCookie = 'claim-' + page.id
    return Boolean($.cookie(expectedCookie))

  currentUserCanInsertTextItem: (page) =>
    if @currentUserCanEditPage(page)
      return true
    user = JL.AuthState.getUser()
    text_writability = page.get('text_writability')
    affiliation = page.getAffiliation(user)
    return text_writability >= affiliation # >:{

  currentUserIsItemCreator: (item) =>
    user = JL.AuthState.getUser()
    windowId = API.WINDOW_ID
    itemWindowId = item.get('creator_window_id')
    if itemWindowId and (itemWindowId == windowId)
      # Of course, the server-side check is not based on window id
      return true
    userId = user.id
    itemCreatorId = item.get('creator_id')
    if not (itemCreatorId and userId)
      return false
    assert _.isNumber itemCreatorId
    assert _.isNumber userId
    return itemCreatorId == userId

  currentUserCanInsertImageItem: (page) =>
    if @currentUserCanEditPage(page)
      return true
    user = JL.AuthState.getUser()
    image_writability = page.get('image_writability')
    affiliation = page.getAffiliation(user)
    return image_writability >= affiliation

  canEditItem: (item) =>
    # breaks naming convention for great justice
    page = item.page
    if @currentUserCanEditPage(page)
      return true
    userCanInsertItem = true

    if item instanceof TextItem
      userCanInsertItem = @currentUserCanInsertTextItem(page)
    else if item instanceof ImageItem or item instanceof EmbedItem
      userCanInsertItem = @currentUserCanInsertImageItem(page)
    
    if userCanInsertItem and @currentUserIsItemCreator(item)
      return true
