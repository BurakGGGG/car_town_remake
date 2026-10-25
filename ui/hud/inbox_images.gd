class_name InboxImages
extends Node
## HABERLER kutusunun kapak resimleri (2026-10-25): panelin yüklediği resim (Firebase Storage) bir kez indirilir,
## user://news_img/'de saklanır (sonraki açılışta internetsiz de görünür), bellekte doku olarak tutulur. Sıra tek tek
## gider; adres NewsFeed.clean_image'dan geçmiş olmalı (yalnız izinli https sunucuları). Bozuk / çok büyük dosya atlanır.

signal loaded(url: String, texture: Texture2D)

const DIR: String = "user://news_img/"
const MAX_BYTES: int = 2_000_000
## Kutuda en büyük kapak ~300 tuval birimi: daha geniş resim bellekte küçültülür.
const MAX_WIDTH: int = 640
const TIMEOUT_SEC: float = 15.0

var _textures: Dictionary = {}   # adres → Texture2D
var _failed: Dictionary = {}     # adres → true (bu oturumda yeniden denenmez)
var _queue: Array[String] = []
var _current: String = ""
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	_http.body_size_limit = MAX_BYTES
	_http.request_completed.connect(_on_completed)
	add_child(_http)


## Hazırsa doku; değilse null döner ve indirme sıraya girer (bitince `loaded`).
func get_texture(url: String) -> Texture2D:
	if url.is_empty() or _failed.has(url):
		return null
	if _textures.has(url):
		return _textures[url]
	var cached: Texture2D = _from_bytes(_read_cache(url))
	if cached:
		_textures[url] = cached
		return cached
	if url != _current and not _queue.has(url):
		_queue.append(url)
		_next()
	return null


func _next() -> void:
	if not _current.is_empty() or _queue.is_empty() or _http == null:
		return
	_current = _queue.pop_front()
	if _http.request(_current) != OK:
		_failed[_current] = true
		_current = ""
		_next()


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var url: String = _current
	_current = ""
	var texture: Texture2D = _from_bytes(body) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if texture:
		_textures[url] = texture
		_write_cache(url, body)
		loaded.emit(url, texture)
	else:
		_failed[url] = true
	_next()


## PNG / JPEG / WebP (dosya imzasından); geniş resim MAX_WIDTH'e küçültülür.
static func _from_bytes(bytes: PackedByteArray) -> Texture2D:
	if bytes.size() < 12 or bytes.size() > MAX_BYTES:
		return null
	var image: Image = Image.new()
	var err: Error = ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = image.load_webp_from_buffer(bytes)
	if err != OK or image.is_empty():
		return null
	if image.get_width() > MAX_WIDTH:
		image.resize(MAX_WIDTH, maxi(int(image.get_height() * float(MAX_WIDTH) / image.get_width()), 1), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)


static func _path(url: String) -> String:
	return DIR + url.sha256_text() + ".img"


static func _read_cache(url: String) -> PackedByteArray:
	var path: String = _path(url)
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


static func _write_cache(url: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file: FileAccess = FileAccess.open(_path(url), FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
