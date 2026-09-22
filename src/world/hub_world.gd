class_name HubWorld
extends Node3D

## สร้างแผนที่ Hub "รากต้นไม้โลก" ด้วยโค้ด ใช้ seed คงที่ให้ผลเหมือนเดิมทุกครั้ง
## สร้างแบบ procedural แทนการวางมือใน editor เพราะปรับสมดุลและขยายไบโอมอื่นได้เร็วกว่า

const MODEL_PATH := "res://assets/models/nature/%s.glb"
const SEED := 20260922

const ARENA_RADIUS := 40.0
const FOREST_INNER := 30.0
const FOREST_OUTER := 44.0
const SHRINE_DISTANCE := 22.0
const WORLD_TREE_SCALE := 15.0

const FOREST_TREES := [
	"tree_default", "tree_oak", "tree_tall", "tree_thin", "tree_detailed",
	"tree_fat", "tree_blocks", "tree_pineTallA", "tree_pineRoundA",
]
## ต้นไม้เวอร์ชันสีเข้ม ใช้แทนพื้นที่ที่ธุลีเน่าลามถึงแล้ว
const BLIGHTED_TREES := [
	"tree_default_dark", "tree_oak_dark", "tree_tall_dark",
	"tree_detailed_dark", "tree_small_dark",
]
const ROCKS := ["rock_largeA", "rock_largeB", "rock_largeC", "rock_tallA", "rock_tallB", "stone_largeA", "stone_tallA"]
const PEBBLES := ["rock_smallA", "rock_smallB", "rock_smallC"]
const UNDERGROWTH := [
	"plant_bush", "plant_bushLarge", "plant_bushSmall", "grass", "grass_large",
	"flower_redA", "flower_purpleA", "flower_yellowA", "crops_leafsStageB",
]
const FUNGI := ["mushroom_red", "mushroom_redGroup", "mushroom_tan", "mushroom_tanGroup"]
const DEADWOOD := ["log", "log_stack", "stump_old", "stump_round"]

## ศาลรากทั้ง 4 ทิศ ใช้ตอนพิธีเลือกเส้นทาง Lv 10
const SHRINES := [
	{"class_id": CharacterClass.Id.HERB_VANGUARD, "direction": Vector3(0, 0, -1), "color": Color(0.45, 0.85, 0.40)},
	{"class_id": CharacterClass.Id.FIELD_MEDIC, "direction": Vector3(0, 0, 1), "color": Color(0.60, 0.88, 1.00)},
	{"class_id": CharacterClass.Id.ALCHEMIST, "direction": Vector3(1, 0, 0), "color": Color(0.72, 0.50, 0.95)},
	{"class_id": CharacterClass.Id.TOXICOLOGIST, "direction": Vector3(-1, 0, 0), "color": Color(0.80, 0.90, 0.30)},
]

var _rng := RandomNumberGenerator.new()
var _scene_cache := {}
## วงพื้นที่ที่ห้ามวางของ เก็บเป็น Vector3(x, z, รัศมี)
var _keep_clear: Array[Vector3] = []


## Main เรียกเองหลังจองพื้นที่ spawn แล้ว ไม่สร้างอัตโนมัติใน _ready
## เพราะ _ready ของลูกทำงานก่อนพ่อ ทำให้จองไม่ทัน
func build() -> void:
	_rng.seed = SEED
	_keep_clear.append(Vector3(0.0, 0.0, 7.0))
	_build_world_tree()
	_build_shrines()
	_build_forest_ring()
	_build_boundary()
	_scatter(ROCKS, 26, 1.6, 3.0, 1.1)
	_scatter(DEADWOOD, 12, 1.8, 2.8, 0.0)
	_scatter(BLIGHTED_TREES, 14, 2.5, 4.0, 0.6)
	_scatter(UNDERGROWTH, 170, 1.6, 3.2, 0.0)
	_scatter(FUNGI, 55, 1.6, 2.8, 0.0)
	_scatter(PEBBLES, 28, 1.4, 2.4, 0.0)


# --- ชิ้นส่วนหลัก ---

func _build_world_tree() -> void:
	var tree := _place("tree_detailed", Vector3.ZERO, WORLD_TREE_SCALE, 0.0)
	tree.name = "WorldTree"
	_add_collider(tree, 1.8, 20.0)

	# รากที่โผล่พ้นดินรอบโคนต้น
	for index in range(10):
		var angle := TAU * float(index) / 10.0
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(4.5, 6.5)
		_place("stump_round", offset, _rng.randf_range(2.0, 3.2), angle)

	for index in range(16):
		var angle := TAU * float(index) / 16.0 + 0.2
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(3.0, 4.5)
		_place(FUNGI.pick_random(), offset, _rng.randf_range(1.6, 2.6), _rng.randf() * TAU)


