# EnhaPrio Rebuffed

Version 1.0.1

## Changes

- 1.0.1: During Spell Disruption (Heigan the Unclean) and Disciplinary Shout (Instructor Razuvious) no hardcasts are shown.

EnhaPrio Rebuffed shows the enhancement shaman priority for Whitemane / Frostmourne Rebuffed (WoW 3.3.5a). It is
based on EnhaPrio 1.1.1 by Stormcast.

## Installation

Copy the `EnhaPrio` folder to `Interface\AddOns`. It replaces the original EnhaPrio and reads its saved settings.

## Priority profiles

The decision logic is new. A right-click on the display switches to the next profile instead of toggling AoE.

| Profile | Weapon imbues | Priority |
|---|---|---|
| `+LB` | Spell | single target with hardcast Lava Burst |
| `NoFN` | Spell | `+LB` without Fire Nova while the Fire Elemental Totem stands |
| `-LB` | Spell | single target without hardcast Lava Burst |
| `4MSW` | Spell | `-LB`, Lightning Bolt only from 4 Maelstrom stacks |
| `5MSW` | Spell | `-LB`, Lightning Bolt only from 5 Maelstrom stacks |
| `AOE` | Spell | 3 targets, Maelstrom into Chain Lightning |
| `WF` | Windfury | single target |
| `WF AOE` | Windfury | 3 targets |

- **Weapon imbues** selects the build. Spell is Flametongue on both weapons. Windfury is Windfury main hand, Flametongue off hand.
- Only the profiles of the chosen build take part.
- **Right-click cycles through** sets which profiles take part; **Up** and **Down** set their order.
- An earth or air totem missing puts Call of the Elements first, Call of the Spirits while the Fire Elemental stands.
- In the single-target Spell profiles, Lava Surge (the Rebuffed Doomhammer proc) gives an instant Lava Burst.
- Shamanistic Rage is used on cooldown with the T10 2-piece bonus. The 1.1.1 low mana threshold is not read.

## Display

- Side column, bottom up: Fire Elemental, Feral Spirit, racial, glove use.
- The Fire Elemental shows while the proc of the strongest worn proc trinket is up, without such a trinket at once.
- Interrupt and purge windows: white border when possible now, red when not.

## New options

| Option | Default | Effect |
|---|---|---|
| **Weapon imbues** | Spell | build for the profiles |
| **Always show** | off | the queue also without a hostile target |
| **Always show profile name** | off | profile name under the icon while the display is shown; otherwise on mouseover and for 3 s after a switch |
| **Profile selector** | off | one box per ticked profile of the build; a left-click switches |
| **Resize** | off | size grip on the display and the selector while not locked |
| **... only on bosses** | on | Feral Spirit and Fire Elemental icons only on bosses |
| **Interrupt window** | on | interrupt icon for a hostile target's cast |
| **Purge window** | on | purge icon for a hostile target's magic buff |
| **Glove use icon** | on | glove use in the side column |
| **Racial icon** | on | Blood Fury, on trolls Berserking |
| **Shamanistic Rage below mana %** | 20 | Shamanistic Rage below this mana |

With ElvUI loaded the selector uses ElvUI's colours and font.

## Commands

| Command | Effect |
|---|---|
| `/epr`, `/enhaprio-rebuffed` | opens the options; `/ep` and `/enhaprio` of 1.1.1 are gone |
| `/epr debug` | switches recording on or off: each display change, at most 3000 lines, saved at `/reload` |
