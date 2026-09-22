class_name Remedy
extends RefCounted

## ยาที่ปรุงเสร็จแล้ว 1 ขนาน เก็บขนาดยาดิบที่ได้หลังหักประสิทธิภาพการเตรียม
## bioavailability ยังไม่ถูกหักตรงนี้ เพราะจะหักตอนให้ยาตาม route

var substance_id: String = ""
var raw_dose: float = 0.0
var method: Preparation.Method = Preparation.Method.DECOCTION
var potency: float = 1.0
var unit_count: int = 1
var ingredient_id: String = ""


static func craft(
	p_ingredient_id: String,
	p_unit_count: int,
	p_method: Preparation.Method,
	p_potency: float = 1.0
) -> Remedy:
	var ingredient := PharmacyDB.ingredient(p_ingredient_id)
	if ingredient == null:
		return null
	var substance := PharmacyDB.substance(ingredient.substance_id)
	if substance == null:
		return null

	var remedy := Remedy.new()
	remedy.ingredient_id = p_ingredient_id
	remedy.substance_id = ingredient.substance_id
	remedy.method = p_method
	remedy.potency = p_potency
	remedy.unit_count = maxi(p_unit_count, 0)
	remedy.raw_dose = (
		ingredient.substance_yield(p_potency)
		* float(remedy.unit_count)
		* substance.efficiency_for(p_method)
	)
	return remedy


func substance() -> Substance:
	return PharmacyDB.substance(substance_id)


func route() -> Pharmacokinetics.Route:
	return Preparation.route_of(method)


## เตรียมยาผิดวิธีจนไม่ได้สารออกฤทธิ์เลย
func is_inert() -> bool:
	var source := PharmacyDB.ingredient(ingredient_id)
	if source == null:
		return true
	return substance().efficiency_for(method) < Preparation.FAILED_EFFICIENCY


func display_name() -> String:
	var source := PharmacyDB.ingredient(ingredient_id)
	var source_name := source.display_name if source != null else substance_id
	return "%s (%s)" % [source_name, Preparation.display_name(method)]


## ประเมินผลของยาขนานนี้เมื่อให้กับร่างที่มี INT เท่านี้
## dose_multiplier รับผลจากปฏิกิริยาระหว่างยาที่กำลังออกฤทธิ์อยู่
func evaluate(intellect: float = 0.0, dose_multiplier: float = 1.0) -> Dictionary:
	var substance_data := substance()
	var effective := Pharmacokinetics.effective_dose(raw_dose, route()) * dose_multiplier
	var toxic_threshold := Pharmacokinetics.widened_toxic_dose(substance_data.toxic_dose, intellect)
	var zone := Pharmacokinetics.effect_zone(effective, substance_data.effective_dose, toxic_threshold)
	var dose_ratio := effective / substance_data.effective_dose if substance_data.effective_dose > 0.0 else 0.0

	return {
		"substance_id": substance_id,
		"effective_dose": effective,
		"dose_ratio": dose_ratio,
		"zone": zone,
		"toxic_threshold": toxic_threshold,
		"onset": Pharmacokinetics.onset_seconds(substance_data.base_onset_seconds, route(), potency),
		"duration": Pharmacokinetics.duration_seconds(substance_data.half_life_seconds, dose_ratio),
		"unit": substance_data.unit,
	}
