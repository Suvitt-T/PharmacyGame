class_name PharmacyDB
extends RefCounted

## โหลดตารางสารออกฤทธิ์และวัตถุดิบจาก JSON
## เก็บข้อมูลบาลานซ์ไว้นอกโค้ด จะได้ปรับค่าโดยไม่ต้องแตะสคริปต์

const SUBSTANCE_PATH := "res://data/substances.json"
const INGREDIENT_PATH := "res://data/ingredients.json"

static var _substances: Dictionary = {}
static var _ingredients: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for entry in _read_json(SUBSTANCE_PATH):
		_substances[entry[0]] = Substance.from_dict(entry[0], entry[1])
	for entry in _read_json(INGREDIENT_PATH):
		_ingredients[entry[0]] = Ingredient.from_dict(entry[0], entry[1])


static func _read_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("เปิดไฟล์ข้อมูลไม่ได้: %s" % path)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("รูปแบบ JSON ไม่ถูกต้อง: %s" % path)
		return []
	var rows := []
	for key in parsed:
		if key.begins_with("_"):
			continue
		rows.append([key, parsed[key]])
	return rows


static func substance(substance_id: String) -> Substance:
	ensure_loaded()
	return _substances.get(substance_id, null)


static func ingredient(ingredient_id: String) -> Ingredient:
	ensure_loaded()
	return _ingredients.get(ingredient_id, null)


static func all_substances() -> Array:
	ensure_loaded()
	return _substances.values()


static func all_ingredients() -> Array:
	ensure_loaded()
	return _ingredients.values()


static func ingredients_in_biome(biome: String) -> Array:
	ensure_loaded()
	var found := []
	for item in _ingredients.values():
		if item.biomes.has(biome):
			found.append(item)
	return found


## หาสารที่แก้สถานะนี้ได้ตรงกลไก ใช้ในระบบยาแก้พิษและเควสวินิจฉัยอาการ
static func antidotes_for(status: String) -> Array:
	ensure_loaded()
	var found := []
	for item in _substances.values():
		if item.counters(status):
			found.append(item)
	return found
