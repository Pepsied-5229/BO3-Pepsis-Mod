# BO3 Pepsi's Mod

A Black Ops III Zombies quality-of-life and ZWR-oriented mod.

[Steam Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3291945384)

## Enabling features

Load the mod, set the desired dvars, and then start the map. The box, Q.E.D. perk, and fixed perk-bottle patches read their settings during match initialization and cannot be enabled midway through a game.

Example configuration:

```cfg
\modvar rk5 1
\modvar do_timers 2
\modvar char_0 -1
\modvar box_patch 0
\modvar qed_perk_patch 0
\modvar perk_bottle_patch 0
```

Change only the features you want. Settings that are not relevant to the current map are safely ignored.

## Features

### Offline RK5 / Super Easter Egg reward

Enable with:

```cfg
\modvar rk5 1
```

This feature is enabled by default. Set `rk5` to `0` to disable it.

- Gives each player the map's configured Super Easter Egg starting weapon when they spawn.
- Falls back to the RK5 when the map does not define another reward weapon.
- Respects the player's current weapon limit.
- Refills all primary-weapon ammunition without changing grenade counts.
- Also applies when a player returns from bleedout or joins an active match.

### Character selection

Set a desired character for each player slot:

```cfg
\modvar char_0 0
\modvar char_1 -1
\modvar char_2 -1
\modvar char_3 -1
```

Character values:

| Value | Character |
|---:|---|
| `-1` | No selection |
| `0` | Dempsey / Floyd |
| `1` | Nikolai / Jackie |
| `2` | Richtofen / Jessica |
| `3` | Takeo / Nero |

When a selected player receives the wrong character, the mod restarts the map and rolls again. Restart enforcement is permitted only during initial match startup, so bleedouts and late joins cannot restart an active game.

Character selection is completely ignored on Moon because Moon uses fixed character indexes that would otherwise cause an impossible restart loop.

Optional restart-safety settings:

| Dvar | Default | Purpose |
|---|---:|---|
| `fast_roll` | `0` | Set to `1` to skip the restart breather entirely. This is faster but less stable. |
| `max_restart_attempts` | `10` | Number of rapid restart attempts allowed before taking a breather. |
| `restart_attempts_blackscreen` | `0` | Set to `1` to wait for the black screen to pass when the attempt limit is reached. |
| `restart_attempts_delay` | `4.5` | Breather duration when black-screen waiting is disabled. |

### Whole-game and round timers

Choose a timer mode:

```cfg
\modvar do_timers 2
```

| Value | Timer mode |
|---:|---|
| `0` | No timers |
| `1` | Whole-game timer only |
| `2` | Whole-game timer, current-round timer, and previous-round duration |

The whole-game timer compensates for the delay between the visible screen fade and the `initial_blackscreen_passed` event. Round mode tracks each round from `start_of_round` to `end_of_round` and preserves the completed round's duration on the HUD.

Optional HUD settings:

| Dvar | Default |
|---|---:|
| `run_timer_x` | `5` |
| `run_timer_y` | `4` |
| `run_timer_fontscale` | `1.8` |
| `run_timer_alpha` | `1` |
| `round_timer_x` | `5` |
| `round_timer_y` | `22` |
| `round_timer_fontscale` | `1.25` |
| `round_timer_alpha` | `0.6` |
| `prev_round_timer_x` | `5` |
| `prev_round_timer_y` | `36` |
| `prev_round_timer_fontscale` | `1` |
| `prev_round_timer_alpha` | `0.4` |
| `timer_offset` | `0.8` |

### First-box weapon patch

Enable before starting the match:

```cfg
\modvar box_patch 1
```

The configured special-weapon list is randomized on each box selection and moved ahead of the ordinary weapon pool. The normal mystery-box validation still decides whether a weapon is actually present, usable, under its quota, and not already owned by the buyer. Invalid or unavailable configured weapons are ignored, and all ordinary box weapons remain available as fallback.

