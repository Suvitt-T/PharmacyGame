class_name Inventory
extends RefCounted

## กระเป๋าตามตารางในหัวข้อ "ระบบ Inventory"
## ไม่มีระบบน้ำหนักโดยตั้งใจ และแยก Herbarium ไม่จำกัดออกจากกระเป๋าหลัก
## เพื่อให้ผู้เล่นเก็บวัตถุดิบได้ไม่อั้น แล้วตัดสินใจเฉพาะเรื่องอุปกรณ์กับยาสำเร็จรูป

signal changed()
signal bag_full()

const DEFAULT_BAG_CAPACITY := 30
const CONSUMABLE_STACK_SIZE := 20
const QUICK_SLOT_COUNT := 6
const STARTING_ROOT_COINS := 50

var bag_capacity: int = DEFAULT_BAG_CAPACITY
var root_coins: int = STARTING_ROOT_COINS

## แต่ละช่องเป็น {"kind": "equipment"|"remedy", "item": ..., "count": int}
var bag: Array[Dictionary] = []
## วัตถุดิบดิบ ไม่จำกัดจำนวนและไม่กินช่องกระเป๋า
## โครงสร้าง: ingredient_id -> { "<potency>": จำนวน }
var herbarium: Dictionary = {}
var quest_items: Array[String] = []
## เก็บ index ของช่องในกระเป๋า -1 คือว่าง
var quick_slots: Array[int] = []


func _init() -> void:
	quick_slots.resize(QUICK_SLOT_COUNT)
	quick_slots.fill(-1)


# --- Herbarium ---

func add_ingredient(ingredient_id: String, count: int = 1, potency: float = 1.0) -> void:
	if count <= 0:
		return
	var buckets: Dictionary = herbarium.get(ingredient_id, {})
	var key := _potency_key(potency)
	buckets[key] = int(buckets.get(key, 0)) + count
	herbarium[ingredient_id] = buckets
	changed.emit()


## potency เก็บแยกถังเพราะวัตถุดิบจากแหล่งต่างกันให้สารออกฤทธิ์ไม่เท่ากัน
## ส่ง potency ลบมาเพื่อนับรวมทุกถัง
func ingredient_count(ingredient_id: String, potency: float = -1.0) -> int:
	var buckets: Dictionary = herbarium.get(ingredient_id, {})
	if potency >= 0.0:
		return int(buckets.get(_potency_key(potency), 0))
	var total := 0
	for key in buckets:
		total += int(buckets[key])
	return total


func potency_buckets(ingredient_id: String) -> Dictionary:
	return herbarium.get(ingredient_id, {}).duplicate()


func best_potency(ingredient_id: String) -> float:
	var best := 0.0
	for key in herbarium.get(ingredient_id, {}):
		best = maxf(best, float(key))
	return best


func has_ingredients(ingredient_id: String, count: int, potency: float = -1.0) -> bool:
	return ingredient_count(ingredient_id, potency) >= count


## ไม่ระบุถัง = ใช้ของ potency ต่ำก่อน เก็บของดีไว้ให้ผู้เล่นเลือกใช้ตอนจำเป็น
func consume_ingredients(ingredient_id: String, count: int, potency: float = -1.0) -> bool:
	if not has_ingredients(ingredient_id, count, potency):
		return false
	var buckets: Dictionary = herbarium.get(ingredient_id, {})
	var order := buckets.keys()
	order.sort_custom(func(a, b): return float(a) < float(b))
	if potency >= 0.0:
		order = [_potency_key(potency)]

	var remaining := count
	for key in order:
		if remaining <= 0:
			break
		var taken: int = mini(int(buckets[key]), remaining)
		buckets[key] = int(buckets[key]) - taken
		remaining -= taken
		if int(buckets[key]) <= 0:
			buckets.erase(key)

	if buckets.is_empty():
		herbarium.erase(ingredient_id)
	else:
		herbarium[ingredient_id] = buckets
	changed.emit()
	return true


func _potency_key(potency: float) -> String:
	return "%.2f" % snappedf(maxf(potency, 0.0), 0.05)


# --- กระเป๋าหลัก ---

func used_slots() -> int:
	return bag.size()


func free_slots() -> int:
	return bag_capacity - used_slots()


