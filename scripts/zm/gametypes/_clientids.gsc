// Pepsi Was Here [Offline RK5/Character Select/Round Timer/Box Patch/Q.E.D. Perk Patch/Fixed Perk Bottles]
// I normally don't riddle my code with comments.
// I made this mod with ZWR in mind, and with a loaded mod, it's really easy to sneak in a cheat.
// So I believe these comments may help with any misunderstandings and to aid verification, if needed.
// I'm not saying that you guys don't know how to read/write code! I just want to be as transparent as possible.
// I say this because whenever I find someone trying to teach me coding, which is what I live and breathe in, I feel immense and utter pain. Like a retards 'how to' on opening a door. I don't like that.
// That's why I'm clarifying. So please don't think much of the comments. Think of them as brail codes on signs that only blind people would really utilize. (Not that you're blind*) No hard feelings.
// If you have questions on the code, feel very free to pop me a dm @pepsied. I'm easy, don't worry.  ;)  ~Pepsi
#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared; // using to link events
#using scripts\shared\system_shared; // using to register mod
#using scripts\shared\array_shared; // using for perk-order and box-patch array helpers
#using scripts\shared\laststand_shared; // using to exclude downed players from the Q.E.D. perk effect
#using scripts\zm\_zm_weapons; // using for giving rk5
#using scripts\zm\_zm_utility; // using for weapon limits
#using scripts\zm\_zm_audio; // using for the stock Q.E.D. perk dialogue
#using scripts\zm\_zm_perks; // using to grant the perk selected by a Q.E.D.
#using scripts\zm\_zm_powerup_free_perk; // using the stock pre-power perk pause helper
#using scripts\zm\_zm_stats; // using to preserve ghost-round free-perk statistics
#insert scripts\shared\shared.gsh;
#insert scripts\zm\_zm_perks.gsh; // using the stock perk identifiers for fixed bottle ordering

#namespace clientids;

REGISTER_SYSTEM("clientids", &__init__, undefined)

// You may see custom map support, and that's bc ZWR also has some custom maps for records.

function __init__() {
    level.PepsiWasHere = []; // used to hold variables like 'MAY_RESTART' (which is utilized by the character selector)
    level.PepsiWasHere["MAY_RESTART"] = 1; // match had just started, allow character selection
	
	// Reset these
	level.PepsiWasHere["HAS_CHAR_SELECTION"] = 0;
	level.PepsiWasHere["IS_CHAR_SELECTION_WORKING"] = 1;
	level.PepsiWasHere["IS_BOX_PATCHED"] = 0;
	level.PepsiWasHere["IS_QED_PERK_PATCHED"] = 0;
	level.PepsiWasHere["IS_PERK_BOTTLE_PATCHED"] = 0;
    map_name = getdvarstring("mapname");

	// Moon fixes character indexes differently than the other maps. Ignore all
	// character-selection dvars there to prevent an impossible restart loop.
	if (map_name == "zm_moon") {
		level.PepsiWasHere["IS_CHAR_SELECTION_WORKING"] = 0;
	}
    
    // Read box_patch only during match initialization so changing the dvar later
    // cannot enable the patch. Nacht der Untoten (zm_prototype) is always stock.
    if ((getdvarint("box_patch", 0) == 1) && (map_name != "zm_prototype")) {
        configure_box_patch_weapons();

        // Only report and hook the patch when this map has a configured list.
        // Unknown/custom maps with no list remain completely stock.
        if (isarray(level.PepsiWasHere["box_patch_weapons"]) && (level.PepsiWasHere["box_patch_weapons"].size > 0)) {
			level.PepsiWasHere["IS_BOX_PATCHED"] = 1;
            level.CustomRandomWeaponWeights = &box_patch_weapon_order;
        }
    }

    // Read qed_perk_patch only during match initialization. The result table and
    // Q.E.D.s exist on Moon, so no other map is permitted to start the installer. Custom maps that ported the QEDs: sorry, not supported
    if ((getdvarint("qed_perk_patch", 0) == 1) && (map_name == "zm_moon")) {
        level thread qed_perk_patch_install_result_dispatcher();
    }

    // Read perk_bottle_patch only during match initialization so it cannot be
    // enabled mid-game. Every other perk source remains completely stock.
    if (getdvarint("perk_bottle_patch", 0) == 1) {
        configure_fixed_perk_bottle_order(map_name);
        level thread fixed_perk_bottle_install();
    }
    
    // Call the function on_player_spawned whenever a player spawns in the map. We give them RK5 there, and check character model, if eligable.
    callback::on_spawned(&on_player_spawned);
    
    // Timer modes:
    // 0 = no timers, 1 = whole-game timer only, 2 = whole-game and round timers.
    timer_mode = getdvarint("do_timers", 0);
    if ((timer_mode == 1) || (timer_mode == 2)) {
        // Our main timer. This timer assumes total match length. Starting from the black screen fades
        run_timer = newhudelem(); // our main timer

        // Round HUD elements are only needed in mode 2. Mode 1 avoids creating
        // or maintaining either of them, leaving only the whole-game timer.
        if (timer_mode == 2) {
            round_timer = newhudelem(); // our round timer
            prev_round_timer = newhudelem(); // our previous-round/intermission timer
            
            level.PepsiWasHere["ROUND_TIMER"] = round_timer;
            level.PepsiWasHere["PREV_ROUND_TIMER"] = prev_round_timer;
        }
        
        // screen & text alignments
        run_timer.horzAlign = "left";
        run_timer.alignX = "left";
        run_timer.vertAlign = "top";
        run_timer.alignY = "top";

        if (timer_mode == 2) {
            round_timer.horzAlign = "left";  prev_round_timer.horzAlign = "left"; // wish I could clone hud elements. >_<
            round_timer.alignX = "left";     prev_round_timer.alignX = "left";
            round_timer.vertAlign = "top";   prev_round_timer.vertAlign = "top";
            round_timer.alignY = "top";      prev_round_timer.alignY = "top";
        }
        
        run_timer.x = getdvarint("run_timer_x", 5); // 5 pixels over
        run_timer.y = getdvarint("run_timer_y", 4); // and 4 pixels down (starting from the 'top' 'left' corners of the screen)

        if (timer_mode == 2) {
            round_timer.x = getdvarint("round_timer_x", 5);   prev_round_timer.x = getdvarint("prev_round_timer_x", 5);
            round_timer.y = getdvarint("round_timer_y", 22);  prev_round_timer.y = getdvarint("prev_round_timer_y", 36); // Adjust by a bit
        }
        
        run_timer.foreground = 1; // I want this to be visible under most circumstances
        run_timer.fontscale = getdvarfloat("run_timer_fontscale", 1.8); // Size of the timer text.

        if (timer_mode == 2) {
            round_timer.foreground = 1;   prev_round_timer.foreground = 1;
            round_timer.fontscale = getdvarfloat("round_timer_fontscale", 1.25);  prev_round_timer.fontscale = getdvarfloat("prev_round_timer_fontscale", 1);
        }
        
        run_timer.alpha = 0; // Make it invisible, so we don't see anything until we want to.
        if (timer_mode == 2) {
            round_timer.alpha = 0;  prev_round_timer.alpha = 0; // and repeat for the other timers
        }

        // Wait for the black screen to completely subside. The start positions for speed runs happens a little before this passing, however. (More on that below)
        level waittill("initial_blackscreen_passed");
        
        // Start the timer as if it started 3 seconds ago.
        // I set the timer to start on 3 because the speed-run rules for when a timer starts, is "Start Position: As soon as the screens fades in"
        // However "initial_blackscreen_passed" is roughly a little over 2.6 seconds BEYOND the screen fade. So -3 is for that 2.6 compensation, with a generous 0.4 margin of error.
        run_timer settimerup(-3); // I'd do settimer(3), only then it would start counting down to zero.
        
        // It's kind of weird to see a timer start at 3 seconds, so to give it that illusion of starting at 0, we have it fade in over 3 seconds. Cheap fix.
        run_timer fadeovertime(3); // And it looks gooder this way.
        run_timer.alpha = getdvarfloat("run_timer_alpha", 1); // begin fade in.

        if (timer_mode == 2) {
            round_timer settimerup(0); // Also start the round intermission timer.
            round_timer fadeovertime(4);
            round_timer.alpha = getdvarfloat("round_timer_alpha", 0.6);
            
            // Here's the funny thing. Either pausing timer hud elements is undocumented, or Treyarch didn't add that capability.
            // So I gotta make a loop to constantly reset the timer to a specifc time to keep it frozen. Brilliant.
            // If you guys know of a method other than manually reseting it, please do let me know. This kind of coding kills me.
            while(1) {
                if (isdefined(level.PepsiWasHere["LAST_DURATION"])) {
                    prev_round_timer fadeovertime(1);
                    prev_round_timer.alpha = getdvarfloat("prev_round_timer_alpha", 0.4); // Fade in over a fraction of a second.
                    while(1) { // Now with each iteration we don't have to check for a IsDefined. Slightly more optimized... yet still an infinite loop.
                        prev_round_timer settimer(level.PepsiWasHere["LAST_DURATION"] + getdvarfloat("timer_offset", 0.8)); // bring the timer back to it's starting point.
                        wait(getdvarfloat("define_check", 0.7)); // I absolutely HATE infinite time-based loops. It just can't be helped. Gotta grit my teeth. >_<
                    }
                }
                wait(getdvarfloat("define_check", 0.9)); // Just keep looping until the round has passed
            }
        }
    }
}

