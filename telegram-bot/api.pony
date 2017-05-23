"""
Caller for the Telegram Bot API
https://core.telegram.org/bots/api
"""

use "net/http"
use lgr = "logger"
use "format"
use "collections"
use "net/ssl"
use "files"
use "json"

actor TelegramAPI
  """
  Lowest level interation with the Telegram API.
  """
  let _logger: lgr.Logger[String]
  let _client: HTTPClient
  let _url_base: URL

  new create(
    logger': lgr.Logger[String],
    url_base': URL,
    client': HTTPClient iso)
  =>
    _logger = logger'
    _url_base = url_base'
    _client = consume client'

  be apply(method: GeneralTelegramMethod iso) =>
      _TelegramAPICall(_logger, this, _url_base, consume method)

  be call_client(
    caller: _TelegramAPICall,
    request: Payload iso,
    handle_maker: HandlerFactory val)
  =>
    if request.url is _url_base then
      // In the unlikely occurance that the GeneralTelegramMethod name is empty.
      _logger(lgr.Error) and _logger.log(
        "Error: GeneralTelegramMethod name() is empty.")
      return
    end

    try
      var payload_val: Payload val = _client(consume request, handle_maker)
      caller.with_sent_payload(payload_val) // Get payload_val back to caller
    else
      _logger(lgr.Error) and _logger.log("Error: Call to API client failed.")
    end

  be client_send_body(
    data: (String val | Array[U8 val] val),
    session: HTTPSession tag)
  =>
    _client.send_body(data, session)

  be log(level: lgr.LogLevel, message: String) =>
    _logger(level) and _logger.log(message)

actor _TelegramAPICall
  """
  Do the work of one call to the Telegram API
  """
  let _logger: lgr.Logger[String]
  let _api: TelegramAPI tag
  let _method: GeneralTelegramMethod iso
  var _response: (Payload val | None) = None
  var _body: Array[U8 val] iso

  new create(
    logger: lgr.Logger[String],
    api: TelegramAPI tag,
    url_base: URL,
    method: GeneralTelegramMethod iso)
  =>
    // An object that will produce response handlers to a request as needed.
    let handle_maker = recover val APIResponseNotifyFactory.create(this) end

    // Construct the complete URL
    let request_url: URL =
      try
        URL.valid(url_base.string() + method.name())
      else
        logger(lgr.Error) and logger.log(
          "Error: Invalid URL after appending GeneralTelegramMethod name()")
        url_base
      end

    // Create and setup a request
    let request = Payload.request(method.request_method(), request_url)
    request("User-Agent") = "Pony Telegram Bot" // TODO: Make user-agent setable

    match request.method
    | "Get" =>
      match method.params()
      | let jo: JsonObject val =>
        request("Content-type") = "application/json"
        request.add_chunk(jo.string())
      end
    | "POST" =>
      request("Content-type") = "multipart/form-data"
      // TODO: Support "multipart/form-data" when uploading files.
      // Stream transfer mode setup..
      // Send body data in with_sent_payload..
    end

    // Make the call
    api.call_client(this, consume request, handle_maker)

    // Needed for later behavior calls on this object
    _logger = logger
    _api = api
    _method = consume method
    _body = recover _body.create() end

  be with_sent_payload(request: Payload val) =>
    _logger(lgr.Info) and _logger.log(
      "API call: " + request.method + " " + _method.name())
    try
      let params: JsonObject val = _method.params() as JsonObject val
      _logger(lgr.Info) and _logger.log(" .. Params:")
      _logger(lgr.Info) and _logger.log(params.string("  ", true))
      _logger(lgr.Info) and _logger.log(" .")
    end

    // TODO:
    // If transfer_mode is Stream or Chunked (either marked on payload or this
    // _TelegramAPICall), Send body data via session returned in payload, i.e.
    // for POST requests of the streamed / chunked variety.
    // Make note in log info.
    None

  be cancelled() =>
    // TODO: Consider retrying API method call? What are consequences?
    _logger(lgr.Warn) and _logger.log(
      "Warning: Cancelled API call: " + _method.name())

  be have_response(response: Payload val) =>
    if response.status == 0 then
      _logger(lgr.Warn) and _logger.log("Warning: Failed payload response.")
      return
    end

    _logger(lgr.Info) and _logger.log(
      "API response: " + _method.name() + "\r\n .. " +
      response.status.string() + " " + response.method)

    // Print all the headers
    _logger(lgr.Fine) and _logger.log(" .. Headers:")
    for (k, v) in response.headers().pairs() do
      _logger(lgr.Fine) and _logger.log("    " + k + ": " + v)
    end

    try
      let body_size = response.body_size() as USize
      let data = response.body()
      if body_size > 0 then
        for piece in data.values() do
          match piece
          | let str_data: String val => _body.append(str_data.array())
          | let byte_data: Array[U8 val] val => _body.append(byte_data)
          end
        end
      end
    end

    _response = response

  be have_body(data: ByteSeq val) =>
    // Collect body data
    match data
    | let str_data: String val => _body.append(str_data.array())
    | let byte_data: Array[U8 val] val => _body.append(byte_data)
    end

  be finished() =>
    // Done collecting body data at this point. Proceed with creating a JsonDoc
    // out of the response body, and fullfilling the method's promise with its
    // result as json string.

    // FIXME: Maybe better way than destructive read?
    let body: Array[U8 val] iso = _body = recover _body.create() end
    let body_val: Array[U8 val] val = consume body
    let body_string: String = String.from_array(body_val)
    let json_doc: JsonDoc iso = JsonDoc.create()

    _logger(lgr.Info) and _logger.log(" .. Body:")
    try
      json_doc.parse(body_string)
      _logger(lgr.Info) and _logger.log(json_doc.string("  ", true))
    else
      // TODO: Perhaps should be error?
      _logger(lgr.Warn) and _logger.log(
        "Warning: Could not parse body as json: " + json_doc.parse_report()._2)
        return
    end
    _logger(lgr.Info) and _logger.log(" .")

    // TODO: Handle unsuccessful json response, were 'ok': false
    // i.e. PossiblyUnavailableChatMethod stuff, etc.

    // Create expected result (json string) of the promiser from the api & json in the response, from _method's expect objectifier?
    // perhaps verify json is parsable?
    // fullfill/Reject the _method's promise depending on success of result's creation
    // Callback to TelegramMethod with finished response object?

class APIResponseNotifyFactory is HandlerFactory
  let _main: _TelegramAPICall

  new iso create(main': _TelegramAPICall) =>
    _main = main'

  fun apply(session: HTTPSession): HTTPHandler ref^ =>
    APIResponseNotify.create(_main, session)

class APIResponseNotify is HTTPHandler
  let _main: _TelegramAPICall
  let _session: HTTPSession

  new ref create(main': _TelegramAPICall, session: HTTPSession) =>
    _main = main'
    _session = session

  fun ref apply(response: Payload val) =>
    """
    Start receiving a response.  We get the status and headers.  Body data
    *might* be available.
    """
    _main.have_response(response)

  fun ref chunk(data: ByteSeq val) =>
    """
    Receive additional arbitrary-length response body data.
    """
    _main.have_body(data)

  fun ref finished() =>
    """
    This marks the end of the received body data.  We are done with the
    session.
    """
    _main.finished()
    _session.dispose()

  fun ref cancelled() =>
    _main.cancelled()
