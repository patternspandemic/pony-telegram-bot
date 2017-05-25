use "collections"
use "itertools"
use "json"
use "time"

// TODO: Include bot tag in TelegramObjects?

// General purpose optional type
type Optional[T] is (T | None)

type JsonObjectData is
  HashMap[
    String val,
    ( F64 val
    | I64 val
    | Bool val
    | None val
    | String val
    | JsonArray ref
    | JsonObject ref
    ),
    HashEq[String val] val
  ] ref

// A Helper for dealing with the underlying JsonObject help by TelegramObjects
primitive JsonHelper
  fun optional_json_str_to_json_obj(
    optional_json_str: Optional[String],
    prealloc: USize val = 6)
    : JsonObject
  =>
    let json_object: JsonObject ref =
      try
        let str: String = optional_json_str as String
        let doc: JsonDoc ref = JsonDoc.create()
        doc.parse(str)
        match doc.data
        | let d: JsonObject => d
        else
          // TODO: Warn via api or bot that couldn't parse JsonObject in json_str' ?
          error
        end
      else
        JsonObject.create(prealloc)
      end
    json_object

  fun json_obj_to_str(json_obj: JsonObject): String =>
    json_obj.string()

primitive MissingRequiredField
  """The type of a missing required field for a TelegramObject."""

primitive UnknownField
  """The type of an unknown field for a TelegramObject."""

primitive WrongOrChangedField
  """The type of a TelegramObject field with an unexpected type."""

primitive NotImplemented
  """The type of un-implemented functionality for a TelegramObject field."""

// Telegram object field types, similar to JsonType
type TelegramType is
  ( F64 val
  | I64 val
  | Bool val
  | None val
  | String val
  | TelegramObject ref
  //| TelegramObjectArray
  | MissingRequiredField
  | UnknownField
  | WrongOrChangedField
  | NotImplemented
  )

// TODO: Add trait val TelegramObjectArray and add to TelegramType
// as analog to JsonArray (Updates and other arrayed responses would be of this type)

trait val TelegramObject
  """
  Telegram Bot API Types
  https://core.telegram.org/bots/api#available-types
  """
  fun ref apply(field: String): TelegramType =>
    let fields: JsonObjectData = _fields() // reference the concrete object's underlying json data
    var result: JsonType

    // Return None for non-existant fields unless they're in the required list.
    result =
      try fields(field) // get field from underlying json data
      else
        // error if the field was required
        if _required_fields().contains(field) then
          // TODO: Log Error of missing required field
          return MissingRequiredField
        else
          // otherwise it was optional, return None
          return None
        end
      end

    // Delegate to the concrete object for translating existing
    // _fields fields from JsonType to TelegramType.
    _json_to_telegram_type(field, result)

  fun ref update(field: String, value: TelegramType): TelegramType =>
    let fields: JsonObjectData = _fields() // reference the concrete object's underlying json data

    // value needs to be transformed from TelegramType back to JsonType
    let json_value: JsonType =
      match value
      | let x: F64 => x
      | let x: I64 => x
      | let x: Bool => x
      | let x: String => x
      | None | UnknownField => None // Unknown fields returned by API calls are mapped to None
      | let x: TelegramObject ref =>
        // The JsonObject or JsonArray representation of the TelegramObject
        try
          match x._json() as JsonType
          | let y: JsonObject => y
          | let y: JsonArray => y
          end
        end
      // | let x: TelegramObjectArray =>
      //     // Map to JsonArray
      //     // TODO / FIXME: ...?
      | let x: MissingRequiredField => None // TODO: Maybe should be error ?
      | let x: NotImplemented => None // TODO: Maybe should be error ?
      | let x: WrongOrChangedField => None  // TODO: Maybe should be error ?
      end

    // Update the field capturing old value
    let old_json_value: JsonType = fields(field) = json_value

    // Return old value transformed back to TelegramType
    _json_to_telegram_type(field, old_json_value)

  // The underlying map of JsonObject data
  fun ref _fields(): JsonObjectData

  // Required fields for the concrete TelegramObject
  fun _required_fields(): Array[String]

  // Concrete type delegation to turn a field's JsonType into the correct TelegramType
  fun ref _json_to_telegram_type(field: String, jt: JsonType): TelegramType

  // Underlying JsonObject of TelegramObject
  fun ref _json(): JsonType



// Concrete Types ...