// This function is responsible for notifying the client when a character selection was made.
// It should make it easier for ZWR staff to tell which feature(s) were used.
function autoexec notify_selection() {
	level endon("end_game");
	level endon("restart_round");
	
	level waittill("initial_blackscreen_passed");
	wait(1);

	// Moon returns here without reporting any configured character dvars.
	if (!isdefined(level.PepsiWasHere["IS_CHAR_SELECTION_WORKING"]) || (level.PepsiWasHere["IS_CHAR_SELECTION_WORKING"] != 1)) {
		return;
	}
	
	has_character_selected = level.PepsiWasHere["HAS_CHAR_SELECTION"];
	// Double-layered checking, just to be VERY sure that label is accurate. This is overkill btw.
	if (!has_character_selected) {
		foreach(plr_index, playr in getplayers()) {
			// Get any character preference for that player id.
			char_selection = getdvarint("char_" + plr_index, -1);
			// Check if we have a value set for character.
			if (isdefined(char_selection) && (char_selection > -1)) {
				// Someone has a selection made for character.
				has_character_selected = true;
				break;
			}
		}
	}	
	
	if (has_character_selected) {
		setdvar("restart_attempts", 0); // Drain the attempts to force any restarted attempts back at zero
		// A selection was made
		notify_label = newhudelem();		
		 
		notify_label.horzAlign = "center";
		notify_label.alignX = "center";
		notify_label.vertAlign = "top";
		notify_label.alignY = "top";
		
		// Normally, I allow labels a custom position, fontsize, and transparency...
		// But this label is strictly for reporting when a selection is made and should NOT be customizable.
		notify_label.x = 0;
		notify_label.y = 10;
		
		notify_label.foreground = 1;
		notify_label.fontscale = 1.4;
		
		notify_label.alpha = 0;
		
		notify_label settext("Selections: Character");
		
		notify_label fadeovertime(1); // I dont like abruptly visible text.
		notify_label.alpha = 1; // begin fade in.
		wait(21); // Selection label remains fully visible for 20 seconds at start of match. +1 second to include fade-in
		notify_label fadeovertime(10); // Then it starts a 10 second fade out.
		notify_label.alpha = 0;
		wait(11); // Wait for fade out to fully complete.
		notify_label destroy(); // Then clean up.
	}	
	// I could add another label for when the timers are enabled; but really, the timers being visible should be more than enough lol
}

