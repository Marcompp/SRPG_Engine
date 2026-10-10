extends "res://tests/test_base.gd"
## Mounts: species, mounted classes, the stat formula, rider rules, mount EXP, Loyal,
## the stable and promotion while mounted, and old saves.


func test_mounted_classes_and_stats() -> void:
	var lord := unit_named("Lord")  # a Swordsman
	var base_hp := lord.max_hp
	lord.strength = 9
	var horse := Mounts.generate("Horse", 1, {"name": "Bayard"})
	lord.mount_up(horse)
	check_eq(lord.unit_class, "Equestrian", "a Swordsman on a horse is an Equestrian")
	check_eq(lord.foot_class, "Swordsman", "and remembers its foot class")
	check(lord.is_mounted() and lord.move_type == "horse", "rides as a horse")
	check(lord.tags.has("horse"), "and counts as one (Pikes)")
	check_eq(lord.mov, 7, "MOV comes from the mount")
	check_eq(lord.combat_str(), 4 + horse.stats.str, "STR: rider 9 / 2 + mount")
	check_eq(lord.max_hp, base_hp, "HP stays the rider's own")
	check(Skills.has(lord, "Canto"), "mounted classes have Canto")
	var back := lord.dismount()
	check_eq(back.name, "Bayard", "dismounting hands back the mount")
	check(lord.unit_class == "Swordsman" and lord.mov == 5 and lord.combat_str() == 9, "back on foot")
	# Pegasi: flying, female riders only, named per class.
	var knight := unit_named("Fighter")  # an Axeman
	ride(knight, "Pegasus", "Footman")
	check_eq(knight.class_display_name(), "Flier", "Cavalry on a pegasus is a Flier")
	check(knight.move_type == "flying" and knight.tags.has("flying") and not knight.tags.has("horse"),
		"the species decides movement and tags")
	# Drakes: the new drake move type climbs.
	ride(knight, "Drake", "Axeman")
	check_eq(knight.class_display_name(), "Drake Raider", "an Axeman on a drake")
	check(knight.tags.has("reptile"), "reptile tag")
	check_eq(b.map.unit_cost(knight, Vector2i(2, 3)), 4.0, "mountains cost a drake 4")
	check_eq(knight.mov, 5, "less MOV than a horse")
	# Innate skills: the foot class's stay, except terrain movement.
	var rogue := unit_named("Archer")
	rogue.set_class("Rogue")
	rogue.mount_up(Mounts.generate("Horse", 1, {"skills": ["Loyal"]}))
	check(Skills.has(rogue, "Steal") and Skills.has(rogue, "Lockpick"), "a mounted Rogue still steals")
	check(not Skills.has(rogue, "Forester"), "but the horse does the moving")
	check(Skills.has(rogue, "Loyal"), "the mount's skills count")


func test_who_can_ride() -> void:
	check(Mounts.ride_problem("Guard", "Human", "male", "Horse") != "", "heavy armor can't ride")
	check(Mounts.ride_problem("Footman", "Centaur", "male", "Horse") != "", "Centaurs don't ride")
	check(Mounts.ride_problem("Footman", "Naga", "male", "Horse") != "", "races banned from mounted classes")
	var why := Mounts.ride_problem("Footman", "Human", "male", "Pegasus")
	check(why.contains("female"), "pegasi say why they refuse: %s" % why)
	check_eq(Mounts.ride_problem("Footman", "Human", "female", "Pegasus"), "", "a female Footman can")
	check_eq(Mounts.ride_problem("Mage", "Elf", "male", "Drake"), "", "casters can ride")
	# Every mountable class's mounted class exists, and promotions stay consistent:
	# mounting then promoting gives the same class as promoting then mounting.
	for foot: String in Mounts.MOUNTED_CLASS:
		var mounted: String = Mounts.MOUNTED_CLASS[foot]
		check(Classes.DATA.has(mounted) and Classes.get_data(mounted).get("mounted", false), "%s exists" % mounted)
		for promo in Classes.promotions(foot):
			check(Classes.promotions(mounted).has(Mounts.mounted_class(promo)),
				"%s -> %s: %s promotes to %s" % [foot, promo, mounted, Mounts.mounted_class(promo)])
		check(Mounts.DISPLAY.has(mounted), "%s has display names" % mounted)


