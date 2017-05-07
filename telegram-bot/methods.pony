use "collections"
use "json"
use "promises"

trait tag PromiserOf[T: TelegramObject #share]
    fun apply(params: Optional[Map[String val, JsonType ref] iso] = None, request_method': Optional[String] = None): _TelegramMethod[T]^ =>
        let req_method: String = try
            request_method' as String
        else
            // Use default request method for this telegram method
            request_method()
        end
        _TelegramMethod[T](this, req_method, consume params)
    
    // Default request method for Telegram API method calls
    fun request_method(): String => "GET"

    fun tag self(): TelegramMethod
    fun tag string(): String

type TelegramMethod is
    ( GetUpdates
    | GetMe 
    | SendMessage
    //| ...
    )

primitive GetUpdates is PromiserOf[Updates]
    fun tag self(): TelegramMethod => this
    fun tag string(): String => "getUpdates"

primitive GetMe is PromiserOf[User]
    fun tag self(): TelegramMethod => this
    fun tag string(): String => "getMe"

primitive SendMessage is PromiserOf[Message]
    fun tag self(): TelegramMethod => this
    fun tag string(): String => "sendMessage"



trait GeneralTelegramMethod
    fun telegram_method(): TelegramMethod
    fun request_method(): String
    fun params(): Optional[Map[String val, JsonType ref] val]// iso]
    fun name(): String
    fun fulfill(f: {(): TelegramObject} iso)
    fun reject()

class iso _TelegramMethod[R: TelegramObject #share] is GeneralTelegramMethod
    let _telegram_method: PromiserOf[R]
    let _request_method: String
    let _params: Optional[Map[String val, JsonType ref] val] // iso] // ?
    let _promise: Promise[R]

    new iso create(telegram_method': PromiserOf[R], request_method': String, params': Optional[Map[String val, JsonType ref] iso] = None) =>
        _telegram_method = telegram_method'
        _request_method = request_method'
        _params = recover val consume params' end //consume params'
        _promise = Promise[R]

    fun ref next[T: Any #share](fulfiller: Fulfill[R, T],
                                rejecter: Reject[T] = RejectAlways[T]): Promise[T] =>
        _promise.next[T](consume fulfiller, consume rejecter)
    
    fun fulfill(f: {(): TelegramObject} iso) =>
        try
            let r = f() as R
            _promise(r)
        end

    fun reject() =>
        _promise.reject()

    fun telegram_method(): TelegramMethod =>
        _telegram_method.self()

    fun request_method(): String =>
        _request_method

    fun params(): Optional[Map[String val, JsonType ref] val] => // iso]
        _params

    fun name(): String =>
        _telegram_method.string()

/*
// BELOW IS OLD

// TODO: Perhaps turn these methods into actors/behaviors.
//   OR: Members of a primitive?
//   OR: Object literals closing over param data
//   OR: Some combo?

type TelegramObjectifier is {(JsonObject, TelegramAPI): TelegramObject ?}

trait TelegramMethod
    fun apply(api: TelegramAPI, to: ) =>
        api(this)

    fun method(): String => "GET"
    fun expect(): TelegramObjectifier

//trait PossiblyUnavailableChatMethod
type PossiblyUnavailableChatMethod is
    ( SendMessage
    | ForwardMessage
    | SendPhoto
    | SendAudio
    | SendDocument
    | SendSticker
    | SendVideo
    | SendVoice
    | SendLocation
    | SendVenue
    | SendContact
    | SendChatAction
    | KickChatMember
    | LeaveChat
    | UnbanChatMember
    | GetChat
    | GetChatAdministrators
    | GetChatMembersCount
    | GetChatMember
    | EditMessageText
    | EditMessageCaption
    | EditMessageReplyMarkup
    | SendGame
    | SetGameScore
    | GetGameHighScores
    )

type ChatIdentifier is (I64 | String)

// getUpdates -> Updates
class GetUpdates is TelegramMethod
    var offset: Optional[I64] = None
    var limit: Optional[I64] = None
    var timeout: Optional[I64] = None
    var allowed_updates: Optional[Array[String]] = None

// TODO:
// setWebhook
// deleteWebhook
// getWebhook

// getMe -> User
class GetMe is TelegramMethod
    fun expect(): TelegramObjectifier =>
        {(json: JsonObject, api: TelegramAPI): User ? => User(json, api)}

// sendMessage -> Message
class SendMessage is TelegramMethod
    var chat_id: ChatIdentifier
    var text: String
    var parse_mode: Optional[String] = None
    var disable_web_page_preview: Optional[Bool] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

// forwardMessage -> Message
class ForwardMessage is TelegramMethod
    var chat_id: ChatIdentifier
    var from_chat_id: ChatIdentifier
    var disable_notification: Optional[Bool] = None
    var message_id: I64

// sendPhoto -> Message
class SendPhoto is TelegramMethod
    var chat_id: ChatIdentifier
    var photo: String
    var caption: Optional[String] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

    fun method(): String => "POST"

// sendAudio -> Message
class SendAudio is TelegramMethod
    var chat_id: ChatIdentifier
    var audio: String
    var caption: Optional[String] = None
    var duration: Optional[I64] = None
    var performer: Optional[String] = None
    var title: Optional[String] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

    fun method(): String => "POST"

// sendDocument -> Message
class SendDocument is TelegramMethod
    var chat_id: ChatIdentifier
    var document: String
    var caption: Optional[String] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None
    
    fun method(): String => "POST"

// sendSticker -> Message
class SendSticker is TelegramMethod
    var chat_id: ChatIdentifier
    var sticker: String
    var caption: Optional[String] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

    fun method(): String => "POST"

// sendVideo -> Message
class SendVideo is TelegramMethod
    var chat_id: ChatIdentifier
    var video: String
    var duration: Optional[I64] = None
    var width: Optional[I64] = None
    var height: Optional[I64] = None
    var caption: Optional[String] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

    fun method(): String => "POST"

// sendVoice -> Message
class SendVoice is TelegramMethod
    var chat_id: ChatIdentifier
    var voice: String
    var caption: Optional[String] = None
    var duration: Optional[I64] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

    fun method(): String => "POST"

// sendLocation -> Message
class SendLocation is TelegramMethod
    var chat_id: ChatIdentifier
    var latitude: F64
    var longitude: F64
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

// sendVenue -> Message
class SendVenue is TelegramMethod
    var chat_id: ChatIdentifier
    var latitude: F64
    var longitude: F64
    var title: String
    var address: String
    var foursquare_id: Optional[String] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

// sendContact -> Message
class SendContact is TelegramMethod
    var chat_id: ChatIdentifier
    var phone_number: String
    var first_name: String
    var last_name: Optional[String] = None
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[ReplyMarkup] = None

// sendChatAction -> True
class SendChatAction is TelegramMethod
    var chat_id: ChatIdentifier
    var action: String

// getUserProfilePhotos -> UserProfilePhotos
class GetUserProfilePhotos is TelegramMethod
    var user_id: I64
    var offset: Optional[I64] = None
    var limit: Optional[I64] = None

// getFile -> File
class GetFile is TelegramMethod
    var file_id: String

// kickChatMember -> True
class KickChatMember is TelegramMethod
    var chat_id: ChatIdentifier
    var user_id: I64

// leaveChat -> True
class LeaveChat is TelegramMethod
    var chat_id: ChatIdentifier

// unbanChatMember -> True
class UnbanChatMember is TelegramMethod
    var chat_id: ChatIdentifier
    var user_id: I64

// getChat -> Chat
class GetChat is TelegramMethod
    var chat_id: ChatIdentifier

// getChatAdministrators -> Array[ChatMember]
class GetChatAdministrators is TelegramMethod
    var chat_id: ChatIdentifier

// getChatMembersCount -> I64
class GetChatMembersCount is TelegramMethod
    var chat_id: ChatIdentifier

// getChatMember -> ChatMember
class GetChatMember is TelegramMethod
    var chat_id: ChatIdentifier
    var user_id: I64

// answerCallbackQuery -> True
class AnswerCallbackQuery is TelegramMethod
    var callback_query_id: String
    var text: Optional[String] = None
    var show_alert: Optional[Bool] = None
    var url: Optional[String] = None
    var cache_time: Optional[I64] = None

// editMessageText -> Message | True
class EditMessageText is TelegramMethod
    var chat_id: Optional[ChatIdentifier] = None
    var message_id: Optional[I64] = None
    var inline_message_id: Optional[String] = None
    var text: String
    var parse_mode: Optional[String] = None
    var disable_web_page_preview: Optional[Bool] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None

// editMessageCaption -> Message | True
class EditMessageCaption is TelegramMethod
    var chat_id: Optional[ChatIdentifier] = None
    var message_id: Optional[I64] = None
    var inline_message_id: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None

// editMessageReplyMarkup -> Message | True
class EditMessageReplyMarkup is TelegramMethod
    var chat_id: Optional[ChatIdentifier] = None
    var message_id: Optional[I64] = None
    var inline_message_id: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None

// answerInlineQuery -> True
class AnswerInlineQuery is TelegramMethod
    var inline_query_id: String
    var results: Array[InlineQueryResult]
    var cache_time: Optional[I64] = None
    var is_personal: Optional[Bool] = None
    var next_offset: Optional[String] = None
    var switch_pm_text: Optional[String] = None
    var switch_pm_parameter: Optional[String] = None

// sendGame -> Message
class SendGame is TelegramMethod
    var chat_id: ChatIdentifier
    var game_short_name: String
    var disable_notification: Optional[Bool] = None
    var reply_to_message_id: Optional[I64] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None

// setGameScore -> ?
class SetGameScore is TelegramMethod
    var user_id: I64
    var score: I64
    var force: Optional[Bool] = None
    var disable_edit_message: Optional[Bool] = None
    var chat_id: Optional[I64] = None
    var message_id: Optional[I64] = None
    var inline_message_id: Optional[String] = None

// getGameHighScores -> Array[GameHighScore]
class GetGameHighScores is TelegramMethod
    var user_id: I64
    var chat_id: Optional[I64] = None
    var message_id: Optional[I64] = None
    var inline_message_id: Optional[String] = None
*/