function autoexec notify_patches() {
	level endon("end_game");
	level endon("restart_round");
	
	level waittill("initial_blackscreen_passed");
	wait(1);
	
	// Patches reporting
	// These flags reflect successful match-start installers; live dvar changes are ignored.
	// I'd double check these, but they actually only enable/activate on specific maps.
	box_patched = level.PepsiWasHere["IS_BOX_PATCHED"];
	qed_perk_patched = level.PepsiWasHere["IS_QED_PERK_PATCHED"];
	perk_bottle_patched = level.PepsiWasHere["IS_PERK_BOTTLE_PATCHED"];
	
	if (box_patched || qed_perk_patched || perk_bottle_patched) {
		// A patch is running
		patch_notify_label = newhudelem();
		 
		patch_notify_label.horzAlign = "center";
		patch_notify_label.alignX = "center";
		patch_notify_label.vertAlign = "top";
		patch_notify_label.alignY = "top";
		
		// Again, no custom positioning or scale
		patch_notify_label.x = 0;
		patch_notify_label.y = 25; // little lower than selections report so the text doesn't overlap with it.
		
		patch_notify_label.foreground = 1;
		patch_notify_label.fontscale = 1.4;
		
		patch_notify_label.alpha = 0;
		
		if (box_patched && qed_perk_patched && perk_bottle_patched) {
			patch_notify_label settext("Patches: Box, QED Perks & Perk Bottles");
		} else if (box_patched && qed_perk_patched) {
			patch_notify_label settext("Patches: Box & QED Perks");
		} else if (box_patched && perk_bottle_patched) {
			patch_notify_label settext("Patches: Box & Perk Bottles");
		} else if (qed_perk_patched && perk_bottle_patched) {
			patch_notify_label settext("Patches: QED Perks & Perk Bottles");
		} else if (box_patched) {
			patch_notify_label settext("Patches: Box");
		} else if (qed_perk_patched) {
			patch_notify_label settext("Patches: QED Perks");
		} else if (perk_bottle_patched) {
			patch_notify_label settext("Patches: Perk Bottles");
		}
		
		patch_notify_label fadeovertime(1); // I *still* dont like abruptly visible text. Thannnk you.
		patch_notify_label.alpha = 1; // begin fade in.
		wait(21); // Patch label remains fully visible for 20 seconds at start of match
		patch_notify_label fadeovertime(10); // Then it starts a 10 second fade out.
		patch_notify_label.alpha = 0;
		wait(11); // Wait for fade out to fully complete.
		patch_notify_label destroy(); // Then clean up.
	}
}

// Whenever a player spawns either returning from bleedout or connecting
function on_player_spawned() {
    self endon("disconnect");
	level endon("end_game");
	level endon("restart_round");
    
    // RK5 time. This code is pulled right out of the COD source files. With some extra safety nets.
    if (getdvarint("rk5", 1) == 1) { // By default on, but optionally allow the user to disable it. Some game types require such to be ZWR-valid.
        weapon_limit = zm_utility::get_player_weapon_limit(self); // let's see what the current player weapon limit is (Perhaps they spawn with mulekick, or maybe have extra/limited space in custom maps)
        self_weapons = self getweaponslistprimaries(); // ironic how pistols are classified as secondary, yet still found in GetWeaponsListPRIMARIES().
        if (self_weapons.size < weapon_limit) { // in the case where a custom map spawns you with no more free weapon slots
            w = level.super_ee_weapon; // Sometimes custom maps like to change this.
            if (!isdefined(w)) { // And if they set it to nothing for some dumb reason...
                w = getweapon("pistol_burst"); // then I got ur rk5 rite here  ;)
            }
            if (isdefined(w)) { // Maybe some custom maps might choose not to load the rk5? lol?
                if (isdefined(level.zombie_weapons[w])) { // Just in case. I want compatability levels at maximum.
                    self zm_weapons::weapon_give(w, false, false, true); // Gotta get the attachments from your loadout (or forced attachments from custom map). And don't forget variants & camos!
                    //Function used: weapon_give(weapon, is_upgrade = false, magic_box = false, nosound = false, b_switch_weapon = true)
                    //You can find the source of zm_weapons::weapon_give at (or around) 'scripts\zm\_zm_weapons:2603'
                }
            }
        }
        
        // I did the ammo thing this way because the other conventional method would have players spawn with 4 grenades. But the ee doesn't modify grenade count. Only ammo.
        foreach(gun in self getweaponslistprimaries()) { // Each gun (MR6/1911 & RK5) excluding equpment like grenades
            self givemaxammo(gun); // And make sure the weapon is maxed in ammo, as does what the actual ee would
        }
    }
    
    
    // Inconsistencies that ONLY concern special custom maps:
    // The RK5 EE will give a player an RK5, and fill there other pistol with max ammo. (Usually from 8/32 to 8/80)
    // There are no official treyarch maps that spawn you with more than 2 weapons (not counting rk5),
    // Therefore I cannot confirm wether or not ALL potential starting weapons get max ammo.
    // For example, a custom map may have you spawn with two default weapons. This mod would then give you a third (rk5, and assuming you have the ability to carry another weapon).
    // But does that second default starting weapon also get max ammo? I can't say since we've only seen the RK5 & the default pistol having max ammo.
    // I tried searching for the dark ops ee code in shared scripting folders, but didn't find anything that would clarify this.
    // So I'm leaning towards yes; all starting guns get max ammo.
    
    
    
    // We don't want to fast restart when the loading screen is still present.
    // Luckily gettime() does NOT reset when the map is restarted.
    if (gettime() < 14000) {
        level waittill("initial_blackscreen_passed");
    }
    
    
    // Check the requested character selection while early restarts are still allowed.
    if ((level.PepsiWasHere["MAY_RESTART"] == 1) && (level.PepsiWasHere["IS_CHAR_SELECTION_WORKING"] == 1)) { // I don't want to restart if the black screen has passed. (cases like bleedouts, new players joining; causing an unwelcome restart)
        self character_selection(); // Check if player is of preference. I would thread this, but if we're going to restart anyways, no point in doing so.
    }
}

