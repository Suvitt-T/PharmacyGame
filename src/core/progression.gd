class_name Progression
extends RefCounted

## ตาราง XP ต่อเลเวล 1-25 ตามเอกสาร หัวข้อ "ตาราง XP ต่อเลเวล"

const MAX_LEVEL := 25
const STAT_POINTS_PER_LEVEL := 3

## index = เลเวลปัจจุบัน, value = XP ที่ต้องใช้ไปเลเวลถัดไป
const XP_TO_NEXT := {
	1: 100, 2: 150, 3: 220, 4: 300, 5: 400,
	6: 520, 7: 660, 8: 820, 9: 1000, 10: 1300,
	11: 1650, 12: 2050, 13: 2500, 14: 3000, 15: 3800,
	16: 4700, 17: 5700, 18: 6800, 19: 8000, 20: 10000,
	21: 12500, 22: 15500, 23: 19000, 24: 23000,
}

const ACT_BY_LEVEL := {
	"prologue": [1, 9],
	"act_1": [10, 14],
	"act_2": [15, 19],
	"act_3": [20, 25],
}


static func xp_to_next(level: int) -> int:
	return int(XP_TO_NEXT.get(level, 0))


## XP สะสมที่ต้องมีเพื่อไปถึงเลเวลนั้น (Lv1 = 0)
static func cumulative_xp_for(level: int) -> int:
	var total := 0
	for lv in range(1, mini(level, MAX_LEVEL)):
		total += xp_to_next(lv)
	return total


static func level_for_cumulative_xp(total_xp: int) -> int:
	var level := 1
	var spent := 0
	while level < MAX_LEVEL:
		var needed := xp_to_next(level)
		if total_xp < spent + needed:
			break
		spent += needed
		level += 1
	return level


## เอกสารระบุ "3 แต้ม/เลเวล" และตัวอย่างคำนวณให้ 45 แต้มที่ Lv15
## จึงนับรวม Lv1 ด้วย: total = level * 3
static func total_stat_points(level: int) -> int:
	return level * STAT_POINTS_PER_LEVEL


static func act_for_level(level: int) -> String:
	for act in ACT_BY_LEVEL:
		var span: Array = ACT_BY_LEVEL[act]
		if level >= span[0] and level <= span[1]:
			return act
	return "act_3"
