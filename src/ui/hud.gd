class_name Hud
extends CanvasLayer

## HUD ชั่วคราวสำหรับ Phase 1 สร้างด้วยโค้ดทั้งหมด
## ไม่ระบุ wireframe ในเอกสาร จึงทำเป็น debug overlay ไปก่อน
## Phase 3 (Inventory) จะออกแบบ UI จริงเป็น scene แยก

const BAR_WIDTH := 260.0
const BAR_HEIGHT := 18.0

var _hp_bar: ProgressBar
var _mana_bar: ProgressBar
var _stamina_bar: ProgressBar
var _xp_bar: ProgressBar
var _header: Label
var _stat_label: Label
var _gear_label: Label
var _skill_label: Label
var _log_label: Label

var _combatant: Combatant
var _inventory: InventoryComponent
var _skills: SkillRuntime
var _log_lines: Array[String] = []


func _ready() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 14)
	add_child(root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	root.add_child(column)

	_header = Label.new()
	column.add_child(_header)

	_hp_bar = _make_bar(column, "HP", Color(0.85, 0.22, 0.25))
	_mana_bar = _make_bar(column, "Mana", Color(0.25, 0.48, 0.9))
	_stamina_bar = _make_bar(column, "Stamina", Color(0.85, 0.72, 0.25))
	_xp_bar = _make_bar(column, "XP", Color(0.45, 0.8, 0.4))

	_stat_label = Label.new()
	column.add_child(_stat_label)

	_gear_label = Label.new()
	column.add_child(_gear_label)

	_skill_label = Label.new()
	column.add_child(_skill_label)

	var hint := Label.new()
	hint.text = "WASD เดิน · Shift วิ่ง · Space หลบ · คลิกซ้าย โจมตี · X +XP · C ดาเมจตัวเอง · R respec"

	var remedy_hint := Label.new()
	remedy_hint.text = "ยาทดลอง — 1 หลิวพอดี · 2 หลิวเกินขนาด · 3 กัวรานา · 4 ซิงโคนา · 5 ฟ็อกซ์โกลฟฉีด (ลอง 4 แล้ว 5 ติดกัน) · E สุ่มดรอป · V เสียบ Vial\nอาชีพ — Tab เลือกอาชีพ (ต้อง Lv10) · L เรียนสกิลถัดไป · Q F G H T ใช้สกิลช่อง 1-5"
	remedy_hint.add_theme_font_size_override("font_size", 12)
	remedy_hint.modulate = Color(1, 1, 1, 0.65)
	column.add_child(remedy_hint)
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.65)
	column.add_child(hint)

	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 13)
	_log_label.modulate = Color(1, 1, 1, 0.85)
	column.add_child(_log_label)


func _make_bar(parent: Control, label_text: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 72
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var value := Label.new()
	value.name = "Value"
	value.custom_minimum_size.x = 110
	row.add_child(value)

	return bar


func bind_skills(runtime: SkillRuntime) -> void:
	_skills = runtime
	runtime.tree.skill_learned.connect(func(_s): _refresh())
	runtime.cooldown_changed.connect(func(_id, _remaining): _refresh())
	_refresh()


func bind_inventory(component: InventoryComponent) -> void:
	_inventory = component
	component.inventory.changed.connect(_refresh)
	component.loadout.changed.connect(_refresh)
	_refresh()


func bind_player(combatant: Combatant) -> void:
	_combatant = combatant
	combatant.hp_changed.connect(func(c, m): _update_bar(_hp_bar, c, m))
	combatant.mana_changed.connect(func(c, m): _update_bar(_mana_bar, c, m))
	combatant.stamina_changed.connect(func(c, m): _update_bar(_stamina_bar, c, m))
	combatant.sheet.stats_changed.connect(_refresh)
	combatant.sheet.xp_gained.connect(func(_a, _t): _refresh())
	combatant.sheet.leveled_up.connect(func(lv): log_line("เลเวลอัพ → Lv %d" % lv))
	combatant.emit_all()
	_refresh()


func _update_bar(bar: ProgressBar, current: float, maximum: float) -> void:
	bar.max_value = maxf(maximum, 1.0)
	bar.value = current
	var value_label := bar.get_parent().get_node_or_null("Value") as Label
	if value_label != null:
		value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _refresh() -> void:
	if _combatant == null:
		return
	var sheet := _combatant.sheet
	var class_part := ""
	if sheet.class_id != CharacterClass.Id.NONE:
		class_part = " · " + CharacterClass.display_name(sheet.class_id)
	_header.text = "%s%s · Lv %d" % [sheet.character_name, class_part, sheet.level]
	_update_bar(_xp_bar, sheet.xp_into_current_level(), maxi(sheet.xp_needed_for_next_level(), 1))
	var stats := sheet.final_stats()
	_stat_label.text = "%s · Crit %.1f%% · Evasion %.1f%% · แต้มเหลือ %d · TI Window +%d%%" % [
		str(stats), sheet.crit_chance(), sheet.evasion_chance(),
		sheet.unspent_points(), int(sheet.therapeutic_window_bonus())
	]
	if _inventory != null:
		var loadout := _inventory.loadout
		_gear_label.text = "ดาเมจอาวุธ %.1f · ป้องกัน %.1f · กระเป๋า %d/%d · %d RC · Vial %d ช่อง" % [
			loadout.weapon_damage(_inventory.unarmed_damage), loadout.total_defense(),
			_inventory.inventory.used_slots(), _inventory.inventory.bag_capacity,
			_inventory.inventory.root_coins, loadout.total_vial_slots()
		]
	if _skills != null:
		_skill_label.text = _skill_text()


func log_line(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > 9:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)


func _skill_text() -> String:
	var tree := _skills.tree
	if tree.class_id == CharacterClass.Id.NONE:
		return "ยังไม่มีอาชีพ — ถึง Lv10 แล้วกด Tab เข้าพิธีเลือกเส้นทาง"

	var parts := ["สาย: " + tree.branch_display_name()]
	var index := 1
	for skill in tree.active_skills():
		var remaining: float = _skills.remaining_cooldown(skill.id)
		var state := "%.0f วิ" % remaining if remaining > 0.0 else "พร้อม"
		if skill.kind == Skill.Kind.TOGGLE:
			state = "เปิดอยู่" if _skills.is_toggled(skill.id) else "ปิด"
		parts.append("[%d] %s (%s)" % [index, skill.name, state])
		index += 1
	for skill in tree.passive_skills():
		parts.append("◇ %s" % skill.name)
	return " · ".join(parts)