// Have this function ran automatically to allow for restarts or not.
function autoexec blackscreen_timeout() {
	level endon("end_game");
	level endon("restart_round");
    level.PepsiWasHere["MAY_RESTART"] = 1; // Allow restarts.
    level waittill("initial_blackscreen_passed"); // Wait until the black screen is gone
    level.PepsiWasHere["MAY_RESTART"] = 0; // Disable auto restarts from now on.
}

// I don't like how you can't press escape to restart the match at the game over screen. Most inefficient. Let's change.
function autoexec end_game_menu_control() {
    level waittill("end_game"); // Wait until the game ends
    setdvar("restart_attempts", 0); // Drain the attempts so that a fresh instance of a match is present.
    wait(0.5); // Small delay before allowing user to restart.
    while (1) {
        setmatchflag("disableIngameMenu", 0); // Allow to open menu at game over screen. So you can press restart.
        wait(0.1);
    }
}

function soft_restart() {
    // These endon's are used to kill the infinite loop down at the bottom
	level endon("end_game");
	level endon("restart_round");
    
    // Enabling of fast_roll will completely skip the breather check. If you don't care about resource limits, and only want speed.... then sure.
    // Defaulted to off, change if needed
	// Fast roll means it wont wait when restarting the level, it restarts back-to-back. You will time out if it goes on for too long. Even in solo play.
    if (getdvarint("fast_roll", 0) == 0) {
        // To reduce the amount of glitches that come from custom maps, we're going to add a restart limit
        setdvar("restart_attempts", getdvarint("restart_attempts", getdvarint("max_restart_attempts", 10)) - 1); // Subtract one from the variable.
        while (getdvarint("restart_attempts", getdvarint("max_restart_attempts", 10)) <= 0) { // We're out of attempts
            // For MAXIMUM saftey enable restart_attempts_blackscreen.
            if (getdvarint("restart_attempts_blackscreen", 0) == 1) {
                level waittill("initial_blackscreen_passed");
            } else { // otherwise just wait no less than 4 seconds for a relatively safer restart. I like a little over 4 seconds to be more safe though.
                wait(getdvarfloat("restart_attempts_delay", 4.5)); // So give the client some breathing room
            }
            setdvar("restart_attempts", getdvarint("max_restart_attempts", 10)); // then restore the attempts.
        }
    }
    WAIT_SERVER_FRAME; // This may alleviate some more server stress. Probably not. :/ Rapid restarts aren't healthy. Especially on custom maps.
    map_restart(); // better luck with RNG next time!
    // Don't return. The function will automatically cancel upon the new restart.
    level waittill("forever");
}

// Characters
// 0: Dempsy / Floyd
// 1: Nicky / Jackie
// 2: Edward / Jesica
// 3: Takeo / Nero

function character_selection() {
	// Defensively reject direct calls on Moon in addition to gating the spawn callback.
	if (!isdefined(level.PepsiWasHere["IS_CHAR_SELECTION_WORKING"]) || (level.PepsiWasHere["IS_CHAR_SELECTION_WORKING"] != 1)) {
		return;
	}

	idx = self.characterIndex; // Get the players' character model index
    // Building solid and ultimately over-killed compatability defenses
    if (isdefined(idx)) {
        // I have to go through a loop to get the player's character id.
        foreach(plr_index, playr in getplayers()) { // I'd use GetLocalClientNumber(), but I'm not sure if that is for splitscreen or not and cant really test it anyways.
            // Check if the iteration is of the player we want
            if (self == playr) {
                // Get the preference for that player id.
                selection = getdvarint("char_" + plr_index, -1);
                // Check if we have a value set, and if it matches the character model index of said player.
                if (selection > -1) {
					level.PepsiWasHere["HAS_CHAR_SELECTION"] = 1;
					if (idx != selection) {
						soft_restart();
						return; // Just in case, I don't want restart_attempts to rejuvenate.
					}
                }
				break; // Break the loop, we got our man.
            }
        }
    }
}

// A function to help track round duration. Will be needed to display duration of previous round.
function getstamp() {
    return floor(gettime() / 1000); // GetTime returns match-time in milliseconds, so we got to devide it by 1000 (1 second in milliseconds) to get it in seconds. And also round it down to an integer using Floor.
}

// This function will monitor round changes and document the durations of them.
// Mode 1 deliberately skips this entire thread because it only displays game time.
function autoexec round_stamp() {
    if (getdvarint("do_timers", 0) == 2) {
        while(1) {
            level waittill("start_of_round"); // Wait for round to start
            level.PepsiWasHere["ROUND_TIMER"] settimerup(0); // Start the round timer
            then = getstamp(); // What time is it? (not adventure time)
            
            level waittill("end_of_round"); // Last zombie died
            level.PepsiWasHere["ROUND_TIMER"] settimerup(0); // Start intermission timer
            duration = getstamp() - then; // And then calculate the difference from now to when the round had started. This is the duration of that round.
            level.PepsiWasHere["PREV_ROUND_TIMER"] settimer(duration); // Set the timer to that duration.
            level.PepsiWasHere["LAST_DURATION"] = duration; // By setting this, we hand over the data to the __init__ loop which will keep the timer frozen using a dumb method.
        }
    }
}

