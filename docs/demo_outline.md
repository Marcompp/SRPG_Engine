# Demo campaign: The Princess Is Out (outline)

Working outline for the 10-chapter proof of concept. Agreed as a starting point
("fine for now"): expect it to change once chapters are built and played. Goals: a
small, lighthearted, self-contained story; every chapter built around one strong
gameplay concept, preferring mechanics the engine already has.

## Premise

Princess Rosalind has never left the palace gardens, and her coming-of-age ceremony is
ten days away. Before a lifetime of opening bridges, she wants to see the sea. She goes
over the wall one night in a "commoner" disguise that fools nobody, and lands in front
of the **Copper Kettle Company**: a small, broke mercenary band that came to collect a
payment and was turned away. She hires them to take her to the coast, promising a
reward she can't pay yet.

**Captain Amaryllis Thorne** of the Royal Guard is sent to bring her back: competent,
tireless, and always one chapter behind. Running gag: chapters end with the Guard
arriving on an empty battlefield and finding a clue. The finale pays it off: the Guard
finally arrives in time, and helps.

**The real troublemaker:** Prince Fabian, her pompous suitor from the neighbouring
kingdom, who wants to win her hand by "rescuing" her. He hires bandits to stage a
kidnapping and frames the mercenaries for it.

## The Royal Guard (recurring mechanic)

On some maps the Guard arrives as reinforcements on a set turn: yellow, never
attacking, heading straight for Rosalind. If a guard ends its move next to her, she's
**caught** and the chapter must be retried. Block them, Shove them aside, or just
finish first; winning in time plays the arrived-too-late scene. The arrival turn is set
per chapter. Used in chapters 2, 4, 7 and 9, so it doesn't get stale (chapter 3 dropped it:
its yellow crowd would count as catchers).

## Cast

| Character | Class | Notes |
|---|---|---|
| Rosalind ("Rose, a commoner") | Lord, Mage | Learned her magic from books. Low stats, high growths, endless enthusiasm |
| Captain Doran Vey | Swordsman | Leads the company. Tired, broke, secretly kind |
| Bex | Axeman | Loud. Thinks everything is a great adventure |
| Fennick | Rogue | Knew she was the princess at once; hasn't said so, because it's funnier |
| Mags | Cleric | Medic and cook. Mothers everyone |
| Juniper | Archer | Quiet; the company's best shot |
| Sir Hollow | Ghost | Ch 5. A manor ghost, lonely for 200 years |
| Wren | (rival mercenary) | Ch 6. Defects from the rival company |
| Sir Plinth | Stoneborn | Ch 7. A palace garden statue that came alive and followed her on foot |
| Moth | Fairy | Ch 8. A bored swamp fairy |

Rosalind gets a pegasus in chapter 7.

## Chapters

| # | Chapter | Gameplay concept | Story beat | Joins |
|---|---|---|---|---|
| 1 | Over the Wall (built) | **Sneaking out.** Escape: Rosalind to the gate. Palace guards doze at their posts (sleeper AI with a wake radius); waking them closes routes. The enemies are burglars who broke in the same night | She climbs out and meets the company, who are robbing the kitchen of what they were owed | Rosalind, Doran, Bex, Fennick, Mags |
| 2 | Honest Work (built) | **First job, with the Guard clock.** Rout bandits from a farmstead before the Guard arrives on turn 8. Teaches the caught rule | Rosalind insists on helping, badly. The Guard finds a grateful farmer | Juniper |
| 3 | Market Day (built) | **Cut him off.** A market town full of neutral townsfolk, who let the thieves slip past but block the company; a thief steals her tiara and runs for the gate (objective `getaway`: lose if he reaches it). Shop on the prep screen and a stall on the map. No Guard clock (the crowd is yellow); Thorne has a cameo in the ending | Her first shopping; she doesn't understand money | – |
| 4 | The Ferry | **Ships.** Ferry the army across a wide river (Board, Unload) while river pirates raid. The Guard arrives on the far bank | The Guard watches the ferry leave | – |
| 5 | The Haunted Manor | **Dungeon crawl.** A paid job: evict the "ghosts". Doors, keys, Lockpick, cracked walls, chests; the ghosts are harmless, the burglars aren't. Seize the study | The company finally gets paid | Sir Hollow |
| 6 | The Tourney | **Three-way fight.** Village tournament: the company, a rival company and bandits who crashed it. Talk a rival over. Thorne entered in disguise | Thorne almost catches her and loses on a technicality | Wren |
| 7 | Wings | **Mounts.** A ranch gives Rosalind a pegasus (female riders only, as built), then a mountain pass of archers and harpies | She flies for the first time and refuses to land | Sir Plinth |
| 8 | The Wandering Lights | **Status effects.** A swamp fairy casts Sleep, Silence and Berserk; Rosalind is silenced and has to use her staff | The fairy was only bored | Moth |
| 9 | The Kidnapping | **Split army.** Fabian's staged kidnapping: Rosalind starts in a cell with a few units, the company on the far side; break through and meet in the middle | Fabian frames the company; the Guard now thinks they're the kidnappers | – |
| 10 | The Sea | **Turn the Guard.** Seaside festival: the Guard attacks the company, Fabian's bandits attack everyone. Rosalind reaches Thorne and talks her over, then together they defeat Fabian | The Guard arrives on time, at last. She sees the sea | – |

Arcs: 1-4 the escape and the road, 5-8 odd jobs and growing up, 9-10 the frame-up and
the reckoning.

## Engine work it needs

- **The Guard: built.** Objective `"caught_by": "neutral"` (losing if a unit of that
  side is ever next to the Lord; a carried Lord is safe; the danger zone shows the catch
  zone), the `pursuer` AI preset (`move: "follow"`, no attacks), and `protect` now
  meaning "falls" so the Guard can be protected before it arrives. The Guard arrives by
  `@spawn` with `event_units` (team "neutral"). Test map: Royal Pursuit.
- **Ch 1: built.** A `wake` event trigger; sleepers' wake radius counts any unit not
  friendly to their side (so neutral watchmen notice the player); a sleeping catcher
  catches nobody, and the danger zone shows its wake radius instead.
- **Ch 9:** two separate starting groups for the player (deploy cells may already do it).

Everything else exists: escape, defend a tile, sleeper AI, thieves, shops, ships,
doors and chests, three factions, talking units over, mounts and the pegasus rider
rule, statuses, reinforcements.

## Open questions

- **Rosalind's class:** Mage (book-learned, so the Lord plays unlike a sword Lord), or a
  classic rapier Swordsman? Default: Mage.
- **Ending:** she goes home on her own terms (company on retainer), or stays with the
  company with the King's grudging blessing? Default: goes home.
- **Permadeath:** keep it with soft wording ("too hurt to go on"), or have demo units
  retreat instead of dying? Undecided.
- **The current 5-chapter campaign:** kept. The demo becomes a second campaign
  (`data/campaigns/`), and the Border March stays as the test suite's campaign.
