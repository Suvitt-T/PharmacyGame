extends RefCounted

var runner

const Route := Pharmacokinetics.Route
const Zone := Pharmacokinetics.Zone


func test_route_profile_matches_doc() -> void:
	runner.equal_float(Pharmacokinetics.speed_factor(Route.INJECTION), 6.0, "injection speedFactor")
	runner.equal_float(Pharmacokinetics.bioavailability(Route.INJECTION), 1.0, "injection bioavailability")
	runner.equal_float(Pharmacokinetics.speed_factor(Route.SUBLINGUAL), 3.5, "sublingual speedFactor")
	runner.equal_float(Pharmacokinetics.bioavailability(Route.SUBLINGUAL), 0.80, "sublingual bioavailability")
	runner.equal_float(Pharmacokinetics.speed_factor(Route.ORAL), 1.0, "oral speedFactor")
	runner.equal_float(Pharmacokinetics.bioavailability(Route.ORAL), 0.50, "oral bioavailability")
	runner.equal_float(Pharmacokinetics.speed_factor(Route.TOPICAL), 0.4, "topical speedFactor")
	runner.equal_float(Pharmacokinetics.bioavailability(Route.TOPICAL), 0.30, "topical bioavailability")


func test_effective_dose() -> void:
	runner.equal_float(Pharmacokinetics.effective_dose(100.0, Route.INJECTION), 100.0, "ฉีดได้เต็มขนาด")
	runner.equal_float(Pharmacokinetics.effective_dose(100.0, Route.ORAL), 50.0, "กินได้ครึ่งเดียว")
	runner.equal_float(Pharmacokinetics.effective_dose(100.0, Route.TOPICAL), 30.0, "ทาได้ 30%")


func test_onset_scales_with_route_and_potency() -> void:
	runner.equal_float(Pharmacokinetics.onset_seconds(60.0, Route.ORAL, 1.0), 60.0, "กิน potency 1.0")
	runner.equal_float(Pharmacokinetics.onset_seconds(60.0, Route.INJECTION, 1.0), 10.0, "ฉีดเร็วกว่า 6 เท่า")
	runner.equal_float(Pharmacokinetics.onset_seconds(60.0, Route.ORAL, 2.0), 30.0, "potency 2 เท่า ออกฤทธิ์ไวขึ้นเท่าตัว")
	runner.ok(
		Pharmacokinetics.onset_seconds(60.0, Route.TOPICAL, 1.0) > Pharmacokinetics.onset_seconds(60.0, Route.ORAL, 1.0),
		"ทาช้ากว่ากินเสมอ"
	)


## ข้อสังเกตสำคัญที่เอกสารระบุไว้: ให้พอดี ED เป๊ะจะได้ duration = 0
func test_duration_zero_at_exact_effective_dose() -> void:
	runner.equal_float(Pharmacokinetics.duration_seconds(30.0, 1.0), 0.0, "doseRatio 1.0 ได้ duration 0")
	runner.equal_float(Pharmacokinetics.duration_seconds(30.0, 0.5), 0.0, "ต่ำกว่า ED ก็ 0")


func test_duration_one_half_life_at_double_dose() -> void:
	runner.equal_float(Pharmacokinetics.duration_seconds(30.0, 2.0), 30.0, "ให้ 2 เท่า ED ได้ 1 half-life")
	runner.equal_float(Pharmacokinetics.duration_seconds(30.0, 4.0), 60.0, "ให้ 4 เท่า ED ได้ 2 half-life")
	runner.equal_float(Pharmacokinetics.duration_seconds(60.0, 2.0), 60.0, "half-life ยาวขึ้น duration ยาวตาม")


func test_effect_zones() -> void:
	runner.ok(Pharmacokinetics.effect_zone(90.0, 100.0, 200.0) == Zone.NO_EFFECT, "ต่ำกว่า ED")
	runner.ok(Pharmacokinetics.effect_zone(100.0, 100.0, 200.0) == Zone.THERAPEUTIC, "พอดี ED เข้าโซนออกฤทธิ์")
	runner.ok(Pharmacokinetics.effect_zone(200.0, 100.0, 200.0) == Zone.THERAPEUTIC, "พอดี TD ยังไม่เป็นพิษ")
	runner.ok(Pharmacokinetics.effect_zone(201.0, 100.0, 200.0) == Zone.TOXIC, "เกิน TD เป็นพิษ")


func test_therapeutic_index() -> void:
	runner.equal_float(Pharmacokinetics.therapeutic_index(100.0, 200.0), 2.0, "TI แคบ")
	runner.equal_float(Pharmacokinetics.therapeutic_index(1.0, 100.0), 100.0, "TI กว้างมาก")
	runner.equal_float(Pharmacokinetics.therapeutic_index(0.0, 100.0), 0.0, "ED 0 ไม่ระเบิด")


func test_intellect_widens_therapeutic_window() -> void:
	runner.equal_float(Pharmacokinetics.widened_toxic_dose(100.0, 5.0), 100.0, "INT 5 ยังไม่ได้โบนัส")
	runner.equal_float(Pharmacokinetics.widened_toxic_dose(100.0, 10.0), 102.0, "INT 10 ขยาย 2%")
	runner.equal_float(Pharmacokinetics.widened_toxic_dose(100.0, 50.0), 110.0, "INT 50 ขยาย 10%")


func test_concentration_curve_shape() -> void:
	var peak := 0.0
	var peak_time := 0.0
	for step in range(1, 400):
		var t := float(step) * 0.5
		var value := Pharmacokinetics.concentration_at(100.0, Route.ORAL, 30.0, 0.15, 10.0, t)
		if value > peak:
			peak = value
			peak_time = t
	runner.ok(peak > 0.0, "กราฟความเข้มข้นมีจุดสูงสุด")
	runner.ok(peak_time > 0.0 and peak_time < 200.0, "จุดสูงสุดอยู่กลางช่วง ไม่ใช่ที่ t=0 (ได้ %.1f วิ)" % peak_time)
	runner.equal_float(Pharmacokinetics.concentration_at(100.0, Route.ORAL, 30.0, 0.15, 10.0, 0.0), 0.0, "t=0 ยังไม่มีสารในเลือด")
	var late := Pharmacokinetics.concentration_at(100.0, Route.ORAL, 30.0, 0.15, 10.0, 600.0)
	runner.ok(late < peak * 0.05, "ปลายกราฟลดลงจนเกือบหมด")
