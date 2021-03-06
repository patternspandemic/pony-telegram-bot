"""
Caller for the Telegram Bot API
https://core.telegram.org/bots/api
"""

use "debug"

use "net/http"
use "net/ssl"

use lgr = "logger"
use "format"
use "collections"
use "files"
use "json"

actor TelegramAPI
  """
  Lowest level interation with the Telegram API.
  """
  let _logger: lgr.Logger[String]
  let _url_base: URL
  // let _client: HTTPClient
  // let _sslctx: SSLContext ref // TODO: Temporary
  let _env: Env // TODO: Temporary, needed for ssl context creation

  // For the time being, each _TelegramAPICall needs its own HTTPClient, due to
  // the way multiple request/responses work over a session (can't be paired up)
  new create(
    logger': lgr.Logger[String],
    url_base': URL,
    env: Env)
    // sslctx: SSLContext iso, //val
    // client': HTTPClient iso)
  =>
    _logger = logger'
    _url_base = url_base'
    _env = env
    // _client = consume client'
    // _sslctx = consume sslctx

  be apply(method: GeneralTelegramMethod iso) =>
    Debug.out("-_-_-_-_-> Entered API apply")
    // TODO: Use an improved HTTPClient if/when available,
    // until then create a client for each _TelegramAPICall
    // ...
    // Get certificate for HTTPS links.
    try
      let sslctx =
        try
          recover val
            let caps =
              recover val FileCaps .> set(FileRead) .> set(FileStat) end
            let pem_path = FilePath(
              _env.root as AmbientAuth,
              "cacert.pem",
              caps)?
            SSLContext
              .> set_client_verify(true)
              .> set_authority(pem_path)?
          end
        else
          _logger(lgr.Error) and _logger.log(
            "Error: Unable to set SSLContext.")
          error
        end
      // An HTTP client to supply to the _TelegramAPICall.
      let client: HTTPClient iso = recover
        HTTPClient(_env.root as AmbientAuth, sslctx)
      end
      _TelegramAPICall(_logger, this, _url_base, consume method, consume client)
      Debug.out("Created _TelegramAPICall from API ***************************")
    else
      _logger(lgr.Error) and _logger.log(
        "Error: Unable to use network.")
    end

    // For when TelegramAPI holds the HTTP client
    // _TelegramAPICall(_logger, this, _url_base, consume method)
    

/*  // Client moved to _TelegramAPICall for time being
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
*/

/*  // Client moved to _TelegramAPICall for time being
  be client_send_body(
    data: (String val | Array[U8 val] val),
    session: HTTPSession tag,
    caller: _TelegramAPICall) // TODO: Temporary
  =>
    // _client.send_body(data, session)
    caller.client.send_body(data, session)
*/

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
  var client: (HTTPClient | None) // TODO: Temporary

  new create(
    logger: lgr.Logger[String],
    api: TelegramAPI tag,
    url_base: URL,
    method: GeneralTelegramMethod iso,
    client': HTTPClient iso) // TODO: Temporary
  =>
    // An object that will produce response handlers to a request as needed.
    let handle_maker = recover val APIResponseNotifyFactory.create(this) end

    // Construct the complete URL
    let request_url: URL =
      try
        URL.valid(url_base.string() + method.name())?
      else
        logger(lgr.Error) and logger.log(
          "Error: Invalid URL after appending GeneralTelegramMethod name()")
        url_base
      end

    // Create and setup a request
    let request = Payload.request(method.request_method(), request_url)
    request("User-Agent") = "Pony Telegram Bot" // TODO: Make user-agent setable

    match request.method
    | "GET" =>
      match method.params()
      | let jo: JsonObject val =>
        request("Content-type") = "application/json"
        request.add_chunk(jo.string())
      end
    | "POST" =>
      request("Content-type") = "multipart/form-data"
      // TODO: Support "multipart/form-data" when uploading files.
      // Stream transfer mode setup..
      // Mark the data for Send body data in with_sent_payload..
      // Use session from this caller's client if still doing things that way
    end

    // Needed for later behavior calls on this object
    _logger = logger
    _api = api
    _method = consume method
    _body = recover _body.create() end

    // Make the call
    // api.call_client(this, consume request, handle_maker)
    // TODO: Temporary local client calling ...
    if request.url is url_base then
      // In the unlikely occurance that the GeneralTelegramMethod name is empty.
      logger(lgr.Error) and logger.log(
        "Error: GeneralTelegramMethod name() is empty.")
      // TODO: Temporary
      client = consume client'
      return
    end
    try
      var payload_val: Payload val = client'(consume request, handle_maker)?
      with_sent_payload(payload_val)
    else
      logger(lgr.Error) and logger.log("Error: Call to API client failed.")
    end

    // TODO: Temporary
    client = consume client'

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
    """"""
    // TODO: Consider retrying API method call? What are consequences?
    _logger(lgr.Warn) and _logger.log(
      "Warning: Cancelled API call: " + _method.name())
    _method.reject()

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
      let data = response.body()?
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

    // FIXME: Might there be a better way than a destructive read?
    let body: Array[U8 val] iso = _body = recover _body.create() end
    let body_val: Array[U8 val] val = consume body
    let body_string: String = String.from_array(body_val)
    let json_doc: JsonDoc ref = JsonDoc.create()

    _logger(lgr.Info) and _logger.log(" .. Body:")
    try
      json_doc.parse(body_string)?
      _logger(lgr.Info) and _logger.log(json_doc.string("  ", true))
    else
      // TODO: Perhaps should be error?
      _logger(lgr.Warn) and _logger.log(
        "Warning: Could not parse body as json: " + json_doc.parse_report()._2)
      _method.reject()
      return
    end

    var ok: Bool = false
    var description: Optional[String] = None
    var result: Optional[String] = None
    var error_code: Optional[I64] = None
    var error_params: Optional[String] = None

    try
      match json_doc.data
      | let jo: JsonObject =>
        // assign to above vars based on 'ok' bool
        ok = jo.data("ok")? as Bool
        try description = jo.data("description")? as String end
        if ok then
          // TODO: Match on JsonTypes, for instance GetChatMembersCount return an integer.
          // TODO: Match on JsonArray as well, for i.e. updates, other methods
          // returning array of ...
          result = (jo.data("result")? as JsonObject).string()
          let method_response: TelegramAPIMethodResponse val =
            TelegramAPIMethodResponse(_api, result as String)
          _method.fulfill(method_response)
          _logger(lgr.Fine) and _logger.log(" .. Fulfilled")
        else
          // TODO: Handle unavailable chats, flood control, etc.
          //   - Resend when chat migrated
          //   - Ask api to wait to process when flood control occurs
          error_code = jo.data("error_code")? as I64
          try error_params = (jo.data("parameters")? as JsonObject).string() end
          // ... reject for now ...
          // ... but maybe fulfill with TelegramAPIMethodResponse w/error info
          _method.reject()
          _logger(lgr.Fine) and _logger.log(" .. Rejected TEMPORARILY")
          // ...
        end
      else
        _logger(lgr.Warn) and _logger.log(
          "Warning: Telegram response was not matched.")
        _method.reject()
        _logger(lgr.Fine) and _logger.log(" .. Rejected")
        //return
      end
    else
      _logger(lgr.Error) and _logger.log(
        "Error: Telegram JsonObject response has changed.")
      _method.reject()
      _logger(lgr.Fine) and _logger.log(" .. Rejected")
      //return
    then
      _logger(lgr.Info) and _logger.log(" .")
    end
    // TODO: Add error 'parameters': information to TelegramAPIMethodResponse
    
    _response = None
    client = None

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
    _session.dispose() // Needed?
