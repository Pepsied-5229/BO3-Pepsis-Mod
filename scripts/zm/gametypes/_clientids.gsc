// Pepsi Was Here [Offline RK5/Character Select/Round Timer]
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
#using scripts\shared\array_shared; // using for gobble gum auto-restarter
#using scripts\zm\_zm_weapons; // using for giving rk5
#using scripts\zm\_zm_utility; // using for weapon limits
#insert scripts\shared\shared.gsh;

#namespace clientids;

REGISTER_SYSTEM("clientids", &__init__, undefined)

// You may see custom map support, and that's bc ZWR also has some custom maps for records.
// Plus I won't be using this mod PURELY for ZWR runs.

function __init__() {
    level.PepsiWasHere = []; // used to hold variables like 'MAY_RESTART' (which is utilized by the character selector)
    level.PepsiWasHere["MAY_RESTART"] = 1; // match had just started, allow character selection
    
    // Call the function on_player_spawned whenever a player spawns in the map. We give them RK5 there, and check character model, if eligable.
    callback::on_spawned(&on_player_spawned);
    
    // Ability to disable the timer, if needed or wanted.
    if (getdvarint("do_timers", 1) == 1) {
        // Our main timer. This timer assumes total match length. Starting from the black screen fades
        run_timer = newhudelem(); // our main timer
        round_timer = newhudelem(); // our round timer
        prev_round_timer = newhudelem(); // our previous-round/intermission timer
        
        level.PepsiWasHere["ROUND_TIMER"] = round_timer;
        level.PepsiWasHere["PREV_ROUND_TIMER"] = prev_round_timer;
        
         // screen & text alignments
        run_timer.horzAlign = "left";  round_timer.horzAlign = "left";  prev_round_timer.horzAlign = "left"; // wish I could clone hud elements. >_<
        run_timer.alignX = "left";     round_timer.alignX = "left";     prev_round_timer.alignX = "left";
        run_timer.vertAlign = "top";   round_timer.vertAlign = "top";   prev_round_timer.vertAlign = "top";
        run_timer.alignY = "top";      round_timer.alignY = "top";      prev_round_timer.alignY = "top";
        
        run_timer.x = getdvarint("run_timer_x", 5); // 5 pixels over
        run_timer.y = getdvarint("run_timer_y", 4); // and 4 pixels down (starting from the 'top' 'left' corners of the screen)
        
        round_timer.x = getdvarint("round_timer_x", 5);   prev_round_timer.x = getdvarint("prev_round_timer_x", 5);
        round_timer.y = getdvarint("round_timer_y", 22);  prev_round_timer.y = getdvarint("prev_round_timer_y", 36); // Adjust by a bit
        
        run_timer.foreground = 1; // I want this to be visible under most circumstances
        run_timer.fontscale = getdvarfloat("run_timer_fontscale", 1.8); // Size of the timer text.
        
        round_timer.foreground = 1;   prev_round_timer.foreground = 1;
        round_timer.fontscale = getdvarfloat("round_timer_fontscale", 1.25);  prev_round_timer.fontscale = getdvarfloat("prev_round_timer_fontscale", 1);
        
        run_timer.alpha = 0; // Make it invisible, so we don't see anything until we want to.
        round_timer.alpha = 0;  prev_round_timer.alpha = 0; // and repeat for the other timers

        // Wait for the black screen to completely subside. The start positions for speed runs happens a little before this passing, however. (More on that below)
        level waittill("initial_blackscreen_passed");
        
        // Start the timer as if it started 3 seconds ago.
        // I set the timer to start on 3 because the speed-run rules for when a timer starts, is "Start Position: As soon as the screens fades in"
        // However "initial_blackscreen_passed" is roughly a little over 2.6 seconds BEYOND the screen fade. So -3 is for that 2.6 compensation, with a generous 0.4 margin of error.
        run_timer settimerup(-3); // I'd do settimer(3), only then it would start counting down to zero.
        
        round_timer settimerup(0); // Also start the round intermission timer.
        
        // It's kind of weird to see a timer start at 3 seconds, so to give it that illusion of starting at 0, we have it fade in over 3 seconds. Cheap fix.
        run_timer fadeovertime(3); // And it looks gooder this way.
        run_timer.alpha = getdvarfloat("run_timer_alpha", 1); // begin fade in.
        
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
    
    
    // For character & bgb selections.
    if (level.PepsiWasHere["MAY_RESTART"] == 1) { // I don't want to restart if the black screen has passed. (cases like bleedouts, new players joining; causing an unwelcome restart)
        self character_selection(); // Check if player is of preference. I would thread this, but if we're going to restart anyways, no point in doing so.
        self bgb_selection(); // Check if first-first gobble gum is of preference.
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
    setdvar("restart_attempts", getdvarint("max_restart_attempts", 14)); // Now restore the restart attempts since we have already had a game going.
    wait(2); // Small delay before allowing user to restart.
    while (1) {
        setmatchflag("disableIngameMenu", 0); // Allow to open menu at game over screen. So you can press restart.
        wait(0.1);
    }
}

function soft_restart() {
    // These endon's are used to hopefully kill the infinite loop down at the bottom
	level endon("end_game");
	level endon("restart_round");
    
    // Enabling of fast_roll will completely skip the breather check. If you don't care about resource limits, and only want speed.... then sure.
    // Defaulted to off, change if needed
	// Fast roll means it wont wait when restarting the level, it restarts back-to-back. You will time out if it goes on for too long.
    if (getdvarint("fast_roll", 0) == 0) {
        // To reduce the amount of glitches that come from custom maps, we're going to add a restart limit
        setdvar("restart_attempts", getdvarint("restart_attempts", getdvarint("max_restart_attempts", 14)) - 1); // Subtract one from the variable.
        while (getdvarint("restart_attempts", getdvarint("max_restart_attempts", 14)) <= 0) { // We're out of attempts
            // For MAXIMUM saftey enable restart_attempts_blackscreen.
            if (getdvarint("restart_attempts_blackscreen", 0) == 1) {
                level waittill("initial_blackscreen_passed");
            } else { // otherwise just wait no less than 3 seconds for a relatively safer restart. I like a little over 3 seconds to be more safe though.
                wait(getdvarfloat("restart_attempts_delay", 3.5)); // So give the client some breathing room
            }
            setdvar("restart_attempts", getdvarint("max_restart_attempts", 14)); // then restore the attempts.
        }
    }
    WAIT_SERVER_FRAME; // This may alleviate some more server stress. Probably not. :/ Rapid restarts aren't healthy. Especially on custom maps.
    map_restart(); // better luck with RNG next time!
    // Don't return.
    level waittill("forever");
}

// Characters
// 0: Dempsy
// 1: Nicky
// 2: Edward
// 3: Takeo

function character_selection() {
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
                if ((selection > -1) && (idx != selection)) {
                    soft_restart();
                    return; // Just in case, I don't want restart_attempts to rejuvenate.
                }
            }
            break; // Break the loop...
        }
    }
    //setdvar("restart_attempts", 5);
}

