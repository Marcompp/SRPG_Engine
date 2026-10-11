extends "res://tests/test_base.gd"
## Weapon traits earned through kills (WeaponTraits).


func test_trait_data() -> void:
	check_eq(WeaponTraits.validate(), [] as Array[String], "every trait is a skill")
	check_eq(Skills.validate(), [] as Array[String], "skill data problems")


func test_kill_history() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	brig.tags.assign(["heavy"])
	lord.hp = 3
	var sword: Dictionary = lord.weapon
	WeaponTraits.record_kill(sword, lord, brig, {"crit": true, "counter": true}, true)
	var h: Dictionary = sword.history
	for key in ["tag:heavy", "vs:axe", "crit", "counter", "low_hp", "alone"]:
		check_eq(h.get(key, 0), 1, "history notes " + key)
	check(not h.has("initiated") and not h.has("ranged") and not h.has("afflicted"), "and nothing that didn't happen")
	check_eq(sword.kills, 1, "counts the kill")


func test_history_weights_the_roll() -> void:
	var history := {"tag:heavy": 49}
	var counts := {}
	for i in 300:
		var t := WeaponTraits.roll(history)
		counts[t] = counts.get(t, 0) + 1
	check(counts.get("Armorbane", 0) > 150, "a weapon that killed armor mostly rolls Armorbane (%s)" % [counts])
	check(counts.size() > 1, "but not always")


func test_trait_at_fifty_kills() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	lord.dexterity = 60
	brig.agility = 0
	brig.luck = 0
	brig.hp = 1
	lord.weapon["kills"] = WeaponTraits.KILLS_FOR_TRAIT - 1
	lord.weapon["history"] = {"tag:heavy": 49}
	check(Glossary.item(lord.weapon).contains("a trait at 50"), "the description counts toward it")
	await b.actions.do_combat(lord, brig)
	var earned: String = lord.weapon.get("trait", "")
	check(earned != "", "the 50th kill earns a trait")
	check(lord.weapon.skills.has(earned) and Skills.of(lord).has(earned), "a skill while equipped")
	check(lord.biography.any(func(e): return Text.render(e).begins_with("Their Iron Sword earned ")), "in the biography")
	var copy := SaveGame.unit_from_dict(SaveGame.unit_to_dict(lord))
	check_eq(copy.weapon.get("trait", ""), earned, "kept with the weapon")
	copy.free()
	var foe := _spawn_enemy(Vector2i(5, 7), 1)
	foe.agility = 0
	await b.actions.do_combat(lord, foe)
	check_eq(lord.weapon.skills.size(), 1, "only once")