// TODO: Redefine as TelegramObjectArray
class Updates is TelegramObject
  var api: TelegramAPI tag
  var json: JsonArray

  new create(api': TelegramAPI, json_str': String) =>
    api = api'
    let doc: JsonDoc ref = JsonDoc.create()
    json =
      try
        doc.parse(json_str')
        doc.data as JsonArray
      else
        // TODO: Warn via api or bot that couldn't parse update array in json_str' ?
        // Shouldn't happen unless json_str' is corrupt
        JsonArray.create()
      end

  // Provides its own impl because underlying json is JsonArray
  // Just to fulfill TelegramObject contract
  fun ref apply(field: String): TelegramType =>
    // FIXME: ? Calling apply not useful for this TelegramObject
    NotImplemented

  // Provides its own impl because underlying json is JsonArray
  // Just to fulfill TelegramObject contract
  fun ref update(field: String, value: TelegramType): TelegramType =>
    // FIXME: ? Calling apply not useful for this TelegramObject
    NotImplemented

  // Provides its own impl because underlying json is JsonArray
  // FIXME: ? Hopefully this won't be called, nevertheless returns
  // empty JsonObjectData just to fulfill contract with TelegramObject
  fun ref _fields(): JsonObjectData => JsonObjectData

  // Just to fulfill TelegramObject contract
  fun _required_fields(): Array[String] =>
    Array[String].create() // No requirements, just a container really with context helpful methods

  fun _json_to_telegram_type(field: String, jt: JsonType): TelegramType =>
    // FIXME: ? Calling _json_to_telegram_type not useful for this TelegramObject
    NotImplemented

  fun ref _json(): JsonType => json


class Update is TelegramObject
  var api: TelegramAPI tag
  var json: JsonObject

  new create(api': TelegramAPI, json_str': String) =>
    api = api'
    let doc: JsonDoc ref = JsonDoc.create()
    json =
      try
        doc.parse(json_str')
        doc.data as JsonObject
      else
        // TODO: Warn via api or bot that couldn't parse update in json_str' ?
        // Shouldn't happen unless json_str' is corrupt
        JsonObject.create()
      end

  fun ref _fields(): JsonObjectData => json.data

  fun _required_fields(): Array[String] => ["update_id"]

  fun _json_to_telegram_type(field: String, jt: JsonType): TelegramType =>
      let json_str: String =
        try JsonHelper.json_obj_to_str(jt as JsonObject)
        else "" end
      try
        match field
        | "update_id" => jt as I64
        | "message" | "edited_message" | "channel_post" |
          "edited_channel_post" => Message(api, json_str)
        | "inline_query" => NotImplemented // InlineQuery(api, json_str)
        | "chosen_inline_result" => NotImplemented // ChosenInlineResult(api, json_str)
        | "callback_query" => NotImplemented // CallbackQuery(api, json_str)
        | "shipping_query" => NotImplemented // ShippingQuery(api, json_str)
        | "pre_checkout_query" => NotImplemented // PreCheckoutQuery(api, json_str)
        else
          UnknownField
        end
      else
        WrongOrChangedField
      end

  fun ref _json(): JsonType => json

/*
class WebhookInfo is TelegramObject
    var url: String
    var has_custom_certificate: Bool
    var pending_update_count: I64
    var last_error_date: Optional[I64] = None
    var last_error_message: Optional[String] = None
    var max_connections: Optional[I64] = None
    var allowed_updates: Optional[Array[String]] = None

    new create(json: JsonObject) ? =>
        url = json.data("url") as String
        has_custom_certificate = json.data("has_custom_certificate") as Bool
        pending_update_count = json.data("pending_update_count") as I64
        last_error_date = try json.data("last_error_date") as I64 end
        last_error_message = try json.data("last_error_message") as String end
        max_connections = try json.data("max_connections") as I64 end
        allowed_updates = try
            var allowed_updates_jsonarray = json.data("allowed_updates") as JsonArray
            let count = allowed_updates_jsonarray.data.size()
            Iter[JsonType](allowed_updates_jsonarray.data.values())
                .map[String]({(j: JsonType): String ? => j as String})
                .collect(Array[String](count))
        end
*/

class User is TelegramObject
  var api: TelegramAPI tag
  var json: JsonObject

  new create(api': TelegramAPI, json_str': Optional[String] = None) =>
    api = api'
    json = JsonHelper.optional_json_str_to_json_obj(json_str', 4)

  fun ref _fields(): JsonObjectData => json.data

  fun _required_fields(): Array[String] => ["id"; "first_name"]

  fun _json_to_telegram_type(field: String, jt: JsonType): TelegramType =>
    try
      match field
      | "id" => jt as I64
      | "first_name" | "last_name" | "username" | "language_code" =>
        jt as String
      else
        UnknownField
      end
    else
      WrongOrChangedField
    end

  fun ref _json(): JsonType => json

/*
class Chat is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var id: I64
    var type': String // ChatType
    var title: Optional[String] = None
    var username: Optional[String] = None
    var first_name: Optional[String] = None
    var last_name: Optional[String] = None
    var all_members_are_administrators: Optional[Bool] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        id = json.data("id") as I64
        type' = json.data("type") as String
        title = try json.data("title") as String end
        username = try json.data("username") as String end
        first_name = try json.data("first_name") as String end
        last_name = try json.data("last_name") as String end
        all_members_are_administrators = try json.data("all_members_are_administrators") as Bool end
*/

class Message is TelegramObject
  var api: TelegramAPI tag
  var json: JsonObject

  new create(api': TelegramAPI, json_str': Optional[String] = None) =>
    api = api'
    json = JsonHelper.optional_json_str_to_json_obj(json_str', 15) // TODO: Find max message object field count

  fun ref _fields(): JsonObjectData => json.data

  fun _required_fields(): Array[String] => ["message_id"; "date"; "chat"]

  fun _json_to_telegram_type(field: String, jt: JsonType): TelegramType =>
    let json_str: String =
      try JsonHelper.json_obj_to_str(jt as JsonObject)
      else "" end
    try
      match field
      | "message_id" | "date" | "forward_from_message_id" | "forward_date" |
        "edit_date" | "migrate_to_chat_id" | "migrate_from_chat_id" => jt as I64
      | "text" | "caption" | "new_chat_title" => jt as String
      | "delete_chat_photo" | "group_chat_created" | "supergroup_chat_created" |
        "channel_chat_created" => jt as Bool
      | "from" | "forward_from" | "left_chat_member" => User(api, json_str)
      | "new_chat_members" => None // FIXME: Array[User]
      | "chat" | "forward_from_chat" => NotImplemented // Chat(api, json_str)
      | "reply_to_message" | "pinned_message" => Message(api, json_str)
      | "audio" => NotImplemented // Audio(api, json_str)
      | "document" => NotImplemented // Document(api, json_str)
      | "game" => NotImplemented // Game(api, json_str)
      | "sticker" => NotImplemented // Sticker(api, json_str)
      | "video" => NotImplemented // Video(api, json_str)
      | "voice" => NotImplemented // Voice(api, json_str)
      | "video_note" => NotImplemented // VideoNote(api, json_str)
      | "contact" => NotImplemented // Contact(api, json_str)
      | "location" => NotImplemented // Location(api, json_str)
      | "venue" => NotImplemented // Venue(api, json_str)
      | "entities" => None // FIXME: Array[MessageEntity]
      | "photo" | "new_chat_photo" => None // FIXME: Array[PhotoSize]
      | "invoice" => NotImplemented // Invoice(api, json_str)
      | "successful_payment" => NotImplemented // SuccessfulPayment(api, json_str)
      else
        UnknownField
      end
    else
      WrongOrChangedField
    end

  fun ref _json(): JsonType => json

/*
class MessageEntity is TelegramObject //is APIUser
    //var _api: TelegramAPI
    var type': String // MessageEntityType
    var offset: I64
    var length: I64
    var url: Optional[String] = None
    var user: Optional[User] = None

    new create(json: JsonObject) ? => // , api: TelegramAPI) ? =>
        // _api = api
        type' = json.data("type") as String
        offset = json.data("offset") as I64
        length = json.data("length") as I64
        url = try json.data("url") as String end
        user = try User(json.data("user") as JsonObject) end

class PhotoSize is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var file_id: String
    var width: I64
    var height: I64
    var file_size: Optional[I64] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        file_id = json.data("file_id") as String
        width = json.data("width") as I64
        height = json.data("height") as I64
        file_size = try json.data("file_size") as I64 end

class Audio is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var file_id: String
    var duration: I64
    var performer: Optional[String] = None
    var title: Optional[String] = None
    var mime_type: Optional[String] = None
    var file_size: Optional[I64] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        file_id = json.data("file_id") as String
        duration = json.data("duration") as I64
        performer = try json.data("performer") as String end
        title = try json.data("title") as String end
        mime_type = try json.data("mime_type") as String end
        file_size = try json.data("file_size") as I64 end

class Document is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var file_id: String
    var thumb: Optional[PhotoSize] = None
    var file_name: Optional[String] = None
    var mime_type: Optional[String] = None
    var file_size: Optional[I64] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        file_id = json.data("file_id") as String
        thumb = try PhotoSize(json.data("thumb") as JsonObject) end
        file_name = try json.data("file_name") as String end
        mime_type = try json.data("mime_type") as String end
        file_size = try json.data("file_size") as I64 end

class Sticker is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var file_id: String
    var width: I64
    var height: I64
    var thumb: Optional[PhotoSize] = None
    var emoji: Optional[String] = None
    var file_size: Optional[I64] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        file_id = json.data("file_id") as String
        width = json.data("width") as I64
        height = json.data("height") as I64
        thumb = try PhotoSize(json.data("thumb") as JsonObject) end
        emoji = try json.data("emoji") as String end
        file_size = try json.data("file_size") as I64 end

class Video is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var file_id: String
    var width: I64
    var height: I64
    var duration: I64
    var thumb: Optional[PhotoSize] = None
    var mime_type: Optional[String] = None
    var file_size: Optional[I64] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        file_id = json.data("file_id") as String
        width = json.data("width") as I64
        height = json.data("height") as I64
        duration = json.data("duration") as I64
        thumb = try PhotoSize(json.data("thumb") as JsonObject) end
        mime_type = try json.data("mime_type") as String end
        file_size = try json.data("file_size") as I64 end

class Voice is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var file_id: String
    var duration: I64
    var mime_type: Optional[String] = None
    var file_size: Optional[I64] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        file_id = json.data("file_id") as String
        duration = json.data("duration") as I64
        mime_type = try json.data("mime_type") as String end
        file_size = try json.data("file_size") as I64 end

class Contact is TelegramObject
    var phone_number: String
    var first_name: String
    var last_name: Optional[String] = None
    var user_id: Optional[I64] = None

    new create(json: JsonObject) ? =>
        phone_number = json.data("phone_number") as String
        first_name = json.data("first_name") as String
        last_name = try json.data("last_name") as String end
        user_id = try json.data("user_id") as I64 end

class Location is TelegramObject
    var longitude: F64
    var latitude: F64

    new create(json: JsonObject) ? =>
        longitude = json.data("longitude") as F64
        latitude = json.data("latitude") as F64

class Venue is TelegramObject
    var location: Location
    var title: String
    var address: String
    var foursquare_id: Optional[String] = None

    new create(json: JsonObject) ? =>
        location = Location(json.data("location") as JsonObject)
        title = json.data("title") as String
        address = json.data("address") as String
        foursquare_id = try json.data("foursquare_id") as String end

class UserProfilePhotos is TelegramObject
    var total_count: I64
    var photos: Array[Array[PhotoSize]]

    new create(json: JsonObject) ? =>
        total_count = json.data("total_count") as I64
        photos = _json_to_photos(json.data("photos") as JsonArray)

    fun tag _json_to_photos(json: JsonArray): Array[Array[PhotoSize]] ? =>
        let photo_cnt = json.data.size()
        var photos' = Array[Array[PhotoSize]](photo_cnt)
        for a in json.data.values() do
            var o = a as JsonObject
            let photo_size_cnt = o.data.size()
            photos'.push(Iter[JsonType](o.data.values())
                .map[PhotoSize]({(j: JsonType): PhotoSize ? => PhotoSize(j as JsonObject)})
                .collect(Array[PhotoSize](photo_size_cnt)))
        end
        photos'

class TelegramFile is TelegramObject
    var file_id: String
    var file_size: Optional[I64] = None
    var file_path: Optional[String] = None

    new create(json: JsonObject) ? =>
        file_id = json.data("file_id") as String
        file_size = try json.data("file_size") as I64 end
        file_path = try json.data("file_path") as String end

class ReplyKeyboardMarkup is TelegramObject
    var keyboard: Array[Array[KeyboardButton]]
    var resize_keyboard: Optional[Bool] = None
    var one_time_keyboard: Optional[Bool] = None
    var selective: Optional[Bool] = None

    new create(json: JsonObject) ? =>
        keyboard = _json_to_keyboard(json.data("keyboard") as JsonArray)
        resize_keyboard = try json.data("resize_keyboard") as Bool end
        one_time_keyboard = try json.data("one_time_keyboard") as Bool end
        selective = try json.data("selective") as Bool end

    fun tag _json_to_keyboard(json: JsonArray): Array[Array[KeyboardButton]] ? =>
        let keyboard_row_cnt = json.data.size()
        var keyboard' = Array[Array[KeyboardButton]](keyboard_row_cnt)
        for a in json.data.values() do
            var o = a as JsonObject
            let keyboard_button_cnt = o.data.size()
            keyboard'.push(Iter[JsonType](o.data.values())
                .map[KeyboardButton]({(j: JsonType): KeyboardButton ? => KeyboardButton(j as JsonObject)})
                .collect(Array[KeyboardButton](keyboard_button_cnt)))
        end
        keyboard'

class KeyboardButton is TelegramObject
    var text: String
    var request_contact: Optional[Bool] = None
    var request_location: Optional[Bool] = None

    new create(json: JsonObject) ? =>
        text = json.data("text") as String
        request_contact = try json.data("request_contact") as Bool end
        request_location = try json.data("request_location") as Bool end

class ReplyKeyboardRemove is TelegramObject
    var remove_keyboard: Bool
    var selective: Optional[Bool] = None

    new create(json: JsonObject) ? =>
        remove_keyboard = json.data("remove_keyboard") as Bool
        selective = try json.data("selective") as Bool end

class InlineKeyboardMarkup is TelegramObject
    var inline_keyboard: Array[Array[InlineKeyboardButton]]

    new create(json: JsonObject) ? =>
        inline_keyboard = _json_to_inline_keyboard(json.data("inline_keyboard") as JsonArray)
    
    fun tag _json_to_inline_keyboard(json: JsonArray): Array[Array[InlineKeyboardButton]] ? =>
        let keyboard_row_cnt = json.data.size()
        var keyboard' = Array[Array[InlineKeyboardButton]](keyboard_row_cnt)
        for a in json.data.values() do
            var o = a as JsonObject
            let keyboard_button_cnt = o.data.size()
            keyboard'.push(Iter[JsonType](o.data.values())
                .map[InlineKeyboardButton]({(j: JsonType): InlineKeyboardButton ? => InlineKeyboardButton(j as JsonObject)})
                .collect(Array[InlineKeyboardButton](keyboard_button_cnt)))
        end
        keyboard'

class InlineKeyboardButton is TelegramObject
    var text: String
    var url: Optional[String] = None
    var callback_data: Optional[String] = None
    var switch_inline_query: Optional[String] = None
    var switch_inline_query_current_chat: Optional[String] = None
    var callback_game: Optional[CallbackGame] = None
    var pay: Optional[Bool] = None

    new create(json: JsonObject) ? =>
        text = json.data("text") as String
        url = try json.data("url") as String end
        callback_data = try json.data("callback_data") as String end
        switch_inline_query = try json.data("switch_inline_query") as String end
        switch_inline_query_current_chat = try json.data("switch_inline_query_current_chat") as String end
        callback_game = try CallbackGame(json.data("callback_game") as JsonObject) end
        pay = try json.data("pay") as Bool end

class CallbackQuery is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var id: String
    var from: User
    var message: Optional[Message] = None
    var inline_message_id: Optional[String] = None
    var chat_instance: String
    var data: Optional[String] = None
    var game_short_name: Optional[String] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        id = json.data("id") as String
        from = User(json.data("from") as JsonObject)
        message = try Message(json.data("message") as JsonObject) end
        inline_message_id = try json.data("inline_message_id") as String end
        chat_instance = json.data("chat_instance") as String
        data = try json.data("data") as String end
        game_short_name = try json.data("game_short_name") as String end

class ForceReply is TelegramObject
    var force_reply: Bool
    var selective: Optional[Bool] = None

    new create(json: JsonObject) ? =>
        force_reply = json.data("force_reply") as Bool
        selective = try json.data("selective") as Bool end

class ChatMember is TelegramObject
    var user: User
    var status: String

    new create(json: JsonObject) ? =>
        user = User(json.data("user") as JsonObject)
        status = json.data("status") as String

class ResponseParameters is TelegramObject
    var migrate_to_chat_id: I64
    var retry_after: I64

    new create(json: JsonObject) ? =>
        migrate_to_chat_id = json.data("migrate_to_chat_id") as I64
        retry_after = json.data("retry_after") as I64

// ? class InputFile

class InlineQuery is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var id: String
    var from: User
    var location: Optional[Location] = None
    var query: String
    var offset: String

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        id = json.data("id") as String
        from = User(json.data("from") as JsonObject)
        location = try Location(json.data("location") as JsonObject) end
        query = json.data("query") as String
        offset = json.data("offset") as String

type InlineQueryResult is
    ( InlineQueryResultArticle
    | InlineQueryResultPhoto
    | InlineQueryResultCachedPhoto
    | InlineQueryResultGif
    | InlineQueryResultCachedGif
    | InlineQueryResultMpeg4Gif
    | InlineQueryResultCachedMpeg4Gif
    | InlineQueryResultVideo
    | InlineQueryResultCachedVideo
    | InlineQueryResultAudio
    | InlineQueryResultCachedAudio
    | InlineQueryResultVoice
    | InlineQueryResultCachedVoice
    | InlineQueryResultDocument
    | InlineQueryResultCachedDocument
    | InlineQueryResultLocation
    | InlineQueryResultVenue
    | InlineQueryResultContact
    | InlineQueryResultGame
    | InlineQueryResultCachedSticker
    )

class InlineQueryResultArticle is TelegramObject
    var type': String
    var id: String
    var title: String
    var input_message_content: JsonObject // InputMessageContent
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var url: Optional[String] = None
    var hide_url: Optional[Bool] = None
    var description: Optional[String] = None
    var thumb_url: Optional[String] = None
    var thumb_width: Optional[I64] = None
    var thumb_height: Optional[I64] = None

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        title = json.data("title") as String
        input_message_content = json.data("input_message_content") as JsonObject
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        url = try json.data("url") as String end
        hide_url = try json.data("hide_url") as Bool end
        description = try json.data("description") as String end
        thumb_url = try json.data("thumb_url") as String end
        thumb_width = try json.data("thumb_width") as I64 end
        thumb_height = try json.data("thumb_height") as I64 end

class InlineQueryResultPhoto is TelegramObject
    var type': String
    var id: String
    var photo_url: String
    var thumb_url: String
    var photo_width: Optional[I64] = None
    var photo_height: Optional[I64] = None
    var title: Optional[String] = None
    var description: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        photo_url = json.data("photo_url") as String
        thumb_url = json.data("thumb_url") as String
        photo_width = try json.data("photo_width") as I64 end
        photo_height = try json.data("photo_height") as I64 end
        title = try json.data("title") as String end
        description = try json.data("description") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end


class InlineQueryResultGif is TelegramObject
    var type': String
    var id: String
    var gif_url: String
    var gif_width: Optional[I64] = None
    var gif_height: Optional[I64] = None
    var gif_duration: Optional[I64] = None
    var thumb_url: String
    var title: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        gif_url = json.data("gif_url") as String
        gif_width = try json.data("gif_width") as I64 end
        gif_height = try json.data("gif_height") as I64 end
        gif_duration = try json.data("gif_duration") as I64 end
        thumb_url = json.data("thumb_url") as String
        title = try json.data("title") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultMpeg4Gif is TelegramObject
    var type': String
    var id: String
    var mpeg4_url: String
    var mpeg4_width: Optional[I64] = None
    var mpeg4_height: Optional[I64] = None
    var mpeg4_duration: Optional[I64] = None
    var thumb_url: String
    var title: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        mpeg4_url = json.data("mpeg4_url") as String
        mpeg4_width = try json.data("mpeg4_width") as I64 end
        mpeg4_height = try json.data("mpeg4_height") as I64 end
        mpeg4_duration = try json.data("mpeg4_duration") as I64 end
        thumb_url = json.data("thumb_url") as String
        title = try json.data("title") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultVideo is TelegramObject
    var type': String
    var id: String
    var video_url: String
    var mime_type: String
    var thumb_url: String
    var title: String
    var caption: Optional[String] = None
    var video_width: Optional[I64] = None
    var video_height: Optional[I64] = None
    var video_duration: Optional[I64] = None
    var description: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        video_url = json.data("video_url") as String
        mime_type = json.data("mime_type") as String
        thumb_url = json.data("thumb_url") as String
        title = json.data("title") as String
        caption = try json.data("caption") as String end
        video_width = try json.data("video_width") as I64 end
        video_height = try json.data("video_height") as I64 end
        video_duration = try json.data("video_duration") as I64 end
        description = try json.data("description") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultAudio is TelegramObject
    var type': String
    var id: String
    var audio_url: String
    var title: String
    var caption: Optional[String] = None
    var performer: Optional[String] = None
    var audio_duration: Optional[I64] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        audio_url = json.data("audio_url") as String
        title = json.data("title") as String
        caption = try json.data("caption") as String end
        performer = try json.data("performer") as String end
        audio_duration = try json.data("audio_duration") as I64 end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultVoice is TelegramObject
    var type': String
    var id: String
    var voice_url: String
    var title: String
    var caption: Optional[String] = None
    var voice_duration: Optional[I64] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        voice_url = json.data("voice_url") as String
        title = json.data("title") as String
        caption = try json.data("caption") as String end
        voice_duration = try json.data("voice_duration") as I64 end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultDocument is TelegramObject
    var type': String
    var id: String
    var title: String
    var caption: Optional[String] = None
    var document_url: String
    var mime_type: String
    var description: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent
    var thumb_url: Optional[String] = None
    var thumb_width: Optional[I64] = None
    var thumb_height: Optional[I64] = None

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        title = json.data("title") as String
        caption = try json.data("caption") as String end
        document_url = json.data("document_url") as String
        mime_type = json.data("mime_type") as String
        description = try json.data("description") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end
        thumb_url = try json.data("thumb_url") as String end
        thumb_width = try json.data("thumb_width") as I64 end
        thumb_height = try json.data("thumb_height") as I64 end

class InlineQueryResultLocation is TelegramObject
    var type': String
    var id: String
    var latitude: F64
    var longitude: F64
    var title: String
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent
    var thumb_url: Optional[String] = None
    var thumb_width: Optional[I64] = None
    var thumb_height: Optional[I64] = None

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        latitude = json.data("latitude") as F64
        longitude = json.data("longitude") as F64
        title = json.data("title") as String
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end
        thumb_url = try json.data("thumb_url") as String end
        thumb_width = try json.data("thumb_width") as I64 end
        thumb_height = try json.data("thumb_height") as I64 end

class InlineQueryResultVenue is TelegramObject
    var type': String
    var id: String
    var latitude: F64
    var longitude: F64
    var title: String
    var address: String
    var foursquare_id: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent
    var thumb_url: Optional[String] = None
    var thumb_width: Optional[I64] = None
    var thumb_height: Optional[I64] = None

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        latitude = json.data("latitude") as F64
        longitude = json.data("longitude") as F64
        title = json.data("title") as String
        address = json.data("address") as String
        foursquare_id = try json.data("foursquare_id") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end
        thumb_url = try json.data("thumb_url") as String end
        thumb_width = try json.data("thumb_width") as I64 end
        thumb_height = try json.data("thumb_height") as I64 end

class InlineQueryResultContact is TelegramObject
    var type': String
    var id: String
    var phone_number: String
    var first_name: String
    var last_name: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent
    var thumb_url: Optional[String] = None
    var thumb_width: Optional[I64] = None
    var thumb_height: Optional[I64] = None

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        phone_number = json.data("phone_number") as String
        first_name = json.data("first_name") as String
        last_name = try json.data("last_name") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end
        thumb_url = try json.data("thumb_url") as String end
        thumb_width = try json.data("thumb_width") as I64 end
        thumb_height = try json.data("thumb_height") as I64 end

class InlineQueryResultGame is TelegramObject
    var type': String
    var id: String
    var game_short_name: String
    var reply_markup: Optional[InlineKeyboardMarkup] = None

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        game_short_name = json.data("game_short_name") as String
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end

class InlineQueryResultCachedPhoto is TelegramObject
    var type': String
    var id: String
    var photo_file_id: String
    var title: Optional[String] = None
    var description: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        photo_file_id = json.data("photo_file_id") as String
        title = try json.data("title") as String end
        description = try json.data("description") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultCachedGif is TelegramObject
    var type': String
    var id: String
    var gif_file_id: String
    var title: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        gif_file_id = json.data("gif_file_id") as String
        title = try json.data("title") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultCachedMpeg4Gif is TelegramObject
    var type': String
    var id: String
    var mpeg4_file_id: String
    var title: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        mpeg4_file_id = json.data("mpeg4_file_id") as String
        title = try json.data("title") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultCachedSticker is TelegramObject
    var type': String
    var id: String
    var sticker_file_id: String
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        sticker_file_id = json.data("sticker_file_id") as String
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultCachedDocument is TelegramObject
    var type': String
    var id: String
    var title: String
    var document_file_id: String
    var description: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        title = json.data("title") as String
        document_file_id = json.data("document_file_id") as String
        description = try json.data("description") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultCachedVideo is TelegramObject
    var type': String
    var id: String
    var video_file_id: String
    var title: String
    var description: Optional[String] = None
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        video_file_id = json.data("video_file_id") as String
        title = json.data("title") as String
        description = try json.data("description") as String end
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultCachedVoice is TelegramObject
    var type': String
    var id: String
    var voice_file_id: String
    var title: String
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        voice_file_id = json.data("voice_file_id") as String
        title = json.data("title") as String
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

class InlineQueryResultCachedAudio is TelegramObject
    var type': String
    var id: String
    var audio_file_id: String
    var caption: Optional[String] = None
    var reply_markup: Optional[InlineKeyboardMarkup] = None
    var input_message_content: Optional[JsonObject] = None // InputMessageContent

    new create(json: JsonObject) ? =>
        type' = json.data("type") as String
        id = json.data("id") as String
        audio_file_id = json.data("audio_file_id") as String
        caption = try json.data("caption") as String end
        reply_markup = try InlineKeyboardMarkup(json.data("reply_markup") as JsonObject) end
        input_message_content = try json.data("input_message_content") as JsonObject end

type InputMessageContent is
    ( InputTextMessageContent
    | InputLocationMessageContent
    | InputVenueMessageContent
    | InputContactMessageContent
    )

class InputTextMessageContent is TelegramObject
    var message_text: String
    var parse_mode: Optional[String] = None
    var disable_web_page_preview: Optional[Bool] = None

    new create(json: JsonObject) ? =>
        message_text = json.data("message_text") as String
        parse_mode = try json.data("parse_mode") as String end
        disable_web_page_preview = try json.data("disable_web_page_preview") as Bool end

class InputLocationMessageContent is TelegramObject
    var longitude: F64
    var latitude: F64

    new create(json: JsonObject) ? =>
        longitude = json.data("longitude") as F64
        latitude = json.data("latitude") as F64

class InputVenueMessageContent is TelegramObject
    var longitude: F64
    var latitude: F64
    var title: String
    var address: String
    var foursquare_id: Optional[String] = None

    new create(json: JsonObject) ? =>
        longitude = json.data("longitude") as F64
        latitude = json.data("latitude") as F64
        title = json.data("title") as String
        address = json.data("address") as String
        foursquare_id = try json.data("foursquare_id") as String end

class InputContactMessageContent is TelegramObject
    var phone_number: String
    var first_name: String
    var last_name: Optional[String] = None

    new create(json: JsonObject) ? =>
        phone_number = json.data("phone_number") as String
        first_name = json.data("first_name") as String
        last_name = try json.data("last_name") as String end

class ChosenInlineResult is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var result_id: String
    var from: User
    var location: Optional[Location] = None
    var inline_message_id: Optional[String] = None
    var query: String

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        result_id = json.data("result_id") as String
        from = User(json.data("from") as JsonObject)
        location = try Location(json.data("location") as JsonObject) end
        inline_message_id = try json.data("inline_message_id") as String end
        query = json.data("query") as String

// TODO:
// LabeledPrice
// Invoice
// ShippingAddress
// OrderInfo
// ShippingOption
// SuccessfulPayment
// ShippingQuery
// PreCheckoutQuery

class Game is (TelegramObject & APIUser)
    var _api: TelegramAPI
    var title: String
    var description: String
    var photo: Array[PhotoSize]
    var text: Optional[String] = None
    var text_entities: Optional[Array[MessageEntity]] = None
    var animation: Optional[Animation] = None

    new create(json: JsonObject, api: TelegramAPI) ? =>
        _api = api
        title = json.data("title") as String
        description = json.data("description") as String
        photo = _json_to_photo(json.data("photo") as JsonArray)
        text = try json.data("text") as String end
        text_entities = try
            var entities_jsonarray = json.data("text_entities") as JsonArray
            let count = entities_jsonarray.data.size()
            Iter[JsonType](entities_jsonarray.data.values())
                .map[MessageEntity]({(j: JsonType): MessageEntity ? => MessageEntity(j as JsonObject)})
                .collect(Array[MessageEntity](count))
        end
        animation = try Animation(json.data("animation") as JsonObject) end

    fun tag _json_to_photo(json: JsonArray): Array[PhotoSize] =>
        let count = json.data.size()
        Iter[JsonType](json.data.values())
            .map[PhotoSize]({(j: JsonType): PhotoSize ? => PhotoSize(j as JsonObject)})
            .collect(Array[PhotoSize](count))

class Animation is TelegramObject
    var file_id: String
    var thumb: Optional[PhotoSize] = None
    var file_name: Optional[String] = None
    var mime_type: Optional[String] = None
    var file_size: Optional[I64] = None

    new create(json: JsonObject) ? =>
        file_id = json.data("file_id") as String
        thumb = try PhotoSize(json.data("thumb") as JsonObject) end
        file_name = try json.data("file_name") as String end
        mime_type = try json.data("mime_type") as String end
        file_size = try json.data("file_size") as I64 end

// Placeholder, holds no info yet
class CallbackGame is TelegramObject
    new create(json: JsonObject) =>
        """"""

class GameHighScore is TelegramObject
    var position: I64
    var user: User
    var score: I64

    new create(json: JsonObject) ? =>
        position = json.data("position") as I64
        user = User(json.data("user") as JsonObject)
        score = json.data("score") as I64


type ReplyMarkup is (InlineKeyboardMarkup | ReplyKeyboardMarkup | ReplyKeyboardRemove | ForceReply)
*/


/*
type ChatType is (Private | Group | SuperGroup | Channel)
... primitives
*/

/*
type MessageEntityType is (Mention | Hashtag | BotCommand | Url | Email | Bold | Italic | Code | Pre | TextLink | TextMention)
... primitives
*/

/*
type ParseModeType is (Markdown | HTML)
... primitives
*/