// Build the fixed priority shared by every perk-bottle powerup. Entries not
// registered on the current map are skipped, so one list safely supports stock
// maps and custom maps without granting perks that their scripts did not load.
function configure_fixed_perk_bottle_order(map_name) {
    perk_order = [];
    perk_tail = [];
    perk_order[perk_order.size] = PERK_JUGGERNOG; // Juggernog is always the first eligible perk. Can't go wrong with that.
	perk_order[perk_order.size] = PERK_QUICK_REVIVE; // Gotta get them self revives early.
    perk_order[perk_order.size] = PERK_STAMINUP; // Gimme dat early speed.
	
	// Electric cherry useful for frying spiders. God I hate those things
	if ((map_name == "zm_island") || (map_name == "zm_genesis")) { // Check for map Zetsubou / Revelations
        perk_order[perk_order.size] = PERK_ELECTRIC_CHERRY;
    }
	
    perk_order[perk_order.size] = PERK_DOUBLETAP2;
	
    // Widow's Wine is normally early in the order. Moon moves it to the tail
    // because breaking the glass can permanently alter the run. So annoying.
    if (map_name != "zm_moon") {
        perk_order[perk_order.size] = PERK_WIDOWS_WINE;
    }

    perk_order[perk_order.size] = PERK_SLEIGHT_OF_HAND;
	
	if ((map_name != "zm_island") && (map_name != "zm_genesis")) {
		perk_order[perk_order.size] = PERK_ELECTRIC_CHERRY;
	}
    perk_order[perk_order.size] = PERK_DEAD_SHOT;

    perk_tail[perk_tail.size] = PERK_ADDITIONAL_PRIMARY_WEAPON; // Mule Kick is last on every map besides Moon.
    if (map_name == "zm_moon") {
        perk_tail[perk_tail.size] = PERK_WIDOWS_WINE; // Moon: Mule Kick second-to-last, Widow's Wine last.
    }

    level.PepsiWasHere["fixed_perk_bottle_order"] = perk_order;
    level.PepsiWasHere["fixed_perk_bottle_tail"] = perk_tail;
}

// The stock registration API intentionally refuses to overwrite an existing
// grab function. Wait for the stock free_perk registration, then replace only
// that function pointer after the other system initializers have settled.
function fixed_perk_bottle_install() {
    level endon("end_game");
    level endon("restart_round");

    // Round 100 and later must use the untouched stock handler.
    if (isdefined(level.round_number) && (level.round_number >= 100)) {
        return;
    }

    registration_checks_remaining = 100; // Five seconds is ample for startup registration without leaving a permanent polling thread.
    while (!isdefined(level._custom_powerups) ||
        !isdefined(level._custom_powerups["free_perk"]) ||
        !isdefined(level._custom_powerups["free_perk"].grab_powerup)) {
        registration_checks_remaining--;
        if (registration_checks_remaining <= 0) {
            return; // Maps without the stock free-perk powerup need no replacement handler.
        }
        wait(0.05);
    }
    wait(0.1);

    // Registration may complete on the same frame that the cap is reached.
    if (isdefined(level.round_number) && (level.round_number >= 100)) {
        return;
    }

    level.PepsiWasHere["fixed_perk_bottle_stock_grab_func"] = level._custom_powerups["free_perk"].grab_powerup;
    level._custom_powerups["free_perk"].grab_powerup = &fixed_perk_bottle_grab;
    level.PepsiWasHere["IS_PERK_BOTTLE_PATCHED"] = 1;
    level thread fixed_perk_bottle_restore_after_round_cap();
}

// Preserve the stock grab callback shape: self is the bottle powerup and the
// supplied player is unused because this powerup rewards every living player.
function fixed_perk_bottle_grab(player) {
    // The inline cap check closes the brief gap before the restoration thread
    // runs and guarantees stock behavior as soon as round 100 begins.
    if ((level.PepsiWasHere["IS_PERK_BOTTLE_PATCHED"] != 1) ||
        (isdefined(level.round_number) && (level.round_number >= 100))) {
        return self [[level.PepsiWasHere["fixed_perk_bottle_stock_grab_func"]]](player);
    }

    level thread fixed_perk_bottle_powerup(self);
}

// Restore the exact grab callback that was present before this patch. This
// preserves custom-map handlers as well as Treyarch's stock random behavior.
function fixed_perk_bottle_restore_after_round_cap() {
    level endon("end_game");
    level endon("restart_round");

    while (!isdefined(level.round_number) || (level.round_number < 100)) {
        wait(0.25);
    }

    if (isdefined(level._custom_powerups) &&
        isdefined(level._custom_powerups["free_perk"]) &&
        isdefined(level.PepsiWasHere["fixed_perk_bottle_stock_grab_func"])) {
        level._custom_powerups["free_perk"].grab_powerup = level.PepsiWasHere["fixed_perk_bottle_stock_grab_func"];
    }
    level.PepsiWasHere["IS_PERK_BOTTLE_PATCHED"] = 0;
}

// Stock free-perk behavior with only give_random_perk replaced. Ghost-round
// stats, downed/spectator exclusions, power-state handling, and map callbacks
// are deliberately preserved.
function fixed_perk_bottle_powerup(item) {
    players = getplayers();
    for (i = 0; i < players.size; i++) {
        if (!players[i] laststand::player_is_in_laststand() && (players[i].sessionstate != "spectator")) {
            player = players[i];

            if (isdefined(item.ghost_powerup)) {
                player zm_stats::increment_client_stat("buried_ghost_perk_acquired", false);
                player zm_stats::increment_player_stat("buried_ghost_perk_acquired");
                player notify("player_received_ghost_round_free_perk");
            }

            fixed_perk = player fixed_perk_bottle_give_next();

            if (IS_TRUE(level.disable_free_perks_before_power)) {
                player thread zm_powerup_free_perk::disable_perk_before_power(fixed_perk);
            }

            if (isdefined(fixed_perk) && isdefined(level.perk_bought_func)) {
                player [[level.perk_bought_func]](fixed_perk);
            }
        }
    }
}

