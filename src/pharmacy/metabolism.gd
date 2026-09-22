class_name Metabolism
extends Node

## ร่างกายของ actor 1 ตัวในแง่เภสัชวิทยา: รับยา เดินเวลา onset/duration แล้วลงผลจริง
## แยกจาก Combatant เพราะศัตรูบางตัวไม่ต้องมีระบบนี้ และเทสต์ระบบยาได้โดยไม่ต้องมีฉาก

signal remedy_administered(remedy: Remedy, evaluation: Dictionary)
signal effect_started(effect: ActiveEffect)
signal effect_ended(effect: ActiveEffect)
signal status_applied(status: String)
signal status_cleared(status: String)
signal interaction_triggered(rule: Dictionary)

## ไม่ระบุในเอกสาร ตัดสินใจเอง: สถานะที่ยาใส่ไว้คงอยู่นานเท่าฤทธิ์ยา
## ส่วนสถานะจากศัตรู (เช่น Blight DOT) มีเวลาของตัวเองที่ผู้เรียกกำหนด
const DEFAULT_STATUS_SECONDS := 8.0

@export var combatant_path: NodePath = NodePath("../Combatant")

var _combatant: Combatant
var _effects: Array[ActiveEffect] = []
var _statuses: Dictionary = {}
var _resistances: Dictionary = {}


func _ready() -> void:
	PharmacyDB.ensure_loaded()
	_combatant = get_node_or_null(combatant_path) as Combatant


func _process(delta: float) -> void:
	_tick_statuses(delta)
	_tick_effects(delta)


# --- การให้ยา ---

## ให้ยา 1 ขนาน คืนผลการประเมินเพื่อให้ UI แสดงโซน ED/TD ได้ทันที
func administer(remedy: Remedy) -> Dictionary:
	if remedy == null or remedy.is_inert():
		return {}

	var intellect := _combatant.sheet.final_stats().intellect if _combatant != null else 0.0
	var multiplier := Interaction.dose_multiplier_for(remedy.substance_id, active_substance_ids())
	var evaluation := remedy.evaluate(intellect, multiplier)

	if not is_equal_approx(multiplier, 1.0):
		for other_id in active_substance_ids():
			var rule := Interaction.find(remedy.substance_id, other_id)
			if not rule.is_empty():
				interaction_triggered.emit(rule)

	remedy_administered.emit(remedy, evaluation)

	var effect := ActiveEffect.from_evaluation(evaluation)
	if effect.is_inert():
		return evaluation
	_effects.append(effect)
	return evaluation


func active_substance_ids() -> Array:
	var ids := []
	for effect in _effects:
		if effect.phase == ActiveEffect.Phase.ACTIVE:
			ids.append(effect.substance_id)
	return ids


func active_effects() -> Array[ActiveEffect]:
	return _effects


func clear_all() -> void:
	for effect in _effects:
		_remove_effect(effect)
	_effects.clear()
	_statuses.clear()
	_resistances.clear()


# --- สถานะผิดปกติ ---

func apply_status(status: String, seconds: float = DEFAULT_STATUS_SECONDS) -> void:
	var resisted := float(_resistances.get(status, 0.0))
	var final_seconds := seconds * (1.0 - clampf(resisted, 0.0, 1.0))
	if final_seconds <= 0.0:
		return
	var already := _statuses.has(status)
	_statuses[status] = maxf(float(_statuses.get(status, 0.0)), final_seconds)
	if not already:
		status_applied.emit(status)


func clear_status(status: String) -> void:
	if not _statuses.has(status):
		return
	_statuses.erase(status)
	status_cleared.emit(status)


func has_status(status: String) -> bool:
	return _statuses.has(status)


func status_list() -> Array:
	return _statuses.keys()


func resistance_to(status: String) -> float:
	return float(_resistances.get(status, 0.0))


# --- เดินเวลา ---

func _tick_statuses(delta: float) -> void:
	for status in _statuses.keys():
		var remaining := float(_statuses[status]) - delta
		if remaining <= 0.0:
			clear_status(status)
		else:
			_statuses[status] = remaining


func _tick_effects(delta: float) -> void:
	var finished: Array[ActiveEffect] = []
	for effect in _effects:
		var was_pending := effect.phase == ActiveEffect.Phase.PENDING
		effect.advance(delta)
		if was_pending and effect.phase == ActiveEffect.Phase.ACTIVE:
			_start_effect(effect)
		elif effect.phase == ActiveEffect.Phase.ACTIVE:
			_tick_effect(effect, delta)
		elif effect.phase == ActiveEffect.Phase.FINISHED:
			finished.append(effect)

	for effect in finished:
		_remove_effect(effect)
		_effects.erase(effect)
		effect_ended.emit(effect)


func _start_effect(effect: ActiveEffect) -> void:
	var payload := effect.payload()
	var kind := str(payload.get("kind", ""))
	var magnitude := float(payload.get("magnitude", 0.0))
	var status := str(payload.get("status", ""))

	match kind:
		"cleanse_status":
			clear_status(status)
		"apply_status":
			apply_status(status, effect.duration_remaining)
		"resist_status":
			_resistances[status] = magnitude
		"stat_modifier":
			var stat_key := str(payload.get("stat", ""))
			if StatBlock.KEYS.has(stat_key) and _combatant != null:
				effect.applied_stat_key = stat_key
				effect.applied_stat_amount = magnitude
				_combatant.sheet.temporary.add_stat(stat_key, magnitude)
				_combatant.sheet.stats_changed.emit()

	effect_started.emit(effect)


func _tick_effect(effect: ActiveEffect, delta: float) -> void:
	if _combatant == null:
		return
	var payload := effect.payload()
	match str(payload.get("kind", "")):
		"regen_hp":
			_combatant.heal(float(payload["magnitude"]) * delta)
		"damage_over_time":
			_combatant.set_hp(_combatant.current_hp - float(payload["magnitude"]) * delta)


func _remove_effect(effect: ActiveEffect) -> void:
	if effect.applied_stat_key != "" and _combatant != null:
		_combatant.sheet.temporary.add_stat(effect.applied_stat_key, -effect.applied_stat_amount)
		_combatant.sheet.stats_changed.emit()
		effect.applied_stat_key = ""
	var payload := effect.payload()
	if str(payload.get("kind", "")) == "resist_status":
		_resistances.erase(str(payload.get("status", "")))
