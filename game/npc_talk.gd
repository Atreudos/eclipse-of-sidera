class_name NpcTalk
extends RefCounted
## Konuşulan karakterlerin tanımları ve konuşma metinleri. Metinler taslaktır; hikâye belgesi onaylanınca genişler.

const NPCS := {
	"mira": {"name": "Mira", "title": "Fener Bekçisi", "tint": Color(1.0, 0.8, 0.4)},
}


static func ids() -> Array:
	return NPCS.keys()


static func display_name(id: String) -> String:
	return str((NPCS.get(id, {}) as Dictionary).get("name", id))


static func tint(id: String) -> Color:
	return (NPCS.get(id, {}) as Dictionary).get("tint", Color(0.6, 0.7, 1.0))


## Karakterin şu anki konuşması (bayraklara göre).
static func dialogue(id: String) -> Dictionary:
	match id:
		"mira":
			return _mira()
	return Dialogue.linear(display_name(id), ["..."])


static func _mira() -> Dictionary:
	if not Story.has("mira_met"):
		return {"speaker": "Mira", "start": "a", "nodes": {
			"a": {"text": "Bir ışık daha. Uzun zamandır kimse bu kadar yukarı çıkamamıştı.", "next": "b"},
			"b": {"text": "Ben Mira. Bu fenerlerin bekçisiyim. Sönmesinler diye buradayım.", "next": "c"},
			"c": {"text": "Aşağıda seni bekleyen bir gölge var. Yüzünü tanıyacaksın.", "choices": [
				{"text": "Gölge mi? Kim o?", "next": "d"},
				{"text": "Beni ilgilendirmez.", "next": "e"},
			]},
			"d": {"text": "Umbra. Senden geri kalan her şey o. Şimdilik bu kadar; yükseldikçe öğrenirsin.", "next": "end", "set": "mira_met"},
			"e": {"text": "Öyle der herkes. Sonra aynaya bakar.", "next": "end", "set": "mira_met"},
		}}
	if Story.has("mira_floor_talk_%d" % int(Story.get_flag("floor_seen", 1))):
		return Dialogue.linear("Mira", ["Fenerler yanıyor. Devam et, Sidera."])
	return Dialogue.linear("Mira", ["Yine geldin. Fenerler seni tanıyor.", "Dikkatli ol. Gölge her katta biraz daha güçleniyor."], "mira_floor_talk_%d" % int(Story.get_flag("floor_seen", 1)))
