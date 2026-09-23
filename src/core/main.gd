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
@onready var metabolism: Metabolism = $Player/Metabolism
@onready var inventory_component: InventoryComponent = $Player/InventoryComponent

## ยาตัวอย่างสำหรับทดลองระบบใน Phase 2 — หน้าจอปรุงยาจริงมาใน Phase 3
const TEST_REMEDIES := {
	"remedy_1": {"ingredient": "willow_bark", "units": 12, "method": Preparation.Method.DECOCTION},
	"remedy_2": {"ingredient": "willow_bark", "units": 400, "method": Preparation.Method.DECOCTION},
	"remedy_3": {"ingredient": "guarana_seed", "units": 8, "method": Preparation.Method.DECOCTION},
	"remedy_4": {"ingredient": "cinchona_bark", "units": 9, "method": Preparation.Method.DECOCTION},
	"remedy_5": {"ingredient": "foxglove_flower", "units": 4, "method": Preparation.Method.INJECTION_EXTRACT},
}


func _ready() -> void:
	InputActions.ensure_registered()
	_build_world()
	player.add_to_group("player")
	player.combatant.sheet.character_name = "ผู้ตื่น"
	hud.bind_player(player.combatant)
	hud.bind_inventory(inventory_component)
	player.combatant.damage_taken.connect(_on_player_damaged)
	player.combatant.died.connect(_on_player_died)
	metabolism.remedy_administered.connect(_on_remedy_administered)
	metabolism.interaction_triggered.connect(_on_interaction_triggered)
	metabolism.effect_ended.connect(_on_effect_ended)
	_give_starting_kit()
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
	elif event.is_action_pressed("debug_roll_loot"):
		_roll_loot()
	elif event.is_action_pressed("debug_insert_vial"):
		_insert_vial()
	elif _try_remedy(event):
		return
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


# --- ทดลองระบบเภสัชกรรม ---

func _try_remedy(event: InputEvent) -> bool:
	for action in TEST_REMEDIES:
		if not event.is_action_pressed(action):
			continue
		var recipe: Dictionary = TEST_REMEDIES[action]
		var remedy := Remedy.craft(recipe["ingredient"], recipe["units"], recipe["method"], 1.0)
		if remedy == null or remedy.is_inert():
			hud.log_line("ปรุงไม่สำเร็จ วิธีเตรียมไม่เข้ากับวัตถุดิบ")
			return true
		metabolism.administer(remedy)
		return true
	return false


func _on_remedy_administered(remedy: Remedy, evaluation: Dictionary) -> void:
	var substance: Substance = remedy.substance()
	hud.log_line("%s · %.2f %s · %s" % [
		remedy.display_name(),
		evaluation["effective_dose"],
		evaluation["unit"],
		Pharmacokinetics.zone_name(evaluation["zone"]),
	])
	if evaluation["zone"] == Pharmacokinetics.Zone.NO_EFFECT:
		hud.log_line("  ไม่ถึง ED %.2f %s จึงไม่ออกฤทธิ์" % [substance.effective_dose, substance.unit])
	else:
		hud.log_line("  ออกฤทธิ์ใน %.1f วิ นาน %.1f วิ" % [evaluation["onset"], evaluation["duration"]])


func _on_interaction_triggered(rule: Dictionary) -> void:
	hud.log_line("[%s] %s" % [Interaction.kind_name(rule["kind"]), rule["note"]])


func _on_effect_ended(effect: ActiveEffect) -> void:
	hud.log_line("%s หมดฤทธิ์" % effect.substance().display_name)


# --- ไอเทมและกระเป๋า ---

## ของเริ่มต้นสำหรับทดลองระบบ — ระบบเก็บของและร้านค้าจริงมาใน Phase ถัดไป
func _give_starting_kit() -> void:
	var inventory := inventory_component.inventory
	for ingredient in PharmacyDB.all_ingredients():
		inventory.add_ingredient((ingredient as Ingredient).id, 40)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for base_id in ["root_blade", "bark_cuirass", "bark_helm"]:
		inventory.add_equipment(ItemDB.roll_equipment(base_id, ItemTier.Tier.COMMON, 1, rng))
	while inventory_component.equip_from_bag(0):
		pass
	hud.log_line("ได้ชุดเริ่มต้นและวัตถุดิบครบ 8 ชนิด อย่างละ 40 ชิ้น")


func _roll_loot() -> void:
	var sheet := player.combatant.sheet
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tier: ItemTier.Tier = ItemTier.all()[rng.randi() % ItemTier.all().size()]
	var base_ids := ItemDB.all_equipment_ids()
	var base_id: String = base_ids[rng.randi() % base_ids.size()]
	var loot := ItemDB.roll_equipment(base_id, tier, sheet.level + 4, rng)

	var current := inventory_component.loadout.item_in(loot.slot())
	var is_upgrade := current == null or loot.final_value() > current.final_value()

	inventory_component.inventory.add_equipment(loot)
	hud.log_line("ดรอป: %s · %s %.1f" % [
		loot.display_name(), "ดาเมจ" if loot.is_weapon() else "ป้องกัน", loot.final_value()
	])
	for affix in loot.affixes:
		hud.log_line("   " + affix.to_text())

	if is_upgrade:
		inventory_component.equip_from_bag(inventory_component.inventory.bag.size() - 1)
		hud.log_line("   สวมใส่แล้ว (ดีกว่าของเดิม)")


func _insert_vial() -> void:
	for slot in ["weapon", "chest", "head"]:
		var item := inventory_component.loadout.item_in(slot)
		if item == null or item.free_vial_slots() <= 0:
			continue
		for vial_id in ItemDB.all_vial_ids():
			if inventory_component.craft_and_insert_vial(vial_id, slot):
				hud.log_line("เสียบ %s ลง %s" % [
					str(ItemDB.vial(vial_id)["display_name"]), item.display_name()
				])
				return
	hud.log_line("ไม่มีช่อง Vial ว่าง — ต้องของ Rare ขึ้นไป (กด E หาของใหม่)")
