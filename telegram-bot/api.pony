"""
Caller for the Telegram Bot API
https://core.telegram.org/bots/api
"""

// TODO: Sub env.out.prints with a logger

use "collections"
use "net/http"
use "net/ssl"
use "files"

class TelegramAPI
    """
    Lowest level interation with the Telegram API.
    """
    let _env: Env
    let _api_key: String
    let _endpoint: String
    let _url: URL
    let _client: HTTPClient

    new create(env: Env, api_key': String, endpoint': (String | None) = None) ? =>
        _env = env
        _api_key = api_key'
        _endpoint = try endpoint' as String
                    else "https://api.telegram.org/" end

        // Construct method call URL.
        let url': String = _endpoint + "bot" + _api_key + "/"
        _url = try URL.valid(url')
               else env.out.print("Invalid API endpoint: " + url') end

        // Get certificate for HTTPS links.
        let sslctx = try
            recover
                SSLContext
                    .>set_client_verify(true)
                    .>set_authority(FilePath(env.root as AmbientAuth, "cacert.pem"))
            end
        end

        try
            // A client to handle our calls to the API.
            _client = HTTPClient(env.root as AmbientAuth, consume sslctx)
        else
            env.out.print("unable to use network")
            error
        end

    fun apply(method: TelegramMethod) =>
        _TelegramAPICall(_env, this, _client, _url, method)


actor _TelegramAPICall
    """
    Do the work of one call to the Telegram API
    """
    let _env: Env
    let _api: TelegramAPI
    let _method: TelegramMethod

    new create(env: Env, api: TelegramAPI, client: HTTPClient, url: URL, method: TelegramMethod) =>
        _env = env
        _api = api
        _method = method

        // An object that will produce response handlers to a request as needed.
        let handle_maker = recover val APIResponseNotifyFactory.create(this) end

        // Build or get Payload with the method obj
        // match on method.method?
        //   - decide to send get params as URL query string, json
        //   - yada
        let request = Payload.request(method.method(), url)
        request("User-Agent") = "Pony Telegram Bot"
        request("Content-type") = ... // not needed with query string?

        // Make the call
        let sent_request: Payload = client(consume request, handle_maker)

        // Send body data via sent_request if it was a POST

    be cancelled() =>
        _env.out.print("-- response cancelled --")

    be have_response(response: Payload val) =>
        if response.status == 0 then
            _env.out.print("Failed")
            return
        end

        _env.out.print(
            "Response " +
            response.status.string() + " " +
            response.method)

        // Print all the headers
        for (k, v) in response.headers().pairs() do
            _env.out.print(k + ": " + v)
        end

        _env.out.print("")

        // Print the body if there is any.  This will fail in Chunked or
        // Stream transfer modes.
        try
            let body = response.body()
            for piece in body.values() do
                _env.out.write(piece)
            end
        end
        // Get response payload
        // error check?
        // fullfill/Reject a promise?

    be have_body(data: ByteSeq val) =>
        // Handle body data
        _env.out.write(data)

    be finished() =>
        _env.out.print("-- end of body --")
        // Set the api on the object
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
