class_name GameMode
extends RefCounted
## Oyun kipleri.
##   NORMAL    Katlar, her katın başında düşmansız lobi ve dükkân, kayıtlı koşu.
##   SINIRSIZ  Geniş bir arenada bitmeyen dalgalar; 5/10/25/50/75/100. dalgalarda dükkân.

enum Kind { NORMAL, ENDLESS }

const DEFAULT := Kind.NORMAL
## Kayıt dosyasındaki anahtarlar.
const KEYS := ["normal", "endless"]
## Menüde görünen adlar.
const NAMES := ["NORMAL", "SINIRSIZ"]
const BLURBS := [
	"Katlarda ilerle. Her katın başında dükkân ve hazırlık odası, sonra giderek zorlaşan odalar. Kaldığın yerden devam edersin.",
	"Geniş bir arenada bitmeyen dalgalar. Her dalgada daha çok ve daha güçlü düşman; arada dükkân. Ne kadar dayanırsın?",
]


static func count() -> int:
	return KEYS.size()


static func clamp_kind(kind: int) -> int:
	return clampi(kind, 0, KEYS.size() - 1)


static func key_of(kind: int) -> String:
	return KEYS[clamp_kind(kind)]


static func name_of(kind: int) -> String:
	return NAMES[clamp_kind(kind)]


static func blurb_of(kind: int) -> String:
	return BLURBS[clamp_kind(kind)]


static func from_key(key: String, fallback: int = DEFAULT) -> int:
	var i := KEYS.find(key)
	return i if i >= 0 else fallback
