class_name Ingredient
extends RefCounted

## วัตถุดิบดิบ 1 ชนิด และตัวคูณ Potency ตามแหล่งที่เก็บ
## เอกสารระบุว่า Potency ต่างกันตามอายุพืช ฤดูกาล และไบโอม แต่ไม่ให้ตัวเลข
## ตัวเลขด้านล่างตัดสินใจเอง คุมช่วงรวมไว้ที่ 0.5-2.0 เพื่อไม่ให้การเก็บวัตถุดิบกลบการคำนวณขนาดยา

enum Maturity { YOUNG, MATURE, ANCIENT }
enum Season { DORMANT, GROWING, PEAK }

const MATURITY_FACTOR := {
	Maturity.YOUNG: 0.70,
	Maturity.MATURE: 1.00,
	Maturity.ANCIENT: 1.15,
}

const SEASON_FACTOR := {
	Season.DORMANT: 0.85,
	Season.GROWING: 1.00,
	Season.PEAK: 1.20,
}

const IDEAL_BIOME_FACTOR := 1.35
const VALID_BIOME_FACTOR := 1.00
const WRONG_BIOME_FACTOR := 0.60

const MIN_POTENCY := 0.5
const MAX_POTENCY := 2.0

var id: String = ""
var display_name: String = ""
var substance_id: String = ""
var yield_per_unit: float = 1.0
var biomes: Array = []
var ideal_biome: String = ""
var lore: String = ""


static func from_dict(ingredient_id: String, data: Dictionary) -> Ingredient:
	var ingredient := Ingredient.new()
	ingredient.id = ingredient_id
	ingredient.display_name = str(data.get("display_name", ingredient_id))
	ingredient.substance_id = str(data.get("substance", ""))
	ingredient.yield_per_unit = float(data.get("yield_per_unit", 1.0))
	ingredient.biomes = data.get("biomes", [])
	ingredient.ideal_biome = str(data.get("ideal_biome", ""))
	ingredient.lore = str(data.get("lore", ""))
	return ingredient


func biome_factor(biome: String) -> float:
	if biome == ideal_biome:
		return IDEAL_BIOME_FACTOR
	if biomes.has(biome):
		return VALID_BIOME_FACTOR
	return WRONG_BIOME_FACTOR


func potency(biome: String, maturity: Maturity, season: Season) -> float:
	var value: float = biome_factor(biome) * float(MATURITY_FACTOR[maturity]) * float(SEASON_FACTOR[season])
	return clampf(value, MIN_POTENCY, MAX_POTENCY)


## ปริมาณสารออกฤทธิ์ที่ได้จากวัตถุดิบ 1 ชิ้น ก่อนหักประสิทธิภาพการเตรียม
func substance_yield(potency_value: float) -> float:
	return yield_per_unit * potency_value