func _build_shrines() -> void:
	for shrine in SHRINES:
		var direction: Vector3 = shrine["direction"]
		var center: Vector3 = direction * SHRINE_DISTANCE
		var yaw := atan2(-direction.x, -direction.z)
		_keep_clear.append(Vector3(center.x, center.z, 7.0))

		var obelisk := _place("statue_obelisk", center, 4.5, yaw)
		obelisk.name = "Shrine_%s" % CharacterClass.SHRINE_DIRECTION[shrine["class_id"]]
		_add_collider(obelisk, 0.9, 4.0)

		_place("statue_ring", center, 4.0, yaw)

		var light := OmniLight3D.new()
		light.light_color = shrine["color"]
		light.light_energy = 2.4
		light.omni_range = 11.0
		light.position = center + Vector3.UP * 3.2
		add_child(light)

		# เสาหินขนาบสองข้าง
		var side := Vector3(direction.z, 0.0, -direction.x)
		for offset in [-3.2, 3.2]:
			var column := _place("statue_column", center + side * offset, 3.0, yaw)
			_add_collider(column, 0.6, 3.0)

		# ทางเดินหินจากโคนต้นไม้โลกมาถึงศาล
		for step in range(5):
			var along := lerpf(10.0, SHRINE_DISTANCE - 5.0, float(step) / 4.0)
			_place("stone_largeA", direction * along, 1.3, _rng.randf() * TAU)


func _build_forest_ring() -> void:
	var count := 170
	for index in range(count):
		var angle := TAU * float(index) / float(count) + _rng.randf_range(-0.02, 0.02)
		var distance := _rng.randf_range(FOREST_INNER, FOREST_OUTER)
		var position := Vector3(cos(angle), 0.0, sin(angle)) * distance
		if _is_blocked(position):
			continue
		var model: String = BLIGHTED_TREES.pick_random() if _rng.randf() < 0.22 else FOREST_TREES.pick_random()
		var tree := _place(model, position, _rng.randf_range(3.2, 5.4), _rng.randf() * TAU)
		_add_collider(tree, 0.7, 8.0)


## กำแพงมองไม่เห็นกันผู้เล่นเดินหลุดขอบแผนที่
func _build_boundary() -> void:
	var wall := StaticBody3D.new()
	wall.name = "Boundary"
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)

	var segments := 24
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(ARENA_RADIUS * TAU / float(segments) + 1.0, 12.0, 1.0)
		shape.shape = box
		shape.position = Vector3(cos(angle), 0.0, sin(angle)) * ARENA_RADIUS + Vector3.UP * 6.0
		shape.rotation.y = -angle
		wall.add_child(shape)


# --- ตัวช่วย ---

func _scatter(models: Array, count: int, min_scale: float, max_scale: float, collider_radius: float) -> void:
	for index in range(count):
		var angle := _rng.randf() * TAU
		var distance := sqrt(_rng.randf()) * (FOREST_INNER - 2.0)
		var position := Vector3(cos(angle), 0.0, sin(angle)) * distance
		if _is_blocked(position):
			continue
		var node := _place(models.pick_random(), position, _rng.randf_range(min_scale, max_scale), _rng.randf() * TAU)
		if collider_radius > 0.0:
			_add_collider(node, collider_radius, 2.0)


func _place(model_name: String, position: Vector3, uniform_scale: float, yaw: float) -> Node3D:
	var packed: PackedScene = _scene_cache.get(model_name, null)
	if packed == null:
		packed = load(MODEL_PATH % model_name)
		_scene_cache[model_name] = packed
	var node: Node3D = packed.instantiate()
	add_child(node)
	node.position = position
	node.scale = Vector3.ONE * uniform_scale
	node.rotation.y = yaw
	return node


## ใส่ collider ทรงกระบอกให้ prop โดยไม่ต้องคำนวณ trimesh ซึ่งหนักเกินจำเป็น
func _add_collider(node: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3.UP * (height * 0.5)
	body.add_child(shape)
	body.position = node.position
	add_child(body)


func _is_blocked(position: Vector3) -> bool:
	for area in _keep_clear:
		if Vector2(position.x - area.x, position.z - area.y).length() < area.z:
			return true
	return false


## ให้ระบบอื่นถามได้ว่าควร spawn ที่ไหนโดยไม่ทับของ
func reserve(position: Vector3, radius: float) -> void:
	_keep_clear.append(Vector3(position.x, position.z, radius))
