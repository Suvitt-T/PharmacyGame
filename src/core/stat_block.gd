class_name StatBlock
extends Resource

## Stat หลัก 4 ตัว เก็บเป็น float เพราะ Class Growth Bonus มีค่า +0.5 ต่อเลเวล

const KEYS := ["strength", "intellect", "vitality", "agility"]

@export var strength: float = 0.0
@export var intellect: float = 0.0
@export var vitality: float = 0.0
@export var agility: float = 0.0


static func make(p_strength: float, p_intellect: float, p_vitality: float, p_agility: float) -> StatBlock:
	var block := StatBlock.new()
	block.strength = p_strength
	block.intellect = p_intellect
	block.vitality = p_vitality
	block.agility = p_agility
	return block


static func uniform(value: float) -> StatBlock:
	return StatBlock.make(value, value, value, value)


func get_stat(key: String) -> float:
	return get(key)


func set_stat(key: String, value: float) -> void:
	set(key, value)


func add_stat(key: String, amount: float) -> void:
	set(key, get(key) + amount)


func total() -> float:
	return strength + intellect + vitality + agility


func plus(other: StatBlock) -> StatBlock:
	return StatBlock.make(
		strength + other.strength,
		intellect + other.intellect,
		vitality + other.vitality,
		agility + other.agility
	)


func scaled(factor: float) -> StatBlock:
	return StatBlock.make(strength * factor, intellect * factor, vitality * factor, agility * factor)


func clone() -> StatBlock:
	return StatBlock.make(strength, intellect, vitality, agility)


func to_dict() -> Dictionary:
	return {"strength": strength, "intellect": intellect, "vitality": vitality, "agility": agility}


static func from_dict(data: Dictionary) -> StatBlock:
	var block := StatBlock.new()
	for key in KEYS:
		block.set(key, float(data.get(key, 0.0)))
	return block


func _to_string() -> String:
	return "STR %.1f / INT %.1f / VIT %.1f / AGI %.1f" % [strength, intellect, vitality, agility]
