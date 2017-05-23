use "net/http"
use lgr = "logger"
use "net/ssl"
use "files"

actor Bot
  let _logger: lgr.Logger[String]
  var api: (TelegramAPI | None) = None
  var self: (User | None) = None

  new create(
    env: Env,
    api_token: String,
    log_level: lgr.LogLevel = lgr.Warn)
  =>
    let logger' =
      lgr.Logger[String].create(
        log_level,
        env.out,
        {(s: String): String => s },
        {(msg: String val, loc: SourceLoc val): String val => msg})

    logger'(lgr.Info) and logger'.log("Initializing Bot")

    var api': (TelegramAPI | None) = None

    // Attempt API connection creation
    logger'(lgr.Info) and logger'.log(" .. setting up API connection")
    try
      // Construct base call URL
      let endpoint: String = "https://api.telegram.org/"
      let url: String = endpoint + "bot" + api_token + "/"
      let url_base: URL =
        try
          URL.valid(url)
        else
          logger'(lgr.Error) and logger'.log(
            "Error: Invalid API endpoint: " + url)
          error
        end
      logger'(lgr.Info) and logger'.log("     with endpoint: " + endpoint)
      try
        api_token.find(":")
        if logger'(lgr.Info) then
          let split_token = api_token.split_by(":")
          let id = split_token.shift()
          let key = split_token.pop()
          let tok = id + ":..." + key.trim(key.size() - 6, key.size())
          logger'.log("     with API token: " + tok)
        end
      else
        logger'(lgr.Error) and logger'.log(
          "Error: API Token is of unknown format.")
        error
      end

      // Get certificate for HTTPS links.
      let sslctx =
        try
          recover
            let caps =
              recover val FileCaps .> set(FileRead) .> set(FileStat) end
            let pem_path = FilePath(
              env.root as AmbientAuth,
              "cacert.pem",
              caps)
            SSLContext
                .> set_client_verify(true)
                .> set_authority(pem_path)
          end
        else
          logger'(lgr.Error) and logger'.log(
            "Error: Unable to set SSLContext.")
          error
        end

      // An HTTP client to supply to the API.
      let client: HTTPClient iso =
        try
          recover HTTPClient(env.root as AmbientAuth, consume sslctx) end
        else
          logger'(lgr.Error) and logger'.log(
            "Error: Unable to use network.")
          error
        end

      api' = TelegramAPI.create(logger', url_base, consume client)
    else
      logger'(lgr.Error) and logger'.log(
        "Error: Could not establish TelegramAPI connection.")
    end

    match api'
    | let api'': TelegramAPI =>
      // Request the User representing this Bot
      logger'(lgr.Info) and logger'.log(" .. sending for bot's User object")
      let get_me = GetMe()
      get_me.next[None](
        {(mr: TelegramAPIMethodResponse)(bot = recover tag this end) =>
          bot.set_self(recover User(mr.api, mr.json_str_response) end)
        } iso)
      api''(consume get_me)
    end

    logger'(lgr.Info) and logger'.log(" .")

    // Set bot fields
    _logger = logger'
    api = api'

  be set_self(user: User iso) =>
    self = consume user
    if _logger(lgr.Info) then
      try
        _logger.log("Bot's User:\r\n" + (self as User).json.string(" ", true))
      end
    end

  be log(level: lgr.LogLevel, message: String) =>
    _logger(level) and _logger.log(message)
