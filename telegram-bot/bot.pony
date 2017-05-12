use "net/http"
use lgr = "logger"
use "net/ssl"
use "files"

actor Bot
    //let _log_level: lgr.LogLevel
    //let _logger: lgr.StringLogger
    let _logger: lgr.Logger[String]
    var api: (TelegramAPI | None) = None
    var self: (User | None) = None

    new create(env: Env, api_key: String, log_level: lgr.LogLevel = lgr.Warn) =>
        //_logger = lgr.StringLogger(
        let logger' = lgr.Logger[String].create(
            log_level,
            env.out,
            {(s: String): String => s },
            lgr.DefaultLogFormatter)
        
        var api': (TelegramAPI | None) = None

        // Attempt API connection creation
        try
            // Construct base call URL
            let endpoint: String = "https://api.telegram.org/"
            let url: String = endpoint + "bot" + api_key + "/"
            let url_base: URL = try
                URL.valid(url)
            else 
                logger'(lgr.Error) and logger'.log("Invalid API endpoint: " + url)
                error
            end

            // Get certificate for HTTPS links.
            let sslctx = try
                recover
                    SSLContext
                        .>set_client_verify(true)
                        .>set_authority(FilePath(env.root as AmbientAuth, "cacert.pem"))
                end
            else 
                logger'(lgr.Error) and logger'.log("Unable to set SSLContext")
                error
            end

            // An HTTP client to supply to the API.
            let client: HTTPClient iso = try
                recover iso HTTPClient(env.root as AmbientAuth, consume sslctx) end
            else
                logger'(lgr.Error) and logger'.log("Unable to use network.")
                error
            end

            api' = TelegramAPI.create(logger', url_base, consume client)
        else
            logger'(lgr.Error) and logger'.log("Could not establish TelegramAPI connection.")
        end

        match api'
        | let api'': TelegramAPI => 
            // Request the User representing this Bot
            let get_me = GetMe()
            get_me.next[None]({(mr: TelegramAPIMethodResponse)(bot = recover tag this end) => 
                bot.set_self(recover iso User(mr.api, mr.json_str_response) end)
            } iso)
            api''(consume get_me)
        end

        // Set bot fields
        _logger = logger'
        api = api'

    be set_self(user: User iso) =>
        self = consume user

    be log(level: lgr.LogLevel, message: String) =>
        _logger(level) and _logger.log(message)
