class_name Equipment
extends RefCounted

## อุปกรณ์ 1 ชิ้นที่สุ่มออกมาแล้ว
## FinalStat = BaseStat(itemLevel) x TierMultiplier x (1 + ΣAffixBonus%) ตามเอกสาร
## โดย Σ นับเฉพาะ affix ที่ตรงกับ scaling_stat ของอุปกรณ์ ให้ตรงกับตัวอย่างคำนวณ

var base_id: String = ""
var tier: ItemTier.Tier = ItemTier.Tier.COMMON
var item_level: int = 1
var affixes: Array[Affix] = []
var vials: Array[String] = []


func definition() -> Dictionary:
	return ItemDB.equipment_base(base_id)


func display_name() -> String:
	return "%s [%s]" % [str(definition().get("display_name", base_id)), ItemTier.display_name(tier)]


func slot() -> String:
	return str(definition().get("slot", "weapon"))


func kind() -> String:
	return str(definition().get("kind", "weapon"))


func scaling_stat() -> String:
	return str(definition().get("scaling_stat", "strength"))


func is_weapon() -> bool:
	return kind() == "weapon"


func base_value() -> float:
	if is_weapon():
		return Formulas.weapon_base_damage(item_level)
	return Formulas.armor_base_defense(item_level)


## รวมเฉพาะ affix ที่ตรงกับ scaling_stat เข้าสูตร ตามที่ตัวอย่างในเอกสารคำนวณไว้
func scaling_affix_percent() -> float:
	var total := 0.0
	for affix in affixes:
		if affix.stat == scaling_stat():
			total += affix.percent
	return total


func final_value() -> float:
	return base_value() * ItemTier.multiplier(tier) * (1.0 + scaling_affix_percent() / 100.0)


func weapon_damage() -> float:
	return final_value() if is_weapon() else 0.0


func defense() -> float:
	return 0.0 if is_weapon() else final_value()


## affix พิเศษให้ผลตรง ๆ ไม่ผ่านสูตร FinalStat
func crit_bonus_percent() -> float:
	return _special_total("crit")


func evasion_bonus_percent() -> float:
	return _special_total("evasion")


func _special_total(stat: String) -> float:
	var total := 0.0
	for affix in affixes:
		if affix.stat == stat:
			total += affix.percent
	return total


## affix ที่เป็น Stat หลักแต่ไม่ใช่ scaling_stat ของชิ้นนี้ ให้เป็นแต้ม Stat ตรง ๆ
## เพื่อไม่ให้ค่ามันหายไปเฉย ๆ และไม่ไปซ้อนกับสูตร FinalStat
func stat_bonus() -> StatBlock:
	var block := StatBlock.new()
	for affix in affixes:
		if affix.is_primary() and affix.stat != scaling_stat():
			block.add_stat(affix.stat, affix.percent * 0.5)
	for vial_id in vials:
		var vial := ItemDB.vial(vial_id)
		if vial.is_empty():
			continue
		var effect: Dictionary = vial["effect"]
		if str(effect.get("kind", "")) == "stat_bonus":
			block.add_stat(str(effect.get("stat", "strength")), float(effect.get("magnitude", 0.0)))
	return block


func vial_slots() -> int:
	return ItemTier.vial_slots(tier)


func free_vial_slots() -> int:
	return vial_slots() - vials.size()


func insert_vial(vial_id: String) -> bool:
	if free_vial_slots() <= 0 or ItemDB.vial(vial_id).is_empty():
		return false
	vials.append(vial_id)
	return true


## รวมผลของหลอดสารสกัดที่เสียบอยู่ ที่ไม่ใช่ stat_bonus
func vial_effects() -> Array:
	var effects := []
	for vial_id in vials:
		var vial := ItemDB.vial(vial_id)
		if not vial.is_empty():
			effects.append(vial["effect"])
	return effects


func to_text() -> String:
	var lines := [display_name(), "  iLv %d · %s %.1f" % [
		item_level, "ดาเมจ" if is_weapon() else "ป้องกัน", final_value()
	]]
	for affix in affixes:
		lines.append("  " + affix.to_text())
	for vial_id in vials:
		lines.append("  ◆ " + str(ItemDB.vial(vial_id).get("display_name", vial_id)))
	return "\n".join(lines)


func to_dict() -> Dictionary:
	var affix_data := []
	for affix in affixes:
		affix_data.append(affix.to_dict())
	return {
		"base_id": base_id,
		"tier": int(tier),
		"item_level": item_level,
		"affixes": affix_data,
		"vials": vials.duplicate(),
	}


static func from_dict(data: Dictionary) -> Equipment:
	var equipment := Equipment.new()
	equipment.base_id = str(data.get("base_id", ""))
	equipment.tier = int(data.get("tier", 0)) as ItemTier.Tier
	equipment.item_level = int(data.get("item_level", 1))
	for affix_data in data.get("affixes", []):
		equipment.affixes.append(Affix.from_dict(affix_data))
	for vial_id in data.get("vials", []):
		equipment.vials.append(str(vial_id))
	return equipment
