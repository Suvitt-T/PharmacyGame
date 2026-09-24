class_name EnemyDB
extends RefCounted

## โหลดตารางศัตรูรายไบโอมจาก JSON

const ENEMY_PATH := "res://data/enemies.json"
const MODEL_PATH := "res://assets/models/monsters/%s.gltf"

static var _enemies: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(ENEMY_PATH, FileAccess.READ)
	if file == null:
		push_error("เปิดไฟล์ศัตรูไม่ได้: %s" % ENEMY_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("รูปแบบ JSON ของศัตรูไม่ถูกต้อง")
		return
	for key in parsed:
		if not key.begins_with("_"):
			_enemies[key] = parsed[key]


static func definition(enemy_id: String) -> Dictionary:
	ensure_loaded()
	return _enemies.get(enemy_id, {})


static func all_ids() -> Array:
	ensure_loaded()
	return _enemies.keys()


static func ids_in_biome(biome: String) -> Array:
	ensure_loaded()
	var found := []
	for key in _enemies:
		if str(_enemies[key].get("biome", "")) == biome:
			found.append(key)
	return found


static func model_scene(enemy_id: String) -> PackedScene:
	var data := definition(enemy_id)
	var model := str(data.get("model", ""))
	return load(MODEL_PATH % model) if not model.is_empty() else null


static func model_scale(enemy_id: String) -> float:
	return float(definition(enemy_id).get("scale", 0.45))
