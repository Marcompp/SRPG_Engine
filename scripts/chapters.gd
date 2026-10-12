class_name Chapters
extends RefCounted
## Campaigns and their chapters (see Campaign). Each campaign is a folder in
## data/campaigns/ (listed by its index.cfg): campaign.cfg, with
##   name, description: shown on the level select.
##   chapters:        chapter ids, in play order (files in its chapters/ folder).
##   start_gold:      the army's funds when it starts (default Campaign.START_GOLD).
## A chapter is played by the campaign's one persistent army. Same format as Levels,
## plus:
##   deploy:          player starting cells, in order (the Lord takes the first);
##                    its size is the number of units the chapter allows.
##   recruits:        units (roster format) that join the army at this chapter.
##   objective:       see Objectives.
##   objects:         villages, chests and shops (see BattleMap.objects).
##   reward:          gold for winning the chapter (docs/economy.md).
##   shop:            what the prep screen's Shop sells before it (default:
##                    Shop.DEFAULT_STOCK).
##   reinforcements:  [{"turn": N, "units": [enemy roster entries]}]; they appear at
##                    the start of enemy phase N and act from the next one.
## Chapters have no "players": the army is deployed from the prep screen. Chapter ids
## are unique across every campaign and test map (saves and Levels.get_level use them).

const DIR := "campaigns"

## {campaign id: campaign.cfg's keys}, in index order.
static var CAMPAIGNS := _load_campaigns()

## Every chapter of every campaign, by id.
static var DATA := _load_chapters()

## The selected campaign's chapters (see Campaign.select), in play order.
static var ORDER: Array[String] = order_of(CAMPAIGNS.keys()[0])


## The chapter ids of `campaign`, in play order.
static func order_of(campaign: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(CAMPAIGNS[campaign].chapters)
	result.make_read_only()
	return result


static func _load_campaigns() -> Dictionary:
	var result := {}
	for id in GameData.strings(DIR + "/index", "", "order"):
		result[id] = GameData.section(DIR + "/" + id + "/campaign", "")
	result.make_read_only()
	return result


static func _load_chapters() -> Dictionary:
	var result := {}
	for id: String in CAMPAIGNS:
		var chapters := GameData.folder(DIR + "/" + id + "/chapters", CAMPAIGNS[id].chapters)
		for chapter: String in chapters:
			assert(not result.has(chapter), "chapter id used twice: " + chapter)
			result[chapter] = chapters[chapter]
	result.make_read_only()
	return result


## Which campaign a chapter belongs to ("" for none).
static func campaign_of(chapter: String) -> String:
	for id: String in CAMPAIGNS:
		if CAMPAIGNS[id].chapters.has(chapter):
			return id
	return ""