// Give the first registered perk in the configured order that this player does
// not already own and does not currently have paused. Unlisted custom perks are
// alphabetized and inserted before the protected map-specific tail.
function fixed_perk_bottle_give_next() {
    if (!isdefined(level._custom_perks)) {
        self playsoundtoplayer(level.zmb_laugh_alias, self);
        return undefined;
    }

    ordered_perks = [];
    perk_order = level.PepsiWasHere["fixed_perk_bottle_order"];
    perk_tail = level.PepsiWasHere["fixed_perk_bottle_tail"];

    foreach(perk in perk_order) {
        if (isdefined(level._custom_perks[perk]) && !array::contains(ordered_perks, perk)) {
            ordered_perks[ordered_perks.size] = perk;
        }
    }

    // Registration order is not used as hidden RNG for unknown custom perks.
    // Sorting by identifier keeps their fallback order stable across matches.
    registered_perks = getarraykeys(level._custom_perks);
    registered_perks = array::alphabetize(registered_perks);
    foreach(perk in registered_perks) {
        if (!array::contains(ordered_perks, perk) && !array::contains(perk_tail, perk)) {
            ordered_perks[ordered_perks.size] = perk;
        }
    }

    foreach(perk in perk_tail) {
        if (isdefined(level._custom_perks[perk]) && !array::contains(ordered_perks, perk)) {
            ordered_perks[ordered_perks.size] = perk;
        }
    }

    foreach(perk in ordered_perks) {
        if (isdefined(self.perk_purchased) && (self.perk_purchased == perk)) {
            continue;
        }

        if (!self hasperk(perk) && !(self zm_perks::has_perk_paused(perk))) {
            self zm_perks::give_perk(perk);
            return perk;
        }
    }

    // Match stock behavior when the player has every registered perk.
    self playsoundtoplayer(level.zmb_laugh_alias, self);
    return undefined;
}

// Add weapon names to the appropriate map array below. Example:
//
// level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"][0] = "octobomb";
// level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"][1] = "weapon_name_here";
//
// Indices must be consecutive and start at zero. Invalid names and weapons that
// are not in the current map's mystery box are ignored safely.
function configure_box_patch_weapons() {
    level.PepsiWasHere["box_patch_weapon_lists"] = [];

    // Shadows of Evil
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"][0] = "octobomb"; // Li'l Arnie
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"][1] = "idgun_0"; // Kor-Maroth
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"][2] = "idgun_1"; // Mar-Astagua
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"][3] = "idgun_2"; // Nar-Ullagua
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_zod"][4] = "idgun_3"; // Lor-Zarozzor

    // The Giant
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_factory"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_factory"][0] = "tesla_gun"; // Wunderwaffe DG-2
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_factory"][1] = "cymbal_monkey"; // Monkey Bomb

    // Der Eisendrache
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_castle"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_castle"][0] = "cymbal_monkey"; // Monkey Bomb

    // Zetsubou No Shima
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_island"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_island"][0] = "cymbal_monkey"; // Monkey Bomb
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_island"][1] = "hero_mirg2000"; // KT-4 (after it has been built and lost)
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_island"][2] = "pistol_shotgun_dw"; // Marshal 16 (Pepsi's thrasher slayer)

    // Gorod Krovi
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_stalingrad"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_stalingrad"][0] = "raygun_mark3"; // GKZ-45 Mk3
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_stalingrad"][1] = "cymbal_monkey"; // Monkey Bomb

    // Revelations
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_genesis"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_genesis"][0] = "idgun_genesis_0"; // Apothicon Servant
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_genesis"][1] = "thundergun"; // Thundergun
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_genesis"][2] = "octobomb"; // Li'l Arnie
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_genesis"][3] = "hero_gravityspikes_melee"; // Ragnarok DG-4

    // Verruckt
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_asylum"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_asylum"][0] = "raygun_mark2"; // Ray Gun Mark II
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_asylum"][1] = "tesla_gun"; // Wunderwaffe DG-2
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_asylum"][2] = "cymbal_monkey"; // Monkey Bomb
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_asylum"][3] = "hero_annihilator"; // Annihilator

    // Shi No Numa
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_sumpf"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_sumpf"][0] = "raygun_mark2"; // Ray Gun Mark II
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_sumpf"][1] = "tesla_gun"; // Wunderwaffe DG-2
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_sumpf"][2] = "cymbal_monkey"; // Monkey Bomb
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_sumpf"][3] = "hero_annihilator"; // Annihilator

    // Kino der Toten
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_theater"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_theater"][0] = "raygun_mark2"; // Ray Gun Mark II
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_theater"][1] = "thundergun"; // Thundergun
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_theater"][2] = "cymbal_monkey"; // Monkey Bomb
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_theater"][3] = "hero_annihilator"; // Annihilator

    // Ascension
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_cosmodrome"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_cosmodrome"][0] = "raygun_mark2"; // Ray Gun Mark II
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_cosmodrome"][1] = "thundergun"; // Thundergun
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_cosmodrome"][2] = "black_hole_bomb"; // Gersh Device
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_cosmodrome"][3] = "nesting_dolls"; // Matryoshka Dolls
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_cosmodrome"][4] = "hero_annihilator"; // Annihilator

    // Shangri-La
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_temple"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_temple"][0] = "raygun_mark2"; // Ray Gun Mark II
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_temple"][1] = "shrink_ray"; // 31-79 JGb215
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_temple"][2] = "cymbal_monkey"; // Monkey Bomb
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_temple"][3] = "hero_annihilator"; // Annihilator

    // Moon
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_moon"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_moon"][0] = "raygun_mark2"; // Ray Gun Mark II
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_moon"][1] = "microwavegundw"; // Zap Gun Dual Wield / Wave Gun
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_moon"][2] = "black_hole_bomb"; // Gersh Device
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_moon"][3] = "quantum_bomb"; // Q.E.D.
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_moon"][4] = "hero_annihilator"; // Annihilator

    // Origins
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_tomb"] = [];
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_tomb"][0] = "raygun_mark2"; // Ray Gun Mark II
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_tomb"][1] = "cymbal_monkey"; // Monkey Bomb
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_tomb"][2] = "beacon"; // G-Strike (after it has been obtained and lost)
    level.PepsiWasHere["box_patch_weapon_lists"]["zm_tomb"][3] = "hero_annihilator"; // Annihilator

    map_name = getdvarstring("mapname");
    if (isdefined(level.PepsiWasHere["box_patch_weapon_lists"][map_name])) {
        level.PepsiWasHere["box_patch_weapons"] = level.PepsiWasHere["box_patch_weapon_lists"][map_name];
    } else {
        // Unknown/custom maps use normal box behavior unless added above.
        level.PepsiWasHere["box_patch_weapons"] = [];
    }
}

