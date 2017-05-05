use "net/http"
use lgr = "logger"
use "net/ssl"
use "files"

actor Bot
    let _log_level: lgr.LogLevel
    //let _logger: lgr.StringLogger
    let _logger: lgr.Logger[String]
    var api: (TelegramAPI | None) = None
    var self: (User | None) = None

    new create(env: Env, api_key: String, log_level: lgr.LogLevel = lgr.Warn) =>
        // Setup a logger for our Bot
        _log_level = log_level
        //_logger = lgr.StringLogger(
        _logger = lgr.Logger[String].create(
            _log_level,
            env.out,
            {(s: String): String => s },
            lgr.DefaultLogFormatter)
        
        //var api_set: Bool = false
        //var api': (TelegramAPI | None) = None

        // Attempt API connection creation
        try
            // Construct base call URL
            let endpoint: String = "https://api.telegram.org/"
            let url: String = endpoint + "bot" + api_key + "/"
            let url_base: URL = try
                URL.valid(url)
            else 
                _logger(lgr.Error) and _logger.log("Invalid API endpoint: " + url)
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

            // An HTTP client to supply to the API.
            let client: HTTPClient iso = try
                recover iso HTTPClient(env.root as AmbientAuth, consume sslctx) end
            else
                _logger(lgr.Error) and _logger.log("Unable to use network.")
                error
            end

            api = TelegramAPI.create(_logger, url_base, consume client)
            //api = api' as TelegramAPI
            //api_set = true
        else
            _logger(lgr.Error) and _logger.log("Could not establish TelegramAPI connection.")
        end

        match api
            | let a: TelegramAPI => 
                // Request the User representing this Bot
                let get_me = GetMe()
                get_me.next[None]({(u: User iso)(bot = this) => bot.set_self(consume u)})
                get_me(a)
        end

        // if api_set then
        //     // Request the User representing this Bot
        //     let get_me = GetMe()
        //     get_me.next[None]({(u: User iso)(bot = this) => bot.set_self(consume u)})
        //     get_me(api)
        // end

    be set_self(user: User iso) =>
        self = recover consume user end
