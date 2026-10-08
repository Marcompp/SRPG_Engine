class_name Items
extends RefCounted
## Inventory items. A unit's inventory holds weapons (see Weapons) and consumables.
## Weapons are the entries with "mt"; everything else here is a consumable.

## kind "heal": restores `heal` HP to the user. kind "mp": restores `mp` MP.
## Using an item ends the unit's turn.
const CONSUMABLES := {
	"Potion": {"kind": "heal", "heal": 15, "uses": 3},
	"Ether": {"kind": "mp", "mp": 15, "uses": 3},
	# Opens a chest (one use per chest). Rogue-movement units open chests without one.
	"Chest Key": {"kind": "key", "uses": 1},
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
	return false