// _zm_magicbox calls this as a player method before its normal validity pass.
// Preferred candidates are shuffled and moved to the front. The stock chooser
// then returns the first candidate that is in the box, not already owned (or an
// upgrade of an owned weapon), below its quota, usable, and valid for the map.
function box_patch_weapon_order(normal_weapons) {
    if (!isarray(normal_weapons) || (normal_weapons.size == 0)) {
        return normal_weapons;
    }

    // Use only the state captured during initialization. The explicit map check
    // keeps Nacht stock even if this callback is assigned by another script.
    if ((level.PepsiWasHere["IS_BOX_PATCHED"] != 1) || (getdvarstring("mapname") == "zm_prototype")) {
        return normal_weapons;
    }

    // ZWR box patching is allowed only through the end of round 19.
    // Round 20 and every round after it receive the untouched stock order.
    if (!isdefined(level.round_number) || (level.round_number >= 20)) {
        return normal_weapons;
    }

    if (!isarray(level.PepsiWasHere["box_patch_weapons"]) || (level.PepsiWasHere["box_patch_weapons"].size == 0)) {
        return normal_weapons;
    }

    preferred_names = array::randomize(level.PepsiWasHere["box_patch_weapons"]);
    ordered_weapons = [];

    // Match names against the real candidate objects instead of calling
    // GetWeapon on config strings. That makes typos/invalid names harmless.
    foreach(preferred_name in preferred_names) {
        foreach(weapon in normal_weapons) {
            if (weapon.name == preferred_name && !array::contains(ordered_weapons, weapon)) {
                ordered_weapons[ordered_weapons.size] = weapon;
                break;
            }
        }
    }

    // Preserve every ordinary box candidate as the fallback pool.
    foreach(weapon in normal_weapons) {
        if (!array::contains(ordered_weapons, weapon)) {
            ordered_weapons[ordered_weapons.size] = weapon;
        }
    }

    return ordered_weapons;
}

// -----------------------------------------------------------------------------
// Q.E.D. PERK PATCH
//
// This patch is installed only when qed_perk_patch was explicitly enabled before
// match start, the current map is Moon. The dvar is
// intentionally not read again here, so changing it during a game cannot enable
// the patch after the match has already started.
//
// Moon's normal Q.E.D. watcher already detects the grenade, waits for it to
// explode, and starts exactly one registered result. 
// This code leaves the watcher alone and temporarily redirects its
// result table through one dispatcher.
//
// Every registered stock result is copied before anything is changed. While the
// patch is active, one existing result entry acts as the dispatcher and all
// other live chances are zeroed. The dispatcher either forces the perk result
// near a machine or manually selects exactly one result from the preserved stock
// table. The original result functions, validation functions, and chances are
// restored when round 20 begins, leaving the patch active only through round 19.
// -----------------------------------------------------------------------------
function qed_perk_patch_install_result_dispatcher() {
    // __init__ already restricts installation to Moon. This second check makes
    // the function safe if it is ever called directly by another script.
    if (getdvarstring("mapname") != "zm_moon") {
        return;
    }

    // This RNG patch is permitted only through the end of round 19. Do not touch
    // the stock table if installation somehow begins on round 20 or later.
    if (isdefined(level.round_number) && (level.round_number >= 20)) {
        return;
    }

    // Q.E.D. results are registered by more than one stock script, and their
    // initialization order is not guaranteed from this file. Wait until both
    // the perk result and the entry used as our dispatcher carrier exist.
    while (!isdefined(level.quantum_bomb_results) ||
        !isdefined(level.quantum_bomb_results["give_nearest_perk"]) ||
        !isdefined(level.quantum_bomb_results["zombie_fling"])) {
        // Never install late if Moon's registration was delayed past the cap.
        if (isdefined(level.round_number) && level.round_number >= 20) {
            return;
        }
        wait(0.05);
    }

    // Give other Q.E.D. registration threads one final moment to add their
    // entries. This helps ensure the snapshot below contains the full table.
    wait(0.1);

    // Registration can finish on the same frame that round 20 begins, so check
    // the cap once more before mutating any stock result.
    if (isdefined(level.round_number) && level.round_number >= 20) {
        return;
    }

    // An empty table cannot be safely redirected or restored.
    keys = getarraykeys(level.quantum_bomb_results);
    if (keys.size == 0) {
        return;
    }

    level.PepsiWasHere["qed_perk_patch_stock_results"] = [];
    for (i = 0; i < keys.size; i++) {
        result = level.quantum_bomb_results[keys[i]];

        // Copy each field into a new struct instead of saving a reference to the
        // live result. Otherwise the chance and callback edits below would also
        // overwrite the values we need for stock selection and restoration.
        stock_result = spawnstruct();
        stock_result.name = result.name;
        stock_result.result_func = result.result_func;
        stock_result.chance = result.chance;
        stock_result.validation_func = result.validation_func;
        level.PepsiWasHere["qed_perk_patch_stock_results"][keys[i]] = stock_result;

        // Remove this result from the live selector. Its untouched chance and
        // callbacks remain available in qed_perk_patch_stock_results.
        result.chance = 0;
    }

    // Reuse one known, already-registered entry as the dispatcher carrier. Its
    // name is unimportant while patched because both callbacks are replaced.
    // A chance of 100 plus an always-true validator guarantees that the stock
    // Q.E.D. watcher starts this dispatcher as its one and only live result.
    dispatcher = level.quantum_bomb_results["zombie_fling"];
    dispatcher.chance = 100;
    dispatcher.validation_func = &qed_perk_patch_dispatcher_validation;
    dispatcher.result_func = &qed_perk_patch_dispatch_result;
    level.PepsiWasHere["IS_QED_PERK_PATCHED"] = 1;
    level thread qed_perk_patch_restore_after_round_cap();
}

// The dispatcher must always pass the stock result-selection validation step.
// Whether the throw qualifies for a forced perk is decided inside the result
// function, where it can safely fall back to a preserved stock result.
function qed_perk_patch_dispatcher_validation(position) {
    return true;
}

