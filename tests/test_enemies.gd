extends RefCounted

var runner


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


## ตาราง AI Behavior ในเอกสาร
func test_archetype_table_matches_doc() -> void:
	var expected := {
		EnemyArchetype.Kind.SKITTISH: [8.0, 1.4],
		EnemyArchetype.Kind.BRAWLER: [12.0, 1.0],
		EnemyArchetype.Kind.KITER: [15.0, 1.0],
		EnemyArchetype.Kind.PACK_HUNTER: [10.0, 1.2],
	}
	for kind in expected:
		runner.equal_float(
			EnemyArchetype.value(kind, "aggro_range"), expected[kind][0],
			"%s aggro range" % EnemyArchetype.display_name(kind)
		)
		runner.equal_float(
			float(EnemyArchetype.profile(kind)["speed_multiplier"]), expected[kind][1],
			"%s ตัวคูณความเร็ว" % EnemyArchetype.display_name(kind)
		)


func test_archetype_specific_traits() -> void:
	runner.equal_float(
		EnemyArchetype.value(EnemyArchetype.Kind.SKITTISH, "cornered_damage_bonus"), 0.50,
		"จนมุมแล้วโจมตีแรงขึ้น +50%"
	)
	runner.equal_float(
		EnemyArchetype.value(EnemyArchetype.Kind.SKITTISH, "desperate_hp_ratio"), 0.20,
		"สู้สวนเมื่อ HP ต่ำกว่า 20%"
	)
	runner.equal_float(
		EnemyArchetype.value(EnemyArchetype.Kind.KITER, "retreat_range"), 5.0,
		"Kiter ถอยเมื่อเข้าใกล้กว่า 5m"
	)
	runner.equal_float(
		EnemyArchetype.value(EnemyArchetype.Kind.KITER, "preferred_min"), 8.0, "รักษาระยะอย่างน้อย 8m"
	)
	runner.equal_float(
		EnemyArchetype.value(EnemyArchetype.Kind.KITER, "preferred_max"), 12.0, "รักษาระยะไม่เกิน 12m"
	)
	runner.equal_float(
		EnemyArchetype.value(EnemyArchetype.Kind.PACK_HUNTER, "call_hp_ratio"), 0.50,
		"เรียกพวกเมื่อ HP ต่ำกว่า 50%"
	)
	runner.equal_float(
		EnemyArchetype.value(EnemyArchetype.Kind.PACK_HUNTER, "call_radius"), 20.0,
		"เรียกพวกในรัศมี 20m"
	)
	var combo_min: int = int(EnemyArchetype.value(EnemyArchetype.Kind.BRAWLER, "combo_min"))
	var combo_max: int = int(EnemyArchetype.value(EnemyArchetype.Kind.BRAWLER, "combo_max"))
	runner.equal_int(combo_min, 2, "คอมโบอย่างน้อย 2 ฮิต")
	runner.equal_int(combo_max, 3, "คอมโบมากสุด 3 ฮิต")
	runner.ok(EnemyArchetype.value(EnemyArchetype.Kind.BRAWLER, "windup") > 0.0, "มี windup ให้หลบทัน")


func test_tier_table_matches_doc() -> void:
	runner.equal_float(EnemyArchetype.base_hp("common"), 60.0, "Common HP 60")
	runner.equal_float(EnemyArchetype.base_damage("common"), 8.0, "Common DMG 8")
	runner.equal_float(EnemyArchetype.base_hp("elite"), 250.0, "Elite HP 250")
	runner.equal_float(EnemyArchetype.base_damage("elite"), 20.0, "Elite DMG 20")
	runner.equal_float(EnemyArchetype.base_hp("miniboss"), 800.0, "Mini-boss HP 800")
	runner.equal_float(EnemyArchetype.base_damage("miniboss"), 35.0, "Mini-boss DMG 35")


