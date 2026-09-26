class_name SpriteDb
## Serves textures by name: atlas regions from assets/sprites/manifest.json, our own PNGs from
## assets/sprites/ui, and a loud placeholder for anything missing so gaps are visible, not fatal.

const MANIFEST := "res://assets/sprites/manifest.json"
const SHEETS := "res://assets/sprites/sheets/"
const UI := "res://assets/sprites/ui/"
const ROOT := "res://assets/sprites/"

static var _manifest := {}
static var _loaded := false
static var _cache := {}
static var _sheets := {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(MANIFEST):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if typeof(parsed) == TYPE_DICTIONARY:
			_manifest = parsed


static func has(name: String) -> bool:
	_ensure()
	return _manifest.has(name)


## Sprite from the manifest. `frame` 1 returns the second animation frame when there is one.
static func sprite(name: String, frame := 0) -> Texture2D:
	_ensure()
	var key := "%s#%d" % [name, frame]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D
	if _manifest.has(name) and _manifest[name].has("file"):
		var path := ROOT + str(_manifest[name]["file"])
		if ResourceLoader.exists(path):
			tex = load(path)
	elif _manifest.has(name):
		var def: Dictionary = _manifest[name]
		var sheet_name: String = str(def.get("sheet", ""))
		if frame == 1 and def.get("anim_sheet") != null and str(def.get("anim_sheet")) != "":
			sheet_name = str(def["anim_sheet"])
		var sheet := _sheet(sheet_name)
		if sheet != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(def.get("x", 0), def.get("y", 0), def.get("w", 16), def.get("h", 16))
			tex = atlas
	if tex == null:
		tex = _placeholder(name)
	_cache[key] = tex
	return tex


static func flip_h(name: String) -> bool:
	_ensure()
	return bool(_manifest.get(name, {}).get("flip_h", false))


## One of our generated UI images by file name without extension.
static func ui(name: String) -> Texture2D:
	var key := "ui:" + name
	if _cache.has(key):
		return _cache[key]
	var path := UI + name + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		tex = _placeholder(name)
	_cache[key] = tex
	return tex


static func _sheet(file: String) -> Texture2D:
	if file == "":
		return null
	if _sheets.has(file):
		return _sheets[file]
	var path := SHEETS + file
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sheets[file] = tex
	return tex


static func _placeholder(name: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var h := name.hash()
	var c := Color.from_hsv(float(h % 360) / 360.0, 0.6, 0.85)
	img.fill(c)
	img.fill_rect(Rect2i(0, 0, 16, 1), Color.BLACK)
	img.fill_rect(Rect2i(0, 15, 16, 1), Color.BLACK)
	img.fill_rect(Rect2i(0, 0, 1, 16), Color.BLACK)
	img.fill_rect(Rect2i(15, 0, 1, 16), Color.BLACK)
	return ImageTexture.create_from_image(img)