func test_mount_exp_and_loyal() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	_spawn_enemy(Vector2i(14, 9))
	lord.mount_up(Mounts.generate("Horse", 1, {"name": "Bayard", "skills": ["Loyal"]}))
	lord.mount.exp = 90
	await b.actions.gain_exp(lord, 30, 15)
	check_eq(lord.mount.level, 2, "the mount levels up from its own EXP")
	check_eq(lord.mount.exp, 5, "leftover mount EXP")
	# Mount EXP is worked out on its own: a young horse under a veteran gains a lot,
	# the veteran little.
	var foe := _spawn_enemy(Vector2i(14, 8))
	foe.level = 10
	lord.level = 18
	var young := Mounts.generate("Horse", 1)
	check(Experience.mount_combat_exp(young, foe, true, true) > Experience.combat_exp(lord, foe, true, true) * 5,
		"the Lv 1 horse gains far more than its Lv 18 rider")
	var old := Mounts.generate("Horse", 10)
	check(Experience.mount_combat_exp(old, foe, true, true) < Experience.mount_combat_exp(young, foe, true, true),
		"and an old mount less than a young one")
	lord.level = 1
	# Loyal: the mount takes the fatal blow.
	var dealt: Array[Unit] = []
	lord.hp = 5
	b.actions._apply_strike(brig, lord, {"hit": true, "crit": false, "dmg": 50}, dealt)
	check_eq(lord.hp, 1, "the rider survives at 1 HP")
	check(lord.mount.is_empty() and lord.unit_class == "Swordsman", "on foot")
	check(lord.biography[-1].begins_with("Lost Bayard"), "biography entry")
	b.actions._apply_strike(brig, lord, {"hit": true, "crit": false, "dmg": 50}, dealt)
	check(lord.hp <= 0, "only once: no mount left to save it")
	# Enemy mounts from rosters scale with the rider's level.
	var nomad := Unit.create("Nomad", Unit.Team.ENEMY, Vector2i.ZERO, {"class": "Archer", "items": ["Iron Bow"],
		"lv": 8, "hp": 20, "str": 6, "dex": 6, "agi": 6, "lck": 2, "def": 4, "mov": 5, "mount": {"species": "Horse"}})
	check_eq(nomad.mount.level, 4, "level 8 rider, level 4 horse")
	check_eq(nomad.class_display_name(), "Nomad", "an Archer on a horse is a Nomad")
	nomad.free()


func test_stable_and_mounted_promotion() -> void:
	await start_chapter(0)
	var rider := Campaign.army_unit("Rider")
	check_eq(rider.unit_class, "Equestrian", "the Rider rides into the campaign")
	check_eq(Campaign.all_mounts().size(), 1, "the stable lists its horse")
	var horse: Dictionary = rider.mount
	Campaign.unassign_mount("Rider")
	check_eq(Campaign.army_unit("Rider").unit_class, "Swordsman", "unassigned: back on foot")
	check_eq(Campaign.stable, [horse], "the horse waits in the stable")
	check_eq(Campaign.ride_problem("Fighter", horse), "", "the Fighter can take it")
	Campaign.assign_mount("Fighter", horse)
	check_eq(Campaign.class_label(Campaign.army_unit("Fighter")), "Raider", "an Axeman on a horse is a Raider")
	check(Campaign.stable.is_empty(), "out of the stable")
	# A mounted unit promotes through its foot class and stays mounted.
	var fighter := Campaign.army_unit("Fighter")
	fighter.level = Classes.PROMOTION_LEVEL
	check(Campaign.can_promote(fighter), "can promote")
	check_eq(Campaign.promotion_options(fighter), ["Berserker"], "the Axeman's promotion")
	Campaign.promote("Fighter", "Berserker")
	fighter = Campaign.army_unit("Fighter")
	check_eq(fighter.foot_class, "Berserker", "promoted on foot")
	check_eq(fighter.unit_class, "Warlord", "and still mounted: a Warlord")
	# The prep screen has a Stable.
	Campaign.save()
	var prep: Control = load("res://scenes/prep.tscn").instantiate()
	root.add_child(prep)
	await process_frame
	check(prep.MENU.has("Stable"), "prep has a Stable")
	prep._enter("stable")
	check_eq(prep._row_count(), 1, "one mount")
	prep.queue_free()


func test_old_saves_get_mounts() -> void:
	var lord := unit_named("Lord")
	var data := SaveGame.unit_to_dict(lord)
	data.unit_class = "Flier"
	data.mount = {}
	data.foot_class = ""
	data.gender = "male"
	data.strength = 7
	var u := SaveGame.unit_from_dict(data)
	check_eq(u.unit_class, "Cavalry", "an old Flier is now Cavalry...")
	check_eq(u.mount.species, "Pegasus", "...on a pegasus")
	check_eq(u.gender, "female", "pegasus riders are female")
	check_eq(u.combat_str(), 7, "effective STR kept")
	u.free()


func test_loyal_steeds_map() -> void:
	await start_level("loyal_steeds")
	var rider := unit_named("Rider")
	var lancer := unit_named("Lancer", Unit.Team.ENEMY)
	check(Skills.has(rider, "Loyal") and Skills.has(unit_named("Pegasus"), "Loyal"), "Loyal mounts on your side")
	check(Skills.has(lancer, "Loyal"), "and on the enemy's")
	# A Loyal enemy survives a fatal blow on foot.
	var dealt: Array[Unit] = []
	b.actions._apply_strike(rider, lancer, {"hit": true, "crit": false, "dmg": 99}, dealt)
	check(lancer.hp == 1 and lancer.mount.is_empty() and lancer.unit_class == "Footman", "the Lancer fights on, on foot")
	# A level 20 rider's mount still earns EXP.
	var veteran := unit_named("Veteran")
	check_eq(veteran.level, Experience.LEVEL_CAP, "a capped rider")
	check(b.actions.earns_exp(veteran), "still earns EXP for its mount")
	await b.actions.gain_exp(veteran, 1, 40)
	check_eq(veteran.exp_points, 0, "the rider gains nothing")
	check_eq(veteran.mount.exp, 40, "the horse gains its own EXP")
	veteran.mount.exp = 95
	await b.actions.gain_exp(veteran, 1, 40)
	check_eq(veteran.mount.level, 2, "and levels up")
	await run_enemy_phases()
