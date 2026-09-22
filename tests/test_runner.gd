extends SceneTree

## Test runner แบบ headless ไม่พึ่ง addon ภายนอก
## รัน: godot --headless --script res://tests/test_runner.gd

const SUITES := [
	"res://tests/test_formulas.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_character_sheet.gd",
	"res://tests/test_combat_math.gd",
	"res://tests/test_pharmacokinetics.gd",
	"res://tests/test_pharmacy_data.gd",
	"res://tests/test_remedy.gd",
	"res://tests/test_interaction.gd",
	"res://tests/test_metabolism.gd",
]

var passed := 0
var failed := 0
var current_suite := ""


func _initialize() -> void:
	for suite_path in SUITES:
		var script = load(suite_path)
		if script == null or not (script is GDScript):
			failed += 1
			print("  โหลดไม่ได้: %s" % suite_path)
			continue
		var suite = script.new()
		suite.runner = self
		current_suite = suite_path.get_file().get_basename()
		for method in suite.get_method_list():
			if not method.name.begins_with("test_"):
				continue
			suite.call(method.name)
			if suite.has_method("teardown"):
				suite.call("teardown")

	print("")
	print("ผ่าน %d · ไม่ผ่าน %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func ok(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("  FAIL [%s] %s" % [current_suite, label])


func equal_float(actual: float, expected: float, label: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) <= tolerance:
		passed += 1
	else:
		failed += 1
		print("  FAIL [%s] %s — ได้ %f คาดหวัง %f" % [current_suite, label, actual, expected])


func equal_int(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		print("  FAIL [%s] %s — ได้ %d คาดหวัง %d" % [current_suite, label, actual, expected])