The patch works only through the end of round 19. Round 20 and later use the untouched box order.

Nacht der Untoten is always excluded. Unknown and unsupported custom maps remain completely natural and do not report the patch as active.

Supported map lists:

| Map | Preferred weapons/equipment |
|---|---|
| Shadows of Evil | Li'l Arnie; Kor-Maroth; Mar-Astagua; Nar-Ullagua; Lor-Zarozzor |
| The Giant | Wunderwaffe DG-2; Monkey Bomb |
| Der Eisendrache | Monkey Bomb |
| Zetsubou No Shima | Monkey Bomb; KT-4 after it has been built and lost; Marshal 16 |
| Gorod Krovi | GKZ-45 Mk3; Monkey Bomb |
| Revelations | Apothicon Servant; Thundergun; Li'l Arnie; Ragnarok DG-4 |
| Verrückt | Ray Gun Mark II; Wunderwaffe DG-2; Monkey Bomb; Annihilator |
| Shi No Numa | Ray Gun Mark II; Wunderwaffe DG-2; Monkey Bomb; Annihilator |
| Kino der Toten | Ray Gun Mark II; Thundergun; Monkey Bomb; Annihilator |
| Ascension | Ray Gun Mark II; Thundergun; Gersh Device; Matryoshka Dolls; Annihilator |
| Shangri-La | Ray Gun Mark II; 31-79 JGb215; Monkey Bomb; Annihilator |
| Moon | Ray Gun Mark II; Zap Guns/Wave Gun; Gersh Device; Q.E.D.; Annihilator |
| Origins | Ray Gun Mark II; Monkey Bomb; G-Strike after it has been obtained and lost; Annihilator |

The standard Ray Gun is not included in any preferred list.

### Moon Q.E.D. perk patch

Enable before starting Moon:

```cfg
\modvar qed_perk_patch 1
```

- Available only on Moon.
- Works only through the end of round 19.
- A Q.E.D. that explodes within the stock 15-foot range of a perk machine always triggers the nearest machine's perk result.
- Every living, non-downed, non-spectating player receives that perk if they do not already own or currently have it in the purchase process.
- Throws away from perk machines execute exactly one preserved stock Q.E.D. result.
- The original Q.E.D. result chances and callbacks are restored when round 20 starts.

Changing the dvar during an active match cannot enable the patch.

### Fixed perk-bottle ordering

Enable before starting the match:

```cfg
\modvar perk_bottle_patch 1
```

This removes randomness only from the free-perk bottle powerup. Other perk sources remain stock.

The normal priority is:

1. Juggernog
2. Quick Revive
3. Stamin-Up
4. Double Tap
5. Widow's Wine
6. Speed Cola
7. Electric Cherry
8. Deadshot Daiquiri
9. Registered custom perks in alphabetical order
10. Mule Kick

Special ordering:

- Zetsubou No Shima and Revelations move Electric Cherry ahead of Double Tap.
- Moon moves Mule Kick to second-to-last and Widow's Wine to last.
- Perks not registered by the current map are skipped safely.

The bottle rewards every living, non-downed, non-spectating player with the first eligible perk they do not already own. Ghost-round statistics, pre-power behavior, and existing map callbacks are preserved. The previous stock or custom handler is restored at round 100.

### Startup disclosure

The mod automatically displays:

- `Selections: Character` when character selection was configured.
- The successfully installed Box, Q.E.D. Perks, and Perk Bottles patches, including combined labels when several are active.

Unsupported patches are not falsely reported. Moon never reports character selection.

### End-game restart access

The in-game menu is automatically re-enabled after game over so the player can open the menu and restart the map.

## Additional included features

These existing mod features are active while the mod is loaded:

- Unlocks weapons, camos, attachments, and GobbleGums.
- Adds map-restart access in-game and at the game-over screen.
- Randomizes the displayed player rank/level as a cosmetic effect.

GobbleGum-cycle selection and automatic rolling are not included.
