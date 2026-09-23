class_name InventoryComponent
extends Node

## เชื่อมกระเป๋าและอุปกรณ์ที่สวมอยู่เข้ากับ Combatant
## ทุกครั้งที่ชุดเปลี่ยน จะคำนวณดาเมจอาวุธ ค่าป้องกัน และโบนัส Stat ใหม่

signal equipment_changed(slot: String, equipment: Equipment)

## ดาเมจติดตัวเมื่อไม่ได้ถืออาวุธ — เอกสารระบุว่าบทนำต่อสู้ด้วยมือเปล่าได้
@export var unarmed_damage: float = 6.0
@export var combatant_path: NodePath = NodePath("../Combatant")

var inventory := Inventory.new()
var loadout := Loadout.new()

var _combatant: Combatant


func _ready() -> void:
	ItemDB.ensure_loaded()
	_combatant = get_node_or_null(combatant_path) as Combatant
	loadout.changed.connect(_sync_to_combatant)
	_sync_to_combatant()


## สวมอุปกรณ์จากกระเป๋า ชิ้นเดิมในช่องนั้นเด้งกลับเข้ากระเป๋า
func equip_from_bag(bag_index: int) -> bool:
	if bag_index < 0 or bag_index >= inventory.bag.size():
		return false
	var entry := inventory.bag[bag_index]
	if entry["kind"] != "equipment":
		return false

	var equipment: Equipment = entry["item"]
	inventory.remove_slot(bag_index)
	var previous := loadout.equip(equipment)
	if previous != null:
		inventory.add_equipment(previous)
	equipment_changed.emit(equipment.slot(), equipment)
	return true


func unequip(slot: String) -> bool:
	var removed := loadout.unequip(slot)
	if removed == null:
		return false
	if not inventory.add_equipment(removed):
		# กระเป๋าเต็ม ใส่กลับไว้ที่เดิมดีกว่าทำหาย
		loadout.equip(removed)
		return false
	equipment_changed.emit(slot, null)
	return true


## ปรุงยาจากวัตถุดิบใน Herbarium แล้วเก็บเข้ากระเป๋า
func craft_remedy(ingredient_id: String, units: int, method: Preparation.Method) -> Remedy:
	if not inventory.has_ingredients(ingredient_id, units):
		return null
	var potency := 1.0
	var remedy := Remedy.craft(ingredient_id, units, method, potency)
	if remedy == null:
		return null
	inventory.consume_ingredients(ingredient_id, units)
	inventory.add_remedy(remedy)
	return remedy


## คราฟต์หลอดสารสกัดแล้วเสียบลงอุปกรณ์ที่สวมอยู่
func craft_and_insert_vial(vial_id: String, slot: String) -> bool:
	var cost := ItemDB.vial_cost(vial_id)
	if cost.is_empty():
		return false
	var target := loadout.item_in(slot)
	if target == null or target.free_vial_slots() <= 0:
		return false
	if not inventory.has_ingredients(cost["ingredient"], cost["units"]):
		return false
	if not target.insert_vial(vial_id):
		return false
	inventory.consume_ingredients(cost["ingredient"], cost["units"])
	loadout.changed.emit()
	return true


func _sync_to_combatant() -> void:
	if _combatant == null:
		return
	_combatant.weapon_base_damage = loadout.weapon_damage(unarmed_damage)
	_combatant.defense = loadout.total_defense()
	_combatant.sheet.equipment = loadout.total_stat_bonus()
	_combatant.sheet.stats_changed.emit()