## เอกสาร: Elite มี Corruption Aura เสมอ และศัตรูตั้งแต่ Act 2 มีทุกตัว
func test_corruption_aura_rules() -> void:
	runner.ok(EnemyArchetype.has_corruption_aura("elite", "hub"), "Elite มี Aura เสมอแม้ใน Hub")
	runner.ok(not EnemyArchetype.has_corruption_aura("common", "hub"), "Common ใน Hub ยังไม่มี")
	for biome in ["swamp", "desert", "ice", "core"]:
		runner.ok(EnemyArchetype.has_corruption_aura("common", biome), "ศัตรูใน %s มี Aura ทุกตัว" % biome)


func test_corruption_aura_values_match_doc() -> void:
	runner.equal_float(CorruptionAura.RADIUS, 3.0, "รัศมี 3m")
	runner.equal_float(CorruptionAura.DAMAGE_PER_SECOND, 5.0, "5 ดาเมจต่อวินาที")
	runner.equal_float(CorruptionAura.DURATION, 4.0, "นาน 4 วินาที")
	runner.equal_float(
		Metabolism.STATUS_DAMAGE_PER_SECOND["blight"], CorruptionAura.DAMAGE_PER_SECOND,
		"ดาเมจของสถานะ Blight ตรงกับที่ Aura ระบุ"
	)


func test_every_doc_enemy_is_present() -> void:
	var expected := {
		"hub": ["feral_rootwolf", "blightbat", "root_wasp", "elder_rootbear"],
		"swamp": ["tainted_leech", "root_mosquito", "bog_shadow_croc"],
		"desert": ["root_sand_scorpion", "ash_vulture", "tainted_sandworm"],
		"ice": ["ice_wolf", "tainted_snow_eagle", "root_ice_giant"],
		"core": ["living_rootling", "blight_warden"],
	}
	for biome in expected:
		var ids := EnemyDB.ids_in_biome(biome)
		for enemy_id in expected[biome]:
			runner.ok(ids.has(enemy_id), "%s อยู่ในไบโอม %s" % [enemy_id, biome])
		runner.equal_int(ids.size(), expected[biome].size(), "จำนวนศัตรูใน %s ตรงตาราง" % biome)


func test_every_biome_has_one_elite() -> void:
	for biome in ["hub", "swamp", "desert", "ice", "core"]:
		var elites := 0
		for enemy_id in EnemyDB.ids_in_biome(biome):
			if str(EnemyDB.definition(enemy_id).get("tier", "")) == "elite":
				elites += 1
		runner.equal_int(elites, 1, "ไบโอม %s มี Elite 1 ตัว" % biome)


func test_every_enemy_points_at_a_real_archetype_and_model() -> void:
	for enemy_id in EnemyDB.all_ids():
		var data := EnemyDB.definition(enemy_id)
		var key := str(data.get("archetype", ""))
		runner.ok(
			EnemyArchetype.PROFILE[EnemyArchetype.from_key(key)]["key"] == key,
			"%s ใช้ archetype ที่มีจริง (%s)" % [enemy_id, key]
		)
		runner.ok(EnemyDB.model_scene(enemy_id) != null, "%s มีโมเดลโหลดได้" % enemy_id)


func test_difficulty_scaling_uses_zone_level() -> void:
	var common_hp := Formulas.enemy_hp(EnemyArchetype.base_hp("common"), 1)
	var deep_hp := Formulas.enemy_hp(EnemyArchetype.base_hp("common"), 13)
	runner.equal_float(common_hp, 60.0, "ZoneLevel 1 ไม่สเกล")
	runner.equal_float(deep_hp, 60.0 * (1.0 + 12.0 * 0.12), "ZoneLevel 13 สเกลตามสูตร")
	runner.ok(deep_hp > common_hp * 2.0, "แก่นต้นไม้โลกแกร่งกว่า Hub เกินเท่าตัว")


# --- Loot Table ---

func test_coins_always_drop_in_range() -> void:
	for seed_value in range(40):
		var drops := LootTable.roll("common", "hub", 1, false, _rng(seed_value))
		var coins := -1
		for drop in drops:
			if drop["kind"] == "coins":
				coins = int(drop["amount"])
		runner.ok(coins >= 5 and coins <= 15, "เงินดรอป 100%% อยู่ในช่วง 5-15 (ได้ %d)" % coins)


