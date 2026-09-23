extends RefCounted

var runner


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


func _sample_remedy(units: int = 12) -> Remedy:
	return Remedy.craft("willow_bark", units, Preparation.Method.DECOCTION, 1.0)


func test_starting_state_matches_doc() -> void:
	var inventory := Inventory.new()
	runner.equal_int(inventory.bag_capacity, 30, "กระเป๋าเริ่มต้น 30 ช่อง")
	runner.equal_int(inventory.root_coins, 50, "เงินเริ่มต้น 50 RC")
	runner.equal_int(inventory.quick_slots.size(), 6, "Quick-slot 6 ช่อง")


func test_equipment_takes_one_slot_each() -> void:
	var inventory := Inventory.new()
	var rng := _rng(2)
	for index in range(30):
		runner.ok(inventory.add_equipment(ItemDB.roll_equipment("root_blade", ItemTier.Tier.COMMON, 5, rng)), "ใส่ชิ้นที่ %d ได้" % (index + 1))
	runner.ok(inventory.is_full(), "ครบ 30 ช่องแล้วเต็ม")
	runner.ok(not inventory.add_equipment(ItemDB.roll_equipment("root_blade", ItemTier.Tier.COMMON, 5, rng)), "เต็มแล้วใส่ไม่ได้")


func test_remedies_stack_to_twenty() -> void:
	var inventory := Inventory.new()
	var remedy := _sample_remedy()
	runner.equal_int(inventory.add_remedy(remedy, 20), 20, "ใส่ยา 20 ขนาน")
	runner.equal_int(inventory.used_slots(), 1, "ซ้อนอยู่ในช่องเดียว")

	inventory.add_remedy(remedy, 1)
	runner.equal_int(inventory.used_slots(), 2, "ขนานที่ 21 ล้นไปช่องใหม่")
	runner.equal_int(inventory.remedy_count(remedy.stack_key()), 21, "นับรวมได้ 21")


func test_different_remedies_do_not_stack() -> void:
	var inventory := Inventory.new()
	inventory.add_remedy(_sample_remedy(12), 1)
	inventory.add_remedy(Remedy.craft("willow_bark", 12, Preparation.Method.POWDER, 1.0), 1)
	runner.equal_int(inventory.used_slots(), 2, "คนละวิธีเตรียม ซ้อนกันไม่ได้")


func test_taking_a_remedy_reduces_the_stack() -> void:
	var inventory := Inventory.new()
	var remedy := _sample_remedy()
	inventory.add_remedy(remedy, 3)
	var key := remedy.stack_key()

	runner.ok(inventory.take_remedy(key) != null, "หยิบมาใช้ได้")
	runner.equal_int(inventory.remedy_count(key), 2, "เหลือ 2")
	inventory.take_remedy(key)
	inventory.take_remedy(key)
	runner.equal_int(inventory.used_slots(), 0, "หมดแล้วช่องว่างคืน")
	runner.ok(inventory.take_remedy(key) == null, "ไม่มีแล้วหยิบไม่ได้")


## เอกสารตั้งใจให้ Herbarium ไม่จำกัด เพื่อไม่ให้ขัดกับแก่นเกมที่อยากให้เก็บวัตถุดิบเยอะ ๆ
func test_herbarium_is_unlimited_and_separate_from_the_bag() -> void:
	var inventory := Inventory.new()
	inventory.add_ingredient("willow_bark", 9999)
	inventory.add_ingredient("foxglove_flower", 500)
	runner.equal_int(inventory.ingredient_count("willow_bark"), 9999, "เก็บได้ไม่อั้น")
	runner.equal_int(inventory.used_slots(), 0, "ไม่กินช่องกระเป๋าเลย")

	runner.ok(inventory.consume_ingredients("willow_bark", 8000), "ใช้ไปได้")
	runner.equal_int(inventory.ingredient_count("willow_bark"), 1999, "หักถูกต้อง")
	runner.ok(not inventory.consume_ingredients("willow_bark", 99999), "ใช้เกินที่มีไม่ได้")


func test_quest_items_have_their_own_tab() -> void:
	var inventory := Inventory.new()
	inventory.add_quest_item("root_seal")
	inventory.add_quest_item("root_seal")
	runner.equal_int(inventory.quest_items.size(), 1, "ไม่ซ้ำ")
	runner.equal_int(inventory.used_slots(), 0, "ไม่กินช่องกระเป๋า")
	runner.ok(inventory.has_quest_item("root_seal"), "ค้นเจอ")


func test_quick_slots_point_into_the_bag() -> void:
	var inventory := Inventory.new()
	inventory.add_remedy(_sample_remedy(), 5)
	runner.ok(inventory.assign_quick_slot(0, 0), "ผูก quick-slot กับช่องกระเป๋า")
	runner.ok(not inventory.quick_slot_entry(0).is_empty(), "อ่านค่ากลับมาได้")
	runner.ok(not inventory.assign_quick_slot(9, 0), "ช่องที่ไม่มีจริงผูกไม่ได้")
	runner.ok(not inventory.assign_quick_slot(0, 99), "ชี้ไปช่องกระเป๋าที่ไม่มีไม่ได้")


func test_quick_slot_clears_when_its_item_is_removed() -> void:
	var inventory := Inventory.new()
	inventory.add_remedy(_sample_remedy(), 1)
	inventory.assign_quick_slot(0, 0)
	inventory.remove_slot(0)
	runner.ok(inventory.quick_slot_entry(0).is_empty(), "ของหมดแล้ว quick-slot ว่างตาม")


func test_bag_can_be_expanded() -> void:
	var inventory := Inventory.new()
	inventory.expand_bag(10)
	runner.equal_int(inventory.bag_capacity, 40, "ซื้อกระเป๋าเพิ่มแล้วได้ 40 ช่อง")


func test_coins() -> void:
	var inventory := Inventory.new()
	runner.ok(inventory.spend_coins(30), "จ่ายได้")
	runner.equal_int(inventory.root_coins, 20, "เหลือ 20 RC")
	runner.ok(not inventory.spend_coins(50), "เงินไม่พอจ่ายไม่ได้")
	inventory.add_coins(100)
	runner.equal_int(inventory.root_coins, 120, "รับเงินเพิ่มได้")
