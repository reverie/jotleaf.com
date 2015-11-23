ACCEPTABLE_HOSTS = [
  'localhost:8000'
  'localhost:8001'
  'yourworldoftext.com'
  'www.yourworldoftext.com'
  'dev.yourworldoftext.com:8001'
]

TRANSFER_CHECK = '/mkt/ywot_transfer_check/'
TRANSFER_RESPONSE = '/mkt/ywot_transfer_response/'

clickedYes = (data) ->
  log "clicked yes"
  data.response = 'yes'
  $('.ywot-transfer').hide('slow')
  $.ajax
    type: 'POST'
    url: TRANSFER_RESPONSE
    data: data
    dataType: 'json'
    success: ->
      window.location.href = '/home/'
    error: ->
      $('.ywot-transfer').show().text('Sorry, there was an error transferring your account.')

clickedNo = (data) ->
  log "clicked no"
  data.response = 'no'
  $('.ywot-transfer').hide('slow')
  $.ajax
    type: 'POST'
    url: TRANSFER_RESPONSE
    data: data
    dataType: 'json'

promptTransfer = (data) ->
  log "prompt got", data.username, data.sig

  transferCheck = $.ajax
    type: 'POST'
    url: TRANSFER_CHECK
    data: data
    dataType: 'json'

  transferCheck.done((response) ->
    if not response # didn't get a response -- why?
      return
    if response.transfer_status != null # they've already taken action
      return
    contents = []
    contents.push $('<span>').text("It looks like you're logged in to yourworldoftext.com as '#{data.username}'.")
    contents.push('<br>')
    prompt = $('<span>').text("Would you like to sign in to Jotleaf using the same credentials?")
    y = $('<span class="response">').text('Yes').click((-> clickedYes(data))).appendTo(prompt)
    n = $('<span class="response">').text('No').click((-> clickedNo(data))).appendTo(prompt)
    contents.push(prompt)
    p = $('.ywot-transfer')
    assert p.length
    for c in contents
      p.append(c)
    p.show()
  )
  transferCheck.fail((response) ->
    log "ywot prompt error:", response
  )

receiveYwotMessage = (msg) ->
  log "got postMessage", msg
  originValid = false
  for host in ACCEPTABLE_HOSTS
    url = "http://#{host}"
    if msg.origin == url
      originValid = true
  if not originValid
    log "Invalid message origin:", msg.origin
    return
  d = msg.data
  if not d.username
    log "User not authenticated to YWOT"
    return
  log "User is authenticated to YWOT as", d.username
  promptTransfer(d)

window.addEventListener("message", receiveYwotMessage, false)
