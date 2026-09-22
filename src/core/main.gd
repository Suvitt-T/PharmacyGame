extends Node3D

## Sandbox ทดสอบ Phase 1: เดิน ตี รับดาเมจ ได้ XP เลเวลอัพ

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const DEBUG_XP_PER_PRESS := 250

const PLAYER_SPAWN := Vector3(6, 1, 16)

## ศัตรูรากต้นไม้โลก (Prologue/Act 1) ตามเอกสาร จับคู่กับโมเดลที่ใกล้เคียงที่สุดในแพ็กที่มี
const SPAWN_TABLE := [
	{"name": "หมาป่าเถื่อน", "model": "Monkroose", "scale": 0.45, "tier": "common", "at": Vector3(10, 1, 12)},
	{"name": "ค้างคาวรากเน่า", "model": "Birb", "scale": 0.40, "tier": "common", "at": Vector3(-11, 1, 13)},
	{"name": "ผึ้งพิษราก", "model": "Frog", "scale": 0.38, "tier": "common", "at": Vector3(-4, 1, 21)},
	{"name": "หมีรากเฒ่า", "model": "Yeti", "scale": 0.60, "tier": "elite", "at": Vector3(7, 1, 22)},
]

@onready var player: PlayerController = $Player
@onready var hud: Hud = $Hud
@onready var enemy_root: Node3D = $Enemies
@onready var hub: HubWorld = $HubWorld


func _ready() -> void:
	InputActions.ensure_registered()
	_build_world()
	player.add_to_group("player")
	player.combatant.sheet.character_name = "ผู้ตื่น"
	hud.bind_player(player.combatant)
	player.combatant.damage_taken.connect(_on_player_damaged)
	player.combatant.died.connect(_on_player_died)
	_spawn_wave()


func _build_world() -> void:
	player.global_position = PLAYER_SPAWN
	hub.reserve(PLAYER_SPAWN, 6.0)
	for entry in SPAWN_TABLE:
		hub.reserve(entry["at"], 4.0)
	hub.build()


func _spawn_wave() -> void:
	for entry in SPAWN_TABLE:
		_spawn_enemy(entry)


func _spawn_enemy(entry: Dictionary) -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.display_name = entry["name"]
	enemy.tier = entry["tier"]
	if entry["tier"] == "elite":
		enemy.xp_reward = 120
		enemy.move_speed = 2.6
	# ต้องตั้งก่อน add_child เพราะ ActorVisuals สร้างโมเดลตอน _ready
	var visuals: ActorVisuals = enemy.get_node("Visuals")
	visuals.model_scene = load("res://assets/models/monsters/%s.gltf" % entry["model"])
	visuals.model_scale = entry["scale"]
	enemy_root.add_child(enemy)
	enemy.global_position = entry["at"]
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Enemy) -> void:
	var gained := player.combatant.sheet.add_xp(enemy.xp_reward)
	hud.log_line("ปราบ %s · +%d XP" % [enemy.display_name, enemy.xp_reward])
	if gained > 0:
		hud.log_line("แต้ม Stat เหลือ %d แต้ม" % player.combatant.sheet.unspent_points())
	if enemy_root.get_child_count() <= 1:
		await get_tree().create_timer(2.0).timeout
		_spawn_wave()


func _on_player_damaged(amount: float, critical: bool) -> void:
	hud.log_line("โดนโจมตี %d%s" % [roundi(amount), " (คริติคอล)" if critical else ""])


func _on_player_died() -> void:
	hud.log_line("ผู้ตื่นล้มลง... กด R เพื่อฟื้น")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_add_xp"):
		player.combatant.sheet.add_xp(DEBUG_XP_PER_PRESS)
		_auto_allocate_points()
	elif event.is_action_pressed("debug_damage_self"):
		player.combatant.set_hp(player.combatant.current_hp - 40.0)
	elif event.is_action_pressed("debug_respec"):
		player.combatant.sheet.respec()
		player.combatant.restore_all()
		hud.log_line("Respec แล้ว คืนแต้มทั้งหมด")


## ชั่วคราวสำหรับ Phase 1 — Phase 4 จะมีหน้าจอแจกแต้มจริง
func _auto_allocate_points() -> void:
	var sheet := player.combatant.sheet
	var order := ["vitality", "strength", "agility", "intellect"]
	var index := 0
	while sheet.unspent_points() > 0:
		sheet.allocate(order[index % order.size()])
		index += 1
