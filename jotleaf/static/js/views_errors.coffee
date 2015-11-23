class Error404 extends TopView
  documentTitle: 'Page Not Found'

  initialize: ->
    @makeMainWebsiteView('tpl_404')


class Error403 extends TopView
  documentTitle: 'Permission Denied'

  initialize: ->
    @makeMainWebsiteView('tpl_permission_denied', {
      username: @options.username
    })
