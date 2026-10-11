class_name Items
extends RefCounted
## Inventory items. A unit's inventory holds weapons (see Weapons) and consumables.
## Weapons are the entries with "mt"; everything else here is a consumable.

## kind "heal": restores `heal` HP to the user. kind "mp": restores `mp` MP.
## kind "cure": cures the user's `cures` status (every status when it has none).
## kind "scroll": teaches `skill` for good (see Skills; a full unit picks one to forget).
## kind "repair": restores one of the user's weapons to full uses (broken ones too).
## Using an item ends the unit's turn.
## Any item (or weapon) can list "skills": held items grant them while in the
## inventory, weapons only while equipped. Items without "uses" never run out.
static var CONSUMABLES := GameData.entries("items")


## Price of a fresh one, in gold (docs/economy.md). Items not listed have no price:
## they can't be bought or sold.
static var PRICES := GameData.section("economy", "prices")


static func cost(item_name: String) -> int:
	return PRICES.get(item_name, 0)


## What an item is worth now: its price, times uses left over max uses (a broken
## weapon is worth nothing). Items that never run out are worth their price.
static func value(item: Dictionary) -> int:
	var price := cost(item.name)
	if not item.has("uses"):
		return price
	var most: int = Weapons.max_uses(item) if is_weapon(item) else CONSUMABLES[item.name].uses
	return floori(price * float(item.uses) / most)


## What a shop pays for it: half its value. 0: it can't be sold.
static func sell_price(item: Dictionary) -> int:
	return floori(value(item) / 2.0)


## Gold to restore a weapon to full uses: the price of the uses it's missing.
static func repair_cost(weapon: Dictionary) -> int:
	var most := Weapons.max_uses(weapon)
	return ceili(cost(weapon.name) * float(most - weapon.uses) / most)


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
	if Statuses.restricts(user, "items"):
		return false
	match item.get("kind", ""):
		"heal":
			return user.hp < user.max_hp
		"mp":
			return user.mp < user.max_mp
		"cure":
			return user.statuses.has(item.cures) if item.has("cures") else not user.statuses.is_empty()
		"scroll":
			return not Skills.has(user, item.skill)
		"repair":
			return user.items.any(func(it): return Items.is_weapon(it) and it.uses < Weapons.max_uses(it))
	return false


## "Name  uses" for menus ("broken" for broken weapons), or just the name for items
## that never run out.
static func label(item: Dictionary, sep := "  ") -> String:
	if is_weapon(item) and Weapons.is_broken(item):
		return item.name + sep + TranslationServer.translate("broken")
	return "%s%s%d" % [item.name, sep, item.uses] if item.has("uses") else item.name
