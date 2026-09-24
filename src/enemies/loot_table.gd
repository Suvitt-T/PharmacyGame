class_name LootTable
extends RefCounted

## Loot Table ตามตารางในเอกสาร หัวข้อ "Loot Table (Common Tier)"

const COIN_CHANCE := 1.00
const COIN_MIN := 5
const COIN_MAX := 15
const COMMON_INGREDIENT_CHANCE := 0.60
const HIGH_POTENCY_CHANCE := 0.12
const RECIPE_CHANCE_COMMON := 0.03
const RECIPE_CHANCE_ELITE := 0.15
## โบนัสเพิ่มเติมเมื่อฆ่าด้วยสกิลพิษของนักพิษวิทยา
const VENOM_SAMPLE_BONUS := 0.08

## Potency ของวัตถุดิบที่ดรอป ไม่ระบุในเอกสาร ตัดสินใจเอง
const NORMAL_POTENCY := 1.0
const HIGH_POTENCY := 1.45

## โอกาสได้อุปกรณ์ ไม่ระบุในเอกสาร ตัดสินใจเอง — Common ไม่ค่อยดรอป Elite ขึ้นไปดรอปบ่อย
const EQUIPMENT_CHANCE := {"common": 0.10, "elite": 0.45, "miniboss": 1.00}
const EQUIPMENT_TIER_WEIGHT := {
	"common": [0.70, 0.25, 0.05, 0.00],
	"elite": [0.20, 0.45, 0.30, 0.05],
	"miniboss": [0.00, 0.25, 0.50, 0.25],
}


## คืนรายการของที่ดรอป แต่ละชิ้นเป็น Dictionary ที่มี kind บอกชนิด
static func roll(
	tier: String, biome: String, zone_level: int,
	killed_with_venom: bool, rng: RandomNumberGenerator
) -> Array:
	var drops := []

	if rng.randf() < COIN_CHANCE:
		drops.append({"kind": "coins", "amount": rng.randi_range(COIN_MIN, COIN_MAX)})

	var biome_ingredients := PharmacyDB.ingredients_in_biome(biome)
	if not biome_ingredients.is_empty():
		if rng.randf() < COMMON_INGREDIENT_CHANCE:
			var pick: Ingredient = biome_ingredients[rng.randi() % biome_ingredients.size()]
			drops.append({"kind": "ingredient", "id": pick.id, "count": 1, "potency": NORMAL_POTENCY})
		if rng.randf() < HIGH_POTENCY_CHANCE:
			var pick: Ingredient = biome_ingredients[rng.randi() % biome_ingredients.size()]
			drops.append({"kind": "ingredient", "id": pick.id, "count": 1, "potency": HIGH_POTENCY})

	var recipe_chance := RECIPE_CHANCE_ELITE if tier != "common" else RECIPE_CHANCE_COMMON
	if rng.randf() < recipe_chance:
		drops.append({"kind": "recipe", "id": _random_recipe(rng)})

	## ตัวอย่างพิษได้เฉพาะตอนฆ่าด้วยสกิลพิษ เป็นโอกาสเพิ่มเติมจากของปกติ
	if killed_with_venom and rng.randf() < VENOM_SAMPLE_BONUS:
		drops.append({"kind": "venom_sample", "count": 1})

	if rng.randf() < float(EQUIPMENT_CHANCE.get(tier, 0.10)):
		drops.append({
			"kind": "equipment",
			"base_id": _random_equipment_base(rng),
			"tier": _weighted_tier(tier, rng),
			"item_level": maxi(zone_level, 1),
		})

	return drops


static func _random_recipe(rng: RandomNumberGenerator) -> String:
	var ids := ItemDB.all_vial_ids()
	return str(ids[rng.randi() % ids.size()]) if not ids.is_empty() else ""


static func _random_equipment_base(rng: RandomNumberGenerator) -> String:
	var ids := ItemDB.all_equipment_ids()
	return str(ids[rng.randi() % ids.size()]) if not ids.is_empty() else ""


static func _weighted_tier(enemy_tier: String, rng: RandomNumberGenerator) -> ItemTier.Tier:
	var weights: Array = EQUIPMENT_TIER_WEIGHT.get(enemy_tier, EQUIPMENT_TIER_WEIGHT["common"])
	var roll_value := rng.randf()
	var running := 0.0
	for index in range(weights.size()):
		running += float(weights[index])
		if roll_value <= running:
			return index as ItemTier.Tier
	return ItemTier.Tier.COMMON


## ใส่ของที่ดรอปลงกระเป๋าผู้เล่น คืนข้อความสรุปไว้แสดงใน HUD
static func grant(drops: Array, component: InventoryComponent) -> Array:
	var lines := []
	for drop in drops:
		match str(drop["kind"]):
			"coins":
				component.inventory.add_coins(int(drop["amount"]))
				lines.append("+%d RC" % int(drop["amount"]))
			"ingredient":
				var ingredient := PharmacyDB.ingredient(str(drop["id"]))
				var potency := float(drop["potency"])
				component.inventory.add_ingredient(str(drop["id"]), int(drop["count"]), potency)
				var grade := " (Potency สูง)" if potency > NORMAL_POTENCY else ""
				lines.append("+%s x%d%s" % [ingredient.display_name, int(drop["count"]), grade])
			"recipe":
				var recipe_name := str(ItemDB.vial(str(drop["id"])).get("display_name", drop["id"]))
				component.inventory.add_quest_item("recipe:" + str(drop["id"]))
				lines.append("สูตรใหม่: %s" % recipe_name)
			"venom_sample":
				component.inventory.add_quest_item("venom_sample")
				lines.append("ได้ตัวอย่างพิษ")
			"equipment":
				var equipment := ItemDB.roll_equipment(
					str(drop["base_id"]), drop["tier"], int(drop["item_level"])
				)
				if equipment != null and component.inventory.add_equipment(equipment):
					lines.append(equipment.display_name())
				else:
					lines.append("กระเป๋าเต็ม ของตกพื้น")
	return lines