function bgb_get_array() {
    if (isdefined(self)) {
    // I'd call a function directly from zm_bgb.gsc, only there is no function that *just* sets the cycle if unset. Similar to powerup cycles.
        if (isdefined(self.bgb_pack) && (self.bgb_pack.size != 0)) {
            if (!isdefined(self.bgb_pack_randomized) || (self.bgb_pack_randomized.size == 0)) { // We check size because the selection of a gum is 'popped' (removed) out of the array; reducing it's size
                // I could technically keep randomizing this until it's right, without map restarting... However, that may interfere with other random-based features of the map.
                // which could lead to unnatural RNG. Taking no chances.
                // And I won't stand for anything but natrual. So, sorry, you're gonna have to let it auto restart until it's perfect. The strat better be worth it lol
                self.bgb_pack_randomized = array::randomize(self.bgb_pack); // Code directly from Treyarch (ran when user uses the gobble gum machine for the first time of that cycle)
            }
        }
    }
}

// First-first gobble gum cycle checker (Called only if custom cyucle is defined)
function bgb_selection() {
    foreach(plr_index, playr in getplayers()) {
        if (self == playr) {
            // Rough Chance formula ((1 / 5) ^ Num_Selections) * ((1 / 4) ^ Num_Character_Selections)
            // Assuming everyone has a full custom pack, and a character selection, you'll get your miracle game in about 1 of 24,414,062,500,000,000 restarts. Have fun waiting for that one...
            // Assuming one player has a custom character and all gum selection: 1 / 12500
            // Assuming one player has all gum selection: 1 / 3125
            for (gum_slot = 0; gum_slot < 5; gum_slot++) { // Sure.... customize your WHOLE pack... What a selfish little one you are. You're gonna be restarting for like... 4 entire minutes.
                // bgb_0_0 3 means to make sure player 1's first gum is that of the 4th gum in his/her pack.
                // bgb_0_1 1 means to make sure player 1's second gum is that of the 2nd gum in his/her pack.
                selection = getdvarint("bgb_" + plr_index + "_" + gum_slot, -1);
                if (isdefined(selection) && (selection > -1) && isdefined(self.bgb_pack) && (self.bgb_pack.size != 0) && isdefined(self.bgb_pack[selection])) {
                    // Treyarch doesn't like setting a cycle until a player needs to access it.
                    // So we're just going to do exactly what they do at match-start.
                    // The game will not re-randomize this cycle once it's in place.
                    self bgb_get_array(); // set the pack if not already...
                    
                    if (isdefined(self.bgb_pack_randomized[gum_slot])) { // first make sure bgb packs are even relevant
                        // I'd use array:pop_front() like treyarch does... only I don't want to actually remove a gum from the array. I just wanna read it
                        next_bgb = self.bgb_pack_randomized[gum_slot]; // array::pop_front() takes off the first value and shifts the other keys. But we don't want to 'take' or 'shift' directly. So we'll just read.
                        if (isdefined(next_bgb) && (self.bgb_pack[selection] != next_bgb)) { // Looks like you didn't get your 1 in 5 chance.
                            soft_restart(); // Better luck next time! See ya in a few. ;)
                            return;
                        }
                    }
                }
            }
        }
    }
}

// A function to help track round duration. Will be needed to display duration of previous round.
function getstamp() {
    return floor(gettime() / 1000); // GetTime returns match-time in milliseconds, so we got to devide it by 1000 (1 second in milliseconds) to get it in seconds. And also round it down to an integer using Floor.
}

// This function will monitor round changes and document the durations of them.
function autoexec round_stamp() {
    if (getdvarint("do_timers", 1) == 1) {
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