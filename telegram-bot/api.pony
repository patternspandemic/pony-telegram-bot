"""
Caller for the Telegram Bot API
https://core.telegram.org/bots/api
"""

use "net/http"
use lgr = "logger"
use "collections"
use "net/ssl"
use "files"

actor TelegramAPI
    """
    Lowest level interation with the Telegram API.
    """
    let _logger: lgr.Logger[String] // lgr.StringLogger
    let _client: HTTPClient
    let _url_base: URL

    new create(logger': lgr.Logger[String], url_base': URL, client': HTTPClient iso) =>
        _logger = logger'
        _url_base = url_base'
        _client = consume client'

    be apply(method: GeneralTelegramMethod iso) =>
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
    let _logger: lgr.Logger[String] //StringLogger
    let _api: TelegramAPI tag
    let _method: GeneralTelegramMethod iso

    new create(logger: lgr.Logger[String], api: TelegramAPI tag, url_base: URL, method: GeneralTelegramMethod iso) =>
        // An object that will produce response handlers to a request as needed.
        let handle_maker = recover val APIResponseNotifyFactory.create(this) end

        // Build or get Payload with the method obj
        // match on method.method?
        //   - decide to send get params as URL query string, json
        //   - yada

        let request_url: URL = try
            URL.valid(url_base.string() + method.name())
        else
            logger(lgr.Error) and logger.log("Invalid URL after appending _method.name()")
            url_base
        end

        let request = Payload.request(method.request_method(), request_url)
        request("User-Agent") = "Pony Telegram Bot"
        //request("Content-type") = ... // not needed with query string?

        // Make the call
        // let sent_request: Payload = client(consume request, handle_maker)
        api.call_client(consume request, handle_maker)

        // Send body data via sent_request if it was a POST

        _logger = logger
        _api = api
        _method = consume method

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
        // Create expected result (TelegramObject) of the promiser from the api & json in the response, from _method's expect objectifier
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
