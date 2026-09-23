class_name Loadout
extends RefCounted

## อุปกรณ์ที่สวมอยู่ และค่ารวมที่ได้จากทั้งชุด
## เอกสารไม่ได้ระบุว่ามีช่องสวมใส่อะไรบ้าง ตัดสินใจเอง 6 ช่องตาม _slots ใน equipment_bases.json

signal changed()

var equipped: Dictionary = {}


func equip(equipment: Equipment) -> Equipment:
	if equipment == null:
		return null
	var slot := equipment.slot()
	var previous: Equipment = equipped.get(slot, null)
	equipped[slot] = equipment
	changed.emit()
	return previous


func unequip(slot: String) -> Equipment:
	if not equipped.has(slot):
		return null
	var removed: Equipment = equipped[slot]
	equipped.erase(slot)
	changed.emit()
	return removed


func item_in(slot: String) -> Equipment:
	return equipped.get(slot, null)


func all_items() -> Array[Equipment]:
	var items: Array[Equipment] = []
	for slot in equipped:
		items.append(equipped[slot])
	return items


## อาวุธชิ้นเดียวเท่านั้นที่ให้ค่าดาเมจฐาน
func weapon_damage(fallback: float = 0.0) -> float:
	var weapon := item_in("weapon")
	return weapon.weapon_damage() if weapon != null else fallback


func total_defense() -> float:
	var total := 0.0
	for item in all_items():
		total += item.defense()
	return total


func total_stat_bonus() -> StatBlock:
	var block := StatBlock.new()
	for item in all_items():
		block = block.plus(item.stat_bonus())
	return block


func total_crit_percent() -> float:
	var total := 0.0
	for item in all_items():
		total += item.crit_bonus_percent()
	return total


func total_evasion_percent() -> float:
	var total := 0.0
	for item in all_items():
		total += item.evasion_bonus_percent()
	return total


## ลดดาเมจต่อเนื่องที่ได้รับ มาจากหลอดสารสกัดที่เสียบใน Vial Slot
func dot_resistance() -> float:
	var total := 0.0
	for effect in _all_vial_effects():
		if str(effect.get("kind", "")) == "dot_resistance":
			total += float(effect.get("magnitude", 0.0))
	return clampf(total, 0.0, 0.9)


func status_resistance(status: String) -> float:
	var total := 0.0
	for effect in _all_vial_effects():
		if str(effect.get("kind", "")) != "status_resistance":
			continue
		if str(effect.get("status", "")) == status:
			total += float(effect.get("magnitude", 0.0))
	return clampf(total, 0.0, 0.9)


func vial_crit_percent() -> float:
	var total := 0.0
	for effect in _all_vial_effects():
		if str(effect.get("kind", "")) == "crit_percent":
			total += float(effect.get("magnitude", 0.0))
	return total


func total_vial_slots() -> int:
	var total := 0
	for item in all_items():
		total += item.vial_slots()
	return total


func _all_vial_effects() -> Array:
	var effects := []
	for item in all_items():
		effects.append_array(item.vial_effects())
	return effects