func test_ingredient_drop_rate_is_near_sixty_percent() -> void:
	var trials := 600
	var hits := 0
	for seed_value in range(trials):
		for drop in LootTable.roll("common", "hub", 1, false, _rng(seed_value)):
			if drop["kind"] == "ingredient" and float(drop["potency"]) <= LootTable.NORMAL_POTENCY:
				hits += 1
				break
	var rate := float(hits) / float(trials)
	runner.ok(absf(rate - 0.60) < 0.06, "อัตราดรอปวัตถุดิบทั่วไปใกล้ 60%% (ได้ %.1f%%)" % (rate * 100.0))


func test_high_potency_drop_rate_is_near_twelve_percent() -> void:
	var trials := 800
	var hits := 0
	for seed_value in range(trials):
		for drop in LootTable.roll("common", "hub", 1, false, _rng(seed_value)):
			if drop["kind"] == "ingredient" and float(drop["potency"]) > LootTable.NORMAL_POTENCY:
				hits += 1
				break
	var rate := float(hits) / float(trials)
	runner.ok(absf(rate - 0.12) < 0.04, "อัตราดรอป Potency สูงใกล้ 12%% (ได้ %.1f%%)" % (rate * 100.0))


## เอกสาร: สูตรยา 3% ธรรมดา แต่ Elite ขึ้นไป 15%
func test_elite_drops_recipes_far_more_often() -> void:
	var common_hits := 0
	var elite_hits := 0
	for seed_value in range(600):
		for drop in LootTable.roll("common", "hub", 1, false, _rng(seed_value)):
			if drop["kind"] == "recipe":
				common_hits += 1
		for drop in LootTable.roll("elite", "hub", 1, false, _rng(seed_value)):
			if drop["kind"] == "recipe":
				elite_hits += 1
	runner.ok(elite_hits > common_hits * 3, "Elite ดรอปสูตรบ่อยกว่ามาก (%d เทียบ %d)" % [elite_hits, common_hits])


## เอกสาร: ตัวอย่างพิษได้เฉพาะตอนฆ่าด้วยสกิลพิษของนักพิษวิทยา
func test_venom_sample_only_when_killed_with_venom() -> void:
	for seed_value in range(200):
		for drop in LootTable.roll("common", "hub", 1, false, _rng(seed_value)):
			if drop["kind"] == "venom_sample":
				runner.ok(false, "ไม่ได้ฆ่าด้วยพิษ ต้องไม่ได้ตัวอย่างพิษ")
				return
	runner.ok(true, "ไม่ได้ฆ่าด้วยพิษ ไม่มีตัวอย่างพิษเลยครบ 200 ครั้ง")

	var hits := 0
	for seed_value in range(400):
		for drop in LootTable.roll("common", "hub", 1, true, _rng(seed_value)):
			if drop["kind"] == "venom_sample":
				hits += 1
	runner.ok(hits > 0, "ฆ่าด้วยพิษแล้วมีโอกาสได้ตัวอย่างพิษ (ได้ %d/400)" % hits)


func test_drops_only_reference_ingredients_from_that_biome() -> void:
	for biome in ["hub", "swamp", "desert", "ice"]:
		var allowed := []
		for item in PharmacyDB.ingredients_in_biome(biome):
			allowed.append((item as Ingredient).id)
		for seed_value in range(60):
			for drop in LootTable.roll("common", biome, 1, false, _rng(seed_value)):
				if drop["kind"] == "ingredient":
					runner.ok(allowed.has(str(drop["id"])), "วัตถุดิบที่ดรอปใน %s ต้องมีในไบโอมนั้น" % biome)


func test_miniboss_always_drops_equipment() -> void:
	for seed_value in range(50):
		var found := false
		for drop in LootTable.roll("miniboss", "hub", 5, false, _rng(seed_value)):
			if drop["kind"] == "equipment":
				found = true
		runner.ok(found, "มินิบอสดรอปอุปกรณ์เสมอ")