function qed_perk_patch_dispatch_result(position) {
    // Force the perk outcome only while the match-start installation is active,
    // only on Moon, only before round 20, and only when the Q.E.D. exploded
    // within the stock perk-result range of at least one perk-machine trigger.
    // The match-start flag is used instead of re-reading the dvar.
    if (level.PepsiWasHere["IS_QED_PERK_PATCHED"] == 1 &&
        getdvarstring("mapname") == "zm_moon" &&
        isdefined(level.round_number) && level.round_number < 20 &&
        qed_perk_patch_near_machine(position)) {
        self qed_perk_patch_give_nearest_perk(position);
        return;
    }

    // Throws that do not qualify must remain vanilla. This thread is already the
    // single result thread created by Moon's stock watcher, so select and execute
    // one preserved result here. Starting another result thread would allow two
    // effects from one Q.E.D.
    result = self qed_perk_patch_select_stock_result(position);
    self [[result.result_func]](position);
}

// Reproduce the stock selector using the preserved table rather than the live
// table, whose chances currently point only to our dispatcher. This keeps every
// non-qualifying throw on its normal random path.
function qed_perk_patch_select_stock_result(position) {
    // Stock result validators share these caches. Clear them before performing a
    // fresh validation pass for this throw, matching the normal selector.
    level.quantum_bomb_cached_in_playable_area = undefined;
    level.quantum_bomb_cached_closest_zombies = undefined;

    eligible_results = [];
    chance = randomint(100);
    keys = getarraykeys(level.PepsiWasHere["qed_perk_patch_stock_results"]);

    for (i = 0; i < keys.size; i++) {
        result = level.PepsiWasHere["qed_perk_patch_stock_results"][keys[i]];

        // A result is eligible only if it passes both its original chance
        // threshold and its original position/entity validation function.
        if (result.chance > chance && self [[result.validation_func]](position)) {
            eligible_results[eligible_results.size] = result.name;
        }
    }

    // The stock selector randomly chooses one entry from all eligible results.
    return level.PepsiWasHere["qed_perk_patch_stock_results"][eligible_results[randomint(eligible_results.size)]];
}

// The patch is legal only through round 19. As soon as round 20 begins, put every
// result back exactly as it was before installation and clear the active flag.
function qed_perk_patch_restore_after_round_cap() {
    while (!isdefined(level.round_number) || (level.round_number < 20)) {
        level waittill("start_of_round");
    }

    keys = getarraykeys(level.PepsiWasHere["qed_perk_patch_stock_results"]);
    for (i = 0; i < keys.size; i++) {
        // A different script may have removed an entry after installation. Skip
        // missing entries instead of recreating something that no longer exists.
        if (!isdefined(level.quantum_bomb_results[keys[i]])) {
            continue;
        }

        // Restore the original probability and both original callbacks. This
        // also turns zombie_fling back from our carrier into its stock result.
        stock_result = level.PepsiWasHere["qed_perk_patch_stock_results"][keys[i]];
        result = level.quantum_bomb_results[keys[i]];
        result.chance = stock_result.chance;
        result.validation_func = stock_result.validation_func;
        result.result_func = stock_result.result_func;
    }
    level.PepsiWasHere["IS_QED_PERK_PATCHED"] = 0;
}

// Return true when the explosion position is within the stock 15-foot Q.E.D.
// perk range of any registered perk-machine trigger. DistanceSquared avoids an
// unnecessary square-root calculation for every machine.
function qed_perk_patch_near_machine(position) {
    vending_triggers = getentarray("zombie_vending", "targetname");
    range_squared = 180 * 180; // Stock range: 15 feet.

    for (i = 0; i < vending_triggers.size; i++) {
        if (distancesquared(vending_triggers[i].origin, position) < range_squared) {
            return true;
        }
    }

    return false;
}

// Deterministic version of the stock give_nearest_perk result. Randomness has
// already been removed by the dispatcher; this function preserves the stock
// effect, nearest-machine choice, and multiplayer recipient behavior.
function qed_perk_patch_give_nearest_perk(position) {
    // Play Moon's normal Q.E.D. mystery effect at the explosion before granting
    // anything. Maps/scripts without the optional callback are handled safely.
    if (isdefined(level.quantum_bomb_play_mystery_effect_func)) {
        [[level.quantum_bomb_play_mystery_effect_func]](position);
    }

    vending_triggers = getentarray("zombie_vending", "targetname");
    if (vending_triggers.size == 0) {
        // This should not happen after the range check, but avoid indexing an
        // empty array if the machine list changed between the two functions.
        return;
    }

    // The qualifying range check may have found more than one nearby machine.
    // Match the stock perk result by using whichever trigger is closest to the
    // actual Q.E.D. explosion.
    nearest = 0;
    for (i = 1; i < vending_triggers.size; i++) {
        if (distancesquared(vending_triggers[i].origin, position) < distancesquared(vending_triggers[nearest].origin, position)) {
            nearest = i;
        }
    }

    players = getplayers();
    // Perk-machine triggers store the perk identifier in script_noteworthy.
    perk = vending_triggers[nearest].script_noteworthy;
    for (i = 0; i < players.size; i++) {
        player = players[i];

        // Vanilla rewards every eligible player, not only the person who threw
        // the Q.E.D. Spectators and players currently downed are excluded.
        if (player.sessionstate == "spectator" || player laststand::player_is_in_laststand()) {
            continue;
        }

        // Do not duplicate a perk the player owns or is already in the process
        // of purchasing. Only the thrower plays the successful Q.E.D. dialogue,
        // while every player who receives the perk gets the stock player effect.
        if (!player hasperk(perk) && (!isdefined(player.perk_purchased) || player.perk_purchased != perk)) {
            if (player == self) {
                self thread zm_audio::create_and_play_dialog("kill", "quant_good");
            }

            player zm_perks::give_perk(perk);
            if (isdefined(level.quantum_bomb_play_player_effect_func)) {
                player [[level.quantum_bomb_play_player_effect_func]]();
            }
        }
    }
}
