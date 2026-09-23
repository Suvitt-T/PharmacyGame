class_name ItemDB
extends RefCounted

## โหลดฐานอุปกรณ์และหลอดสารสกัดจาก JSON และสุ่มอุปกรณ์ออกมา

const EQUIPMENT_PATH := "res://data/equipment_bases.json"
const VIAL_PATH := "res://data/vials.json"

static var _equipment_bases: Dictionary = {}
static var _vials: Dictionary = {}
static var _slots: Array = []
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var equipment_data := _read_json(EQUIPMENT_PATH)
	_slots = equipment_data.get("_slots", [])
	for key in equipment_data:
		if not key.begins_with("_"):
			_equipment_bases[key] = equipment_data[key]
	var vial_data := _read_json(VIAL_PATH)
	for key in vial_data:
		if not key.begins_with("_"):
			_vials[key] = vial_data[key]


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("เปิดไฟล์ข้อมูลไม่ได้: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("รูปแบบ JSON ไม่ถูกต้อง: %s" % path)
		return {}
	return parsed


static func equipment_base(base_id: String) -> Dictionary:
	ensure_loaded()
	return _equipment_bases.get(base_id, {})


static func vial(vial_id: String) -> Dictionary:
	ensure_loaded()
	return _vials.get(vial_id, {})


static func all_equipment_ids() -> Array:
	ensure_loaded()
	return _equipment_bases.keys()


static func all_vial_ids() -> Array:
	ensure_loaded()
	return _vials.keys()


static func slots() -> Array:
	ensure_loaded()
	return _slots


static func bases_for_slot(slot: String) -> Array:
	ensure_loaded()
	var found := []
	for base_id in _equipment_bases:
		if str(_equipment_bases[base_id].get("slot", "")) == slot:
			found.append(base_id)
	return found


## สุ่มอุปกรณ์ 1 ชิ้น จำนวน affix มาจาก Tier ตามตารางในเอกสาร
static func roll_equipment(
	base_id: String, tier: ItemTier.Tier, item_level: int, rng: RandomNumberGenerator = null
) -> Equipment:
	ensure_loaded()
	if not _equipment_bases.has(base_id):
		return null
	var generator := rng
	if generator == null:
		generator = RandomNumberGenerator.new()
		generator.randomize()

	var equipment := Equipment.new()
	equipment.base_id = base_id
	equipment.tier = tier
	equipment.item_level = maxi(item_level, 1)
	for index in range(ItemTier.affix_slots(tier)):
		equipment.affixes.append(Affix.roll(generator))
	return equipment


## คราฟต์หลอดสารสกัดจากวัตถุดิบชุดเดียวกับระบบยา
static func vial_cost(vial_id: String) -> Dictionary:
	var data := vial(vial_id)
	if data.is_empty():
		return {}
	return {"ingredient": str(data["ingredient"]), "units": int(data["units_required"])}