func is_full() -> bool:
	return free_slots() <= 0


func add_equipment(equipment: Equipment) -> bool:
	if equipment == null:
		return false
	if is_full():
		bag_full.emit()
		return false
	bag.append({"kind": "equipment", "item": equipment, "count": 1})
	changed.emit()
	return true


## ยาสำเร็จรูปซ้อนได้ 20 ต่อชนิด ล้นแล้วเปิดช่องใหม่
func add_remedy(remedy: Remedy, count: int = 1) -> int:
	if remedy == null or count <= 0:
		return 0
	var remaining := count
	var key := remedy.stack_key()

	for entry in bag:
		if remaining <= 0:
			break
		if entry["kind"] != "remedy" or (entry["item"] as Remedy).stack_key() != key:
			continue
		var space: int = CONSUMABLE_STACK_SIZE - int(entry["count"])
		var moved: int = mini(space, remaining)
		entry["count"] = int(entry["count"]) + moved
		remaining -= moved

	while remaining > 0 and not is_full():
		var moved: int = mini(CONSUMABLE_STACK_SIZE, remaining)
		bag.append({"kind": "remedy", "item": remedy, "count": moved})
		remaining -= moved

	if remaining > 0:
		bag_full.emit()
	if remaining < count:
		changed.emit()
	return count - remaining


func remedy_count(key: String) -> int:
	var total := 0
	for entry in bag:
		if entry["kind"] == "remedy" and (entry["item"] as Remedy).stack_key() == key:
			total += int(entry["count"])
	return total


## หยิบยา 1 หน่วยออกมาใช้ คืน null ถ้าไม่มี
func take_remedy(key: String) -> Remedy:
	for index in range(bag.size()):
		var entry := bag[index]
		if entry["kind"] != "remedy":
			continue
		var remedy := entry["item"] as Remedy
		if remedy.stack_key() != key:
			continue
		entry["count"] = int(entry["count"]) - 1
		if int(entry["count"]) <= 0:
			_remove_slot(index)
		changed.emit()
		return remedy
	return null


func remove_slot(index: int) -> void:
	if index < 0 or index >= bag.size():
		return
	_remove_slot(index)
	changed.emit()


func _remove_slot(index: int) -> void:
	bag.remove_at(index)
	for slot_index in range(quick_slots.size()):
		var target: int = quick_slots[slot_index]
		if target == index:
			quick_slots[slot_index] = -1
		elif target > index:
			quick_slots[slot_index] = target - 1


func equipment_in_bag() -> Array[Equipment]:
	var found: Array[Equipment] = []
	for entry in bag:
		if entry["kind"] == "equipment":
			found.append(entry["item"])
	return found


## ซื้อกระเป๋าเพิ่มที่ร้านค้าตามเอกสาร
func expand_bag(extra_slots: int) -> void:
	bag_capacity += maxi(extra_slots, 0)
	changed.emit()


# --- Quest item แยก Tab ไม่กินช่องกระเป๋า ---

func add_quest_item(item_id: String) -> void:
	if quest_items.has(item_id):
		return
	quest_items.append(item_id)
	changed.emit()


func has_quest_item(item_id: String) -> bool:
	return quest_items.has(item_id)


# --- Quick-slot อ้างอิงช่องในกระเป๋าหลัก ---

func assign_quick_slot(slot_index: int, bag_index: int) -> bool:
	if slot_index < 0 or slot_index >= QUICK_SLOT_COUNT:
		return false
	if bag_index < -1 or bag_index >= bag.size():
		return false
	quick_slots[slot_index] = bag_index
	changed.emit()
	return true


func quick_slot_entry(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= QUICK_SLOT_COUNT:
		return {}
	var bag_index: int = quick_slots[slot_index]
	if bag_index < 0 or bag_index >= bag.size():
		return {}
	return bag[bag_index]


# --- เงิน ---

func add_coins(amount: int) -> void:
	root_coins = maxi(root_coins + amount, 0)
	changed.emit()


func can_afford(amount: int) -> bool:
	return root_coins >= amount


func spend_coins(amount: int) -> bool:
	if not can_afford(amount):
		return false
	root_coins -= amount
	changed.emit()
	return true
