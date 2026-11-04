class_name MixRules
extends RefCounted
## The balance puzzle (a compost heap, a filter bed, a fuel blend): set how
## much of each ingredient goes in; every rule from data must hold.
## Rules: {"ratio": [a, b], "min": x, "max": y, "fail": "..."} on amount(a)/amount(b),
## or {"amount": a, "min": x, "max": y, "fail": "..."}, or {"total": true, ...}.


## The `fail` lines of every rule the amounts break (empty when it is right).
static func problems(rules: Array, amounts: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for rule: Dictionary in rules:
		var value := _value(rule, amounts)
		if value < float(rule.get("min", -INF)) or value > float(rule.get("max", INF)):
			found.append(str(rule.get("fail", "Not right yet.")))
	return found


static func _value(rule: Dictionary, amounts: Dictionary) -> float:
	if rule.has("ratio"):
		var pair: Array = rule["ratio"]
		var below := float(amounts.get(pair[1], 0))
		return INF if below <= 0.0 else float(amounts.get(pair[0], 0)) / below
	if rule.has("amount"):
		return float(amounts.get(rule["amount"], 0))
	var total := 0.0
	for amount in amounts.values():
		total += float(amount)
	return total
