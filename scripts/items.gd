class_name Items
extends RefCounted
## Inventory items. A unit's inventory holds weapons (see Weapons) and consumables.
## Weapons are the entries with "mt"; everything else here is a consumable.

## kind "heal": restores `heal` HP to the user. kind "mp": restores `mp` MP.
## kind "scroll": teaches `skill` for good (see Skills; a full unit picks one to forget).
## kind "repair": restores one of the user's weapons to full uses (broken ones too).
## Using an item ends the unit's turn.
## Any item (or weapon) can list "skills": held items grant them while in the
## inventory, weapons only while equipped. Items without "uses" never run out.
const CONSUMABLES := {
	"Potion": {"kind": "heal", "heal": 15, "uses": 3},
	"Ether": {"kind": "mp", "mp": 15, "uses": 3},
	# Opens a chest (one use per chest). Rogue-movement units open chests without one.
	"Chest Key": {"kind": "key", "uses": 1},
	"Repair Kit": {"kind": "repair", "uses": 2},
	"Celerity Scroll": {"kind": "scroll", "skill": "Celerity", "uses": 1},
	"Vigor Scroll": {"kind": "scroll", "skill": "Strength +2", "uses": 1},
	# Held items with skills.
	"Power Ring": {"kind": "ring", "skills": ["Strength +2"]},
	"Speed Ring": {"kind": "ring", "skills": ["Speed +2"]},
}


## Returns a fresh copy of a weapon or consumable (so each unit tracks its own uses).
static func make(item_name: String) -> Dictionary:
	if Weapons.DATA.has(item_name):
		return Weapons.make(item_name)
	var item: Dictionary = CONSUMABLES[item_name].duplicate()
	item.name = item_name
	return item


static func is_weapon(item: Dictionary) -> bool:
	return item.has("mt")


## Whether `user` gets anything out of using this item right now.
static func can_use(user: Unit, item: Dictionary) -> bool:
	match item.get("kind", ""):
		"heal":
			return user.hp < user.max_hp
		"mp":
			return user.mp < user.max_mp
		"scroll":
			return not Skills.has(user, item.skill)
		"repair":
			return user.items.any(func(it): return Items.is_weapon(it) and it.uses < Weapons.max_uses(it))
	return false


## "Name  uses" for menus ("broken" for broken weapons), or just the name for items
## that never run out.
static func label(item: Dictionary, sep := "  ") -> String:
	if is_weapon(item) and Weapons.is_broken(item):
		return item.name + sep + "broken"
	return "%s%s%d" % [item.name, sep, item.uses] if item.has("uses") else item.name
