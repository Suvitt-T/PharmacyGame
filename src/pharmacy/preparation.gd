class_name Preparation
extends RefCounted

## วิธีเตรียมยา ตามหัวข้อ "วิธีเตรียมยา (Preparation Method)" ในเอกสาร
## เอกสารระบุไว้ 4 วิธี (ต้ม/หมัก/บด/สกัดฉีด) แต่ ROUTE_PROFILE มี 4 route
## จึงเพิ่มยาทา (salve) เพื่อให้ route topical มีทางเข้าถึงจริง ไม่เป็น route ตาย

enum Method { DECOCTION, TINCTURE, POWDER, INJECTION_EXTRACT, SALVE }

const PROFILE := {
	Method.DECOCTION: {
		"key": "decoction",
		"name": "ต้มสกัดน้ำ",
		"route": Pharmacokinetics.Route.ORAL,
		"craft_seconds": 6.0,
		"note": "ต้มเปลือกหรือรากในน้ำเดือด เหมาะกับสารที่ละลายน้ำได้ดี",
	},
	Method.TINCTURE: {
		"key": "tincture",
		"name": "หมักแอลกอฮอล์",
		"route": Pharmacokinetics.Route.SUBLINGUAL,
		"craft_seconds": 10.0,
		"note": "หมักในแอลกอฮอล์ ดึงสารที่ไม่ละลายน้ำออกมาได้ อมใต้ลิ้นดูดซึมเร็ว",
	},
	Method.POWDER: {
		"key": "powder",
		"name": "บดผง",
		"route": Pharmacokinetics.Route.ORAL,
		"craft_seconds": 3.0,
		"note": "บดแห้งเป็นผง เก็บได้นานแต่ดูดซึมช้ากว่าแบบสกัด",
	},
	Method.INJECTION_EXTRACT: {
		"key": "injection_extract",
		"name": "สกัดฉีด",
		"route": Pharmacokinetics.Route.INJECTION,
		"craft_seconds": 14.0,
		"note": "สกัดให้บริสุทธิ์พอจะฉีดได้ ออกฤทธิ์เร็วที่สุดและพลาดแล้วแก้ยากที่สุด",
	},
	Method.SALVE: {
		"key": "salve",
		"name": "ยาทา",
		"route": Pharmacokinetics.Route.TOPICAL,
		"craft_seconds": 5.0,
		"note": "ผสมไขมันเป็นขี้ผึ้ง ออกฤทธิ์เฉพาะที่ ดูดซึมเข้ากระแสเลือดน้อย",
	},
}

## ต่ำกว่านี้ถือว่าวิธีเตรียมผิดจนไม่ได้สารออกฤทธิ์เลย
const FAILED_EFFICIENCY := 0.05


static func route_of(method: Method) -> Pharmacokinetics.Route:
	return PROFILE[method]["route"]


static func key_of(method: Method) -> String:
	return PROFILE[method]["key"]


static func display_name(method: Method) -> String:
	return PROFILE[method]["name"]


static func craft_seconds(method: Method, craft_speed: float = 1.0) -> float:
	return PROFILE[method]["craft_seconds"] / maxf(craft_speed, 0.01)


static func all() -> Array:
	return PROFILE.keys()


static func from_key(key: String) -> Method:
	for method in PROFILE:
		if PROFILE[method]["key"] == key:
			return method
	return Method.DECOCTION
