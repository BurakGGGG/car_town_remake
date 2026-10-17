class_name LinkShare
## PAYLAŞIM (2026-10-17, arkadaş davet linki): Android'in paylaşım penceresi (WhatsApp, Mesajlar, Telegram…) —
## eklentisiz, Godot'nun JavaClassWrapper + AndroidRuntime köprüsüyle Intent.ACTION_SEND (GallerySaver gibi).
## Android değilse (PC) ya da pencere açılamazsa metin panoya kopyalanır.


## Metni paylaşır. Dönen: "shared" (paylaşım penceresi açıldı) ya da "copied" (panoya kopyalandı).
static func share(text: String, title: String) -> String:
	if OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime") and _share_android(text, title):
		return "shared"
	DisplayServer.clipboard_set(text)
	return "copied"


static func _share_android(text: String, title: String) -> bool:
	var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
	var intent_class: JavaClass = JavaClassWrapper.wrap("android.content.Intent")
	if activity == null or intent_class == null:
		return false
	var intent: Object = intent_class.call("Intent", "android.intent.action.SEND")
	if _java_failed() or intent == null:
		return false
	intent.call("setType", "text/plain")
	intent.call("putExtra", "android.intent.extra.TEXT", text)
	if _java_failed():
		return false
	var chooser: Object = intent_class.call("createChooser", intent, title)
	if _java_failed() or chooser == null:
		chooser = intent   # köprü başlığı CharSequence'e çeviremezse: seçicisiz (sistem yine uygulama sorar)
	activity.call("startActivity", chooser)
	return not _java_failed()


## Son Java çağrısı istisna attıysa günlüğe yazar ve true döner.
static func _java_failed() -> bool:
	var exception: JavaObject = JavaClassWrapper.get_exception()
	if exception == null:
		return false
	push_warning("LinkShare: %s" % str(exception.call("toString")))
	return true
