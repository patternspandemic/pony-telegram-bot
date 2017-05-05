"""
Caller for the Telegram Bot API
https://core.telegram.org/bots/api
"""

// TODO: Sub env.out.prints with a logger

use "net/http"
use lgr = "logger"
use "collections"
use "net/ssl"
use "files"

//class val TelegramAPI
actor TelegramAPI
    """
    Lowest level interation with the Telegram API.
    """
    //let _env: Env
    let _logger: lgr.Logger[String] // lgr.StringLogger
    //let _api_key: String
    //let _endpoint: String
    let _client: HTTPClient
    let _url_base: URL

    new create(logger': lgr.Logger[String], url_base': URL, client': HTTPClient iso) =>
        _logger = logger'
        _url_base = url_base'
        _client = consume client'

/*
    new create_old(env: Env, api_key': String, endpoint': (String | None) = None) ? =>
        _env = env
        _api_key = api_key'
        _endpoint = try endpoint' as String
                    else "https://api.telegram.org/" end

        // Construct method call URL.
        let url': String = _endpoint + "bot" + _api_key + "/"
        _url_base = try
            URL.valid(url')
        else 
            env.out.print("Invalid API endpoint: " + url')
            error
        end

        // Get certificate for HTTPS links.
        let sslctx = try
            recover
                SSLContext
                    .>set_client_verify(true)
                    .>set_authority(FilePath(env.root as AmbientAuth, "cacert.pem"))
            end
        end

        _client = try
            // A client to handle our calls to the API.
            HTTPClient(env.root as AmbientAuth, consume sslctx)
        else
            env.out.print("unable to use network")
            error
        end
*/

    fun apply(method: TelegramMethod[TelegramObject] iso) =>
        //_TelegramAPICall(_env, this, _client, _url, consume method)
        _TelegramAPICall(_logger, this, _url_base, consume method)

    be call_client(request: Payload iso, handle_maker: HandlerFactory val) =>
        if request.url is _url_base then
            _logger(lgr.Error) and _logger.log("Bad _method.string() name")
            return
        end

        _client(consume request, handle_maker)


actor _TelegramAPICall
    """
    Do the work of one call to the Telegram API
    """
    //let _env: Env
    let _logger: lgr.Logger[String] //StringLogger
    let _api: TelegramAPI tag
    let _method: TelegramMethod[TelegramObject] iso

    //new create(env: Env, api: TelegramAPI tag, client: HTTPClient tag, url: URL, method: TelegramMethod[TelegramObject] iso) =>
    new create(logger: lgr.Logger[String], api: TelegramAPI tag, url_base: URL, method: TelegramMethod[TelegramObject] iso) =>
        //_env = env
        _logger = logger
        _api = api
        _method = consume method

        // An object that will produce response handlers to a request as needed.
        let handle_maker = recover val APIResponseNotifyFactory.create(this) end

        // Build or get Payload with the method obj
        // match on method.method?
        //   - decide to send get params as URL query string, json
        //   - yada

        let request_url: URL = try
            URL.valid(url_base.string() + _method.string())
        else
            _logger(lgr.Error) and _logger.log("Invalid URL after appending _method.string()")
            url_base
        end

        let request = Payload.request(_method.request_method, request_url)
        request("User-Agent") = "Pony Telegram Bot"
        //request("Content-type") = ... // not needed with query string?

        // Make the call
        // let sent_request: Payload = client(consume request, handle_maker)
        _api.call_client(consume request, handle_maker)

        // Send body data via sent_request if it was a POST

    be cancelled() =>
        _logger(lgr.Info) and _logger.log("-- response cancelled --")

    be have_response(response: Payload val) =>
        if response.status == 0 then
            _logger(lgr.Warn) and _logger.log("Failed")
            return
        end

        _logger(lgr.Info) and _logger.log(
            "Response " +
            response.status.string() + " " +
            response.method)

        // Print all the headers
        for (k, v) in response.headers().pairs() do
            _logger(lgr.Info) and _logger.log(k + ": " + v)
        end

        _logger(lgr.Info) and _logger.log("")

        // Print the body if there is any.  This will fail in Chunked or
        // Stream transfer modes.
        try
            let body = response.body()
            for piece in body.values() do
                //_logger(lgr.Info) and _logger.log(piece)
                _logger(lgr.Info) and _logger.log("Handling body piece")
            end
        end
        // Get response payload
        // error check?
        

    be have_body(data: ByteSeq val) =>
        // Handle body data
        //_logger(lgr.Info) and _logger.log(data)
        _logger(lgr.Info) and _logger.log("Handling body data")

    be finished() =>
        _logger(lgr.Info) and _logger.log("-- end of body --")
        // Set the api on the object
        // fullfill/Reject a promise?
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
