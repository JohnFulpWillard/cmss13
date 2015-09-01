//This file deals with distress beacons. It randomizes between a number of different types when activated.
//There's also an admin commmand which lets you set one to your liking.

//basic persistent gamemode stuff.
/datum/game_mode
	var/list/datum/emergency_call/all_calls = list() //initialized at round start and stores the datums.
	var/datum/emergency_call/picked_call = null //Which distress call is currently active
	var/has_called_emergency = 0
	var/distress_cooldown = 0

//The distress call parent. Cannot be called itself due to "name" being a filtered target.
/datum/emergency_call
	var/name = "name"
	var/mob_max = 0
	var/dispatch_message = "An encrypted signal has been received from a nearby vessel. Stand by." //Msg to display when starting
	var/arrival_message = "" //Msg to display about when the shuttle arrives
	var/objectives //Txt of objectives to display to joined. Todo: make this into objective notes
	var/probability = 0 //Chance of it occuring. Total must equal 100%
	var/list/datum/mind/members = list() //Currently-joined members.
	var/list/datum/mind/candidates = list() //Potential candidates for enlisting.
	var/waiting_for_candidates = 0 //Are we waiting on people to join?
	var/role_needed = BE_RESPONDER //Obsolete
	var/name_of_spawn = "Distress" //If we want to set up different spawn locations
	var/mob/living/carbon/leader = null //Who's leading these miscreants

//Weyland Yutani commandos. Friendly to USCM, hostile to xenos.
/datum/emergency_call/pmc
	name = "Commandos"
	mob_max = 6
	arrival_message = "USS Sulaco, this is USCSS Royce responding to your distress call. We are boarding. Any hostile actions will be met with lethal force."
	objectives = "Secure the Corporate Liason and the Sulaco Commander, and eliminate any hostile threats. Do not damage W-Y property."
	probability = 40

//Supply drop. Just docks and has a crapload of stuff inside.
/datum/emergency_call/supplies
	name = "Supply Drop"
	mob_max = 0
	arrival_message = "Weyland Yutani Automated Supply Drop 334-Q signal received. Docking procedures have commenced."
	probability = 5

//Randomly-equipped mercenaries. Neutral to Weyland Yutani.
/datum/emergency_call/mercs
	name = "Mercenaries"
	mob_max = 5
	arrival_message = "USS Sulaco, this is mercenary vessel MC-98 responding to your distress call. Prepare for boarding."
	objectives = "Help or hinder the crew of the Sulaco. Take what you want as payment. Do what your Captain says. Ensure your survival at all costs."
	probability = 20

//Xeeenoooooossss
/datum/emergency_call/xenos
	name = "Xenomorphs"
	mob_max = 6
	arrival_message = "USS Sulaco, this is USS Vriess respond-- #&...*#&^#.. signal.. oh god, they're in the vent---... Priority Warning: Signal lost."
	objectives = "Screeee! FoRr tHe HIvE!"
	probability = 15
	role_needed = BE_ALIEN

//Russian 'iron bear' mercenaries. Hostile to everyone.
/datum/emergency_call/bears
	name = "Iron Bears"
	mob_max = 4
	arrival_message = "Incoming Transmission: 'Vrag korabl'! Podgotovka k posadke i smerti!'"
	objectives = "Kill everything that moves. Blow up everything that doesn't. Listen to your superior officers. Help or hinder the Sulaco crew at your officer's discretion."
	probability = 15

//Terrified pizza delivery
/datum/emergency_call/pizza
	name = "Pizza Delivery"
	mob_max = 1
	arrival_message = "Incoming Transmission: 'That'll be.. sixteen orders of cheesy fries, eight large double topping pizzas, nine bottles of Four Loko.. hello? Is anyone on this ship? Your pizzas are getting cold.'"
	objectives = "Make sure you get a tip!"
	probability = 5


/datum/game_mode/proc/initialize_emergency_calls()
	if(all_calls.len) //It's already been set up.
		return

	var/list/total_calls = typesof(/datum/emergency_call)
	if(!total_calls.len)
		world << "\red \b Error setting up emergency calls, no datums found."
		return 0
	for(var/S in total_calls)
		var/datum/emergency_call/C= new S()
		if(!C)	continue
		if(C.name == "name") continue //The default parent, don't add it
		all_calls += C
	spawn(0)
		world << "Emergency distress beacons powering up. Total call types: \b [all_calls.len]."


//Randomizes and chooses a call datum.
/datum/game_mode/proc/get_random_call()
	var/chance = rand(1,100)
	var/add_prob = 0
	var/datum/emergency_call/chosen_call

	for(var/datum/emergency_call/E in all_calls) //Loop through all potential candidates
		if(chance >= E.probability + add_prob) //Tally up probabilities till we find which one we landed on
			add_prob += E.probability
			continue
		chosen_call = E //Our random chance found one.
		break

	if(!istype(chosen_call))
		world << "\red Something went wrong with emergency calls. Tell a coder!"
		return null
	else
		return chosen_call

/datum/emergency_call/proc/show_join_message()
	if(!mob_max || !ticker || !ticker.mode) //Just a supply drop, don't bother.
		return

	var/list/datum/mind/possible_joiners = ticker.mode.get_players_for_role(role_needed) //Default role_needed is BE_RESPONDER
	for(var/mob/dead/observer/M in player_list)
		if(M.client && M.mind && M.mind in possible_joiners)
			M << "<font size='3'>\red An emergency beacon has been activated. Use the Join Response Team verb, IC tab, to join!</font>"

/datum/game_mode/proc/activate_distress()
	picked_call = get_random_call()
	if(!istype(picked_call,/datum/emergency_call)) //Something went horribly wrong
		return

	picked_call.activate()
	spawn(0)
		has_called_emergency = 1
	return

/datum/emergency_call/proc/activate()
	if(!ticker || !ticker.mode) //Something horribly wrong with the gamemode ticker
		return

	if(ticker.mode.has_called_emergency) //It's already been called.
		return

	if(mob_max > 0)
		waiting_for_candidates = 1
	show_join_message() //Show our potential candidates the message to let them join.
	message_admins("Distress beacon: '[src.name]' activated. Looking for candidates.", 1)
	command_announcement.Announce("A distress beacon has been launched from the USS Sulaco.", "Alert")
	spawn(600) //If after 60 seconds we aren't full, abort
		if(candidates.len < mob_max)
			waiting_for_candidates = 0
			ticker.mode.has_called_emergency = 0
			members = list() //Empty the members list.
			candidates = list()
			message_admins("Aborting distress beacon, not enough candidates found.", 1)
			command_announcement.Announce("Attention: Distress beacon received no signal. Aborting attempt.", "Distress Beacon")
			ticker.mode.distress_cooldown = 1
			spawn(900)
				ticker.mode.distress_cooldown = 0
		else //we got enough!
			command_announcement.Announce(dispatch_message, "Distress Beacon")
			message_admins("Distress beacon finalized, setting up candidates.", 1)
			if(candidates.len)
				for(var/datum/mind/M in candidates)
					members += M
					create_member(M)
			spawn(1800) //After 2.5 minutes, send the arrival message. Should be about the right time they make it there.
				command_announcement.Announce(arrival_message, "Distress Beacon")
		return

/datum/emergency_call/proc/add_candidate(var/mob/M)
	if(!waiting_for_candidates) return
	if(!M.mind || !M.client) return //Not connected
	if(M.mind in members) return //Already there.
	if(!istype(M,/mob/dead/observer) && !istype(M,/mob/new_player)) return //Something went wrong

	candidates += M.mind

/datum/emergency_call/proc/get_spawn_point()
	var/list/spawn_list = list()

	for(var/obj/effect/landmark/L in landmarks_list)
		if(L.name == name_of_spawn) //Default is "Distress"
			spawn_list += L

	var/turf/spawn_loc	= get_turf(pick(spawn_list))
	if(!istype(spawn_loc))
		return null

	return spawn_loc

/datum/emergency_call/proc/create_member(var/datum/mind/M) //This is the parent, each type spawns its own variety.
	return

/datum/emergency_call/pmc/create_member(var/datum/mind/M)
	var/turf/spawn_loc = get_spawn_point()
	var/mob/original = M.current

	if(!istype(spawn_loc)) return //Didn't find a useable spawn point.

	var/mob/living/carbon/human/mob = new(spawn_loc)
	mob.gender = pick(MALE,FEMALE)
	var/datum/preferences/A = new()
	A.randomize_appearance_for(mob)
	if(mob.gender == MALE)
		mob.real_name = "PMC [pick(first_names_male)] [pick(last_names)]"
	else
		mob.real_name = "PMC [pick(first_names_female)] [pick(last_names)]"
	mob.name = mob.real_name
	mob.age = rand(17,45)
	mob.dna.ready_dna(mob)
	M.transfer_to(mob)
	mob.mind.assigned_role = "MODE"
	mob.mind.special_role = "W-Y PMC LEADER"
	ticker.mode.traitors += mob.mind
	spawn(0)
		if(!leader)       //First one spawned is always the leader.
			leader = mob
			spawn_officer(mob)
			mob << "<font size='3'>\red You are the PMC Commando leader!</font>"
			mob << "<B> You must lead the PMCs to victory against any and all hostile threats.</b>"
			mob << "<B> Ensure no damage is incurred against Weyland Yutani.</b>"
		else
			if(prob(65)) //Randomize the heavy commandos and standard PMCs.
				spawn_standard(mob)
				mob << "<font size='3'>\red You are a Weyland Yutani Commando!</font>"
			else
				spawn_heavy(mob)
				mob << "<font size='3'>\red You are a Weyland Yutani Heavy Commando!</font>"
	spawn(10)
		M << "<B>Objectives:</b> [objectives]"

	if(original)
		del(original)
	return


/datum/emergency_call/pmc/proc/spawn_standard(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/device/radio/headset/syndicate/PMC(M), slot_l_ear)
	M.equip_to_slot_or_del(new /obj/item/clothing/under/marine_jumpsuit/PMC(M), slot_w_uniform)
	M.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/marine/PMCarmor(M), slot_wear_suit)
	M.equip_to_slot_or_del(new /obj/item/clothing/gloves/black(M), slot_gloves)
	M.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/marine/PMC(M), slot_head)
	M.equip_to_slot_or_del(new /obj/item/weapon/melee/baton(M), slot_belt)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/marine, slot_shoes)
	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m39/PMC(M), slot_r_hand)
	M.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/PMCmask(M), slot_wear_mask)
	M.equip_to_slot_or_del(new /obj/item/weapon/tank/emergency_oxygen/engi(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/m39(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive/PMC(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/device/flashlight(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/m39(M), slot_l_store)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/m39(M), slot_r_store)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "PMC Standard"
	W.registered_name = M.real_name
	W.name = "[M.real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	W.access += get_all_centcom_access()
	M.equip_to_slot_or_del(W, slot_wear_id)

/datum/emergency_call/pmc/proc/spawn_officer(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/device/radio/headset/syndicate/PMC(M), slot_l_ear)
	M.equip_to_slot_or_del(new /obj/item/clothing/under/marine_jumpsuit/PMC/leader(M), slot_w_uniform)
	M.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/marine/PMCarmor/leader(M), slot_wear_suit)
	M.equip_to_slot_or_del(new /obj/item/clothing/gloves/black(M), slot_gloves)
	M.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/marine/PMC/leader(M), slot_head)
	M.equip_to_slot_or_del(new /obj/item/weapon/melee/baton(M), slot_belt)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(M), slot_shoes)
	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m39/PMC(M), slot_r_hand)
	M.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/PMCmask/leader(M), slot_wear_mask)
	M.equip_to_slot_or_del(new /obj/item/weapon/tank/emergency_oxygen/engi(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/device/flashlight(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/VP78 (M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/VP78(M.back), slot_in_backpack)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "Weyland PMC Officer"
	W.registered_name = M.real_name
	W.name = "[M.real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	W.access += get_all_centcom_access()
	M.equip_to_slot_or_del(W, slot_wear_id)

/datum/emergency_call/pmc/proc/spawn_heavy(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/device/radio/headset/syndicate/PMC(M), slot_l_ear)
	M.equip_to_slot_or_del(new /obj/item/clothing/glasses/m42_goggles	(M), slot_glasses)
	M.equip_to_slot_or_del(new /obj/item/clothing/under/marine_jumpsuit/PMC/commando(M), slot_w_uniform)
	M.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/marine/PMCarmor/commando(M), slot_wear_suit)
	M.equip_to_slot_or_del(new /obj/item/clothing/gloves/black(M), slot_gloves)
	M.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/marine/PMC/commando(M), slot_head)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/PMC(M), slot_shoes)
	M.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/PMCmask/leader(M), slot_wear_mask)
	M.equip_to_slot_or_del(new /obj/item/weapon/tank/emergency_oxygen/engi(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive/PMC(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/VP78(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/VP78 (M.back), slot_in_backpack)
	if(prob(50))
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/m39(M), slot_l_store)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/m39(M), slot_r_store)
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m39/PMC(M), slot_r_hand)
	else
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/m42c(M), slot_l_store)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/m42c(M), slot_r_store)
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/M42C(M), slot_r_hand)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "PMC Elite Commando"
	W.registered_name = M.real_name
	W.name = "[M.real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	W.access += get_all_centcom_access()
	M.equip_to_slot_or_del(W, slot_wear_id)

/datum/emergency_call/pmc/proc/spawn_xenoborg(var/mob/M) //Deferred for now. Just keep it in mind
	return

/datum/emergency_call/xenos/create_member(var/datum/mind/M)
	var/turf/spawn_loc = get_spawn_point()
	var/mob/original = M.current

	if(!istype(spawn_loc)) return //Didn't find a useable spawn point.
	var/chance = rand(0,2)
	var/mob/living/carbon/Xenomorph/new_xeno
	if(chance == 0)
		new_xeno = new /mob/living/carbon/Xenomorph/Hunter(spawn_loc)
	else if(chance == 1)
		new_xeno = new /mob/living/carbon/Xenomorph/Spitter(spawn_loc)
	else
		new_xeno = new /mob/living/carbon/Xenomorph/Drone(spawn_loc)

	new_xeno.jelly = 1

	M.transfer_to(new_xeno)

	if(original) //Just to be sure.
		del(original)

/datum/emergency_call/mercs/create_member(var/datum/mind/M)
	var/turf/spawn_loc = get_spawn_point()
	var/mob/original = M.current

	if(!istype(spawn_loc)) return //Didn't find a useable spawn point.

	var/mob/living/carbon/human/mob = new(spawn_loc)
	mob.gender = pick(MALE,FEMALE)
	var/datum/preferences/A = new()
	A.randomize_appearance_for(mob)
	if(mob.gender == MALE)
		mob.real_name = "[pick(first_names_male)] [pick(last_names)]"
	else
		mob.real_name = "[pick(first_names_female)] [pick(last_names)]"
	mob.name = mob.real_name
	mob.age = rand(17,45)
	mob.dna.ready_dna(mob)
	M.transfer_to(mob)
	mob.mind.assigned_role = "MODE"
	mob.mind.special_role = "Mercenary"
	ticker.mode.traitors += mob.mind
	spawn(0)
		if(!leader)       //First one spawned is always the leader.
			leader = mob
			spawn_captain(mob)
			mob << "<font size='3'>\red You are the Mercenary captain!</font>"
			mob << "<B> You must lead the mercs to victory against any and all hostile threats.</b>"
		else
			spawn_mercenary(mob)
			mob << "<font size='3'>\red You are a Space Mercenary!</font>"

	spawn(10)
		M << "<B>Objectives:</b> [objectives]"

	if(original)
		del(original)
	return

/datum/emergency_call/mercs/proc/spawn_captain(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/device/radio/headset/syndicate(M), slot_l_ear)
	M.equip_to_slot_or_del(new /obj/item/clothing/under/captain_fly(M), slot_w_uniform)
	M.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/bulletproof(M), slot_wear_suit)
	M.equip_to_slot_or_del(new /obj/item/clothing/gloves/black(M), slot_gloves)
	M.equip_to_slot_or_del(new /obj/item/clothing/head/caphat(M), slot_head)
	M.equip_to_slot_or_del(new /obj/item/weapon/melee/baton(M), slot_belt)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/weapon/tank/emergency_oxygen/engi(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/device/flashlight(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(M), slot_shoes)

	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/deagle(M), slot_r_hand)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a50(M), slot_l_store)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a50(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a50(M.back), slot_in_backpack)


	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "Captain"
	W.registered_name = M.real_name
	W.name = "[M.real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	M.equip_to_slot_or_del(W, slot_wear_id)

/datum/emergency_call/mercs/proc/spawn_mercenary(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/device/radio/headset/syndicate(M), slot_l_ear)
	if(prob(50))
		M.equip_to_slot_or_del(new /obj/item/clothing/under/chameleon(M), slot_w_uniform)
	else
		M.equip_to_slot_or_del(new /obj/item/clothing/under/syndicate(M), slot_w_uniform)
	if(prob(50))
		M.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/bulletproof(M), slot_wear_suit)
	else
		if(prob(50))
			M.equip_to_slot_or_del(new /obj/item/clothing/suit/bomber(M), slot_wear_suit)
		else
			M.equip_to_slot_or_del(new /obj/item/clothing/suit/armor(M), slot_wear_suit)
	if(prob(50))
		M.equip_to_slot_or_del(new /obj/item/clothing/gloves/black(M), slot_gloves)
	else
		M.equip_to_slot_or_del(new /obj/item/clothing/gloves/yellow(M), slot_gloves)
	if(prob(30))
		M.equip_to_slot_or_del(new /obj/item/clothing/head/welding(M), slot_head)
	else
		if(prob(30))
			M.equip_to_slot_or_del(new /obj/item/clothing/head/bowler(M), slot_head)
		else
			if(prob(30))
				M.equip_to_slot_or_del(new /obj/item/clothing/head/helmet(M), slot_head)
			else
				M.equip_to_slot_or_del(new /obj/item/clothing/head/hardhat(M), slot_head)

	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/weapon/tank/emergency_oxygen/engi(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/device/flashlight(M.back), slot_in_backpack)
	if(prob(75))
		M.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(M), slot_shoes)
	else
		M.equip_to_slot_or_del(new /obj/item/clothing/shoes/magboots(M), slot_shoes)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(M), slot_shoes)

	var/rand_gun = rand(0,5)
	if(rand_gun == 0)
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/combat(M), slot_r_hand)
		M.equip_to_slot_or_del(new /obj/item/ammo_casing/shotgun(M), slot_l_store)
		M.equip_to_slot_or_del(new /obj/item/ammo_casing/shotgun(M.back), slot_in_backpack)
	else if(rand_gun == 1)
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/launcher/crossbow(M), slot_r_hand)
		M.equip_to_slot_or_del(new /obj/item/weapon/arrow(M), slot_l_store)
		M.equip_to_slot_or_del(new /obj/item/weapon/arrow(M), slot_r_store)
		M.equip_to_slot_or_del(new /obj/item/weapon/arrow(M.back), slot_in_backpack)
	else if(rand_gun == 2)
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/mini_uzi(M), slot_r_hand)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/c45m(M), slot_l_store)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/c45m(M.back), slot_in_backpack)
	else if(rand_gun == 3)
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/c20r(M), slot_r_hand)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a12mm(M), slot_l_store)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a12mm(M.back), slot_in_backpack)
	else if(rand_gun == 4)
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/l6_saw(M), slot_r_hand)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a762(M), slot_l_store)
		M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a762(M.back), slot_in_backpack)
	else
		M.equip_to_slot_or_del(new /obj/item/weapon/gun/energy/laser(M), slot_r_hand)


/datum/emergency_call/bears/create_member(var/datum/mind/M)
	var/turf/spawn_loc = get_spawn_point()
	var/mob/original = M.current

	if(!istype(spawn_loc)) return //Didn't find a useable spawn point.

	var/mob/living/carbon/human/mob = new(spawn_loc)
	mob.gender = pick(MALE,FEMALE)
	var/datum/preferences/A = new()
	A.randomize_appearance_for(mob)
	var/list/first_names_mr = list("Grigory","Vladimir","Alexei","Andrei","Artyom","Viktor","Boris","Ivan","Igor","Oleg")
	var/list/first_names_fr = list("Alexandra","Anna","Anastasiya","Eva","Klara","Nikita","Olga","Svetlana","Tatyana","Yaroslava")
	var/list/last_names_r = list("Azarov","Bogdanov","Barsukov","Golovin","Davydov","Dragomirov","Yeltsin","Zhirov","Zhukov","Ivanov","Ivchenko","Kasputin","Lukyanenko","Melnikov")
	if(mob.gender == MALE)
		mob.real_name = "[pick(first_names_mr)] [pick(last_names_r)]"
	else
		mob.real_name = "[pick(first_names_fr)] [pick(last_names_r)]"
	mob.name = mob.real_name
	mob.age = rand(17,45)
	mob.dna.ready_dna(mob)
	M.transfer_to(mob)
	mob.mind.assigned_role = "MODE"
	mob.mind.special_role = "IRON BEARS"
	ticker.mode.traitors += mob.mind
	spawn(0)
		if(!leader)       //First one spawned is always the leader.
			leader = mob
			spawn_officer(mob)
			mob << "<font size='3'>\red You are the Iron Bears leader!</font>"
			mob << "<B> You must lead the Iron Bears mercenaries to victory against any and all hostile threats.</b>"
			mob << "<B> To Hell with Weyland Yutani and the USCM! The Iron Bears run the show now!</b>"
		else
			spawn_standard(mob)
			mob << "<font size='3'>\red You are an Iron Bear mercenary!</font>"

	spawn(10)
		M << "<B>Objectives:</b> [objectives]"

	if(original)
		del(original)
	return


/datum/emergency_call/bears/proc/spawn_standard(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/device/radio/headset/syndicate(M), slot_l_ear)
	M.equip_to_slot_or_del(new /obj/item/clothing/under/marine_jumpsuit/PMC/Bear(M), slot_w_uniform)
	M.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/marine/PMCarmor/Bear(M), slot_wear_suit)
	M.equip_to_slot_or_del(new /obj/item/clothing/gloves/black(M), slot_gloves)
	if(prob(75))
		M.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/marine/PMC/Bear(M), slot_head)
	else
		M.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt(M), slot_head)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/marine, slot_shoes)
	M.equip_to_slot_or_del(new /obj/item/weapon/tank/emergency_oxygen/engi(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/device/flashlight(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/plastique(M.back), slot_in_backpack)

	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/l6_saw(M), slot_r_hand)
	M.equip_to_slot_or_del(new /obj/item/weapon/plastique(M), slot_l_store)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/a762(M), slot_r_store)

	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/mc9mm(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol(M), slot_in_backpack)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "Iron Bear"
	W.registered_name = M.real_name
	W.name = "[M.real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	M.equip_to_slot_or_del(W, slot_wear_id)

/datum/emergency_call/bears/proc/spawn_officer(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/device/radio/headset/syndicate/PMC(M), slot_l_ear)
	M.equip_to_slot_or_del(new /obj/item/clothing/under/marine_jumpsuit/PMC/Bear(M), slot_w_uniform)
	M.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/marine/PMCarmor/Bear(M), slot_wear_suit)
	M.equip_to_slot_or_del(new /obj/item/clothing/gloves/black(M), slot_gloves)
	M.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/marine/PMC/Bear(M), slot_head)

	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(M), slot_shoes)

	M.equip_to_slot_or_del(new /obj/item/weapon/gun/energy/sniperrifle(M), slot_r_hand)
	M.equip_to_slot_or_del(new /obj/item/weapon/tank/emergency_oxygen/engi(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/device/flashlight(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/mc9mm(M), slot_l_store)
	M.equip_to_slot_or_del(new /obj/item/ammo_magazine/mc9mm(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol(M), slot_r_store)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "Iron Bears Sergeant"
	W.registered_name = M.real_name
	W.name = "[M.real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	W.access += get_all_centcom_access()
	M.equip_to_slot_or_del(W, slot_wear_id)

/datum/emergency_call/pizza/create_member(var/datum/mind/M)
	var/turf/spawn_loc = get_spawn_point()
	var/mob/original = M.current

	if(!istype(spawn_loc)) return //Didn't find a useable spawn point.

	var/mob/living/carbon/human/mob = new(spawn_loc)
	mob.gender = pick(MALE,FEMALE)
	var/datum/preferences/A = new()
	A.randomize_appearance_for(mob)
	if(mob.gender == MALE)
		mob.real_name = "[pick(first_names_male)] [pick(last_names)]"
	else
		mob.real_name = "[pick(first_names_female)] [pick(last_names)]"
	mob.name = mob.real_name
	mob.age = rand(17,45)
	mob.dna.ready_dna(mob)
	M.transfer_to(mob)
	mob.mind.assigned_role = "MODE"
	mob.mind.special_role = "Pizza"
	ticker.mode.traitors += mob.mind
	spawn(0)
		spawn_pizza(mob)
		mob << "<font size='3'>\red You are a pizza deliverer!</font>"
		mob << "Your job is to deliver your pizzas. You're PRETTY sure this is the right place.."
	spawn(10)
		M << "<B>Objectives:</b> [objectives]"

	if(original)
		del(original)
	return

/datum/emergency_call/pizza/proc/spawn_pizza(var/mob/M)
	if(!M || !istype(M)) return

	M.equip_to_slot_or_del(new /obj/item/clothing/under/pizza(M), slot_w_uniform)
	M.equip_to_slot_or_del(new /obj/item/clothing/head/soft/red(M), slot_head)
	M.equip_to_slot_or_del(new /obj/item/clothing/shoes/red(M), slot_shoes)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(M), slot_back)
	M.equip_to_slot_or_del(new /obj/item/pizzabox/margherita(M), slot_r_hand)
	M.equip_to_slot_or_del(new /obj/item/pizzabox/margherita(M), slot_r_hand)
	M.equip_to_slot_or_del(new /obj/item/device/radio(M), slot_r_store)

	M.equip_to_slot_or_del(new /obj/item/device/flashlight(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/pizzabox/vegetable(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/pizzabox/mushroom(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/pizzabox/meat(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/box/pizza(M.back), slot_in_backpack)
	M.equip_to_slot_or_del(new /obj/item/weapon/storage/box/pizza(M.back), slot_in_backpack)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "Pizzahaus Deliverer ([rand(1,1000)])"
	W.registered_name = M.real_name
	W.name = "[M.real_name]'s ID Card ([W.assignment])"
	W.icon_state = "centcom"
	W.access = get_all_accesses()
	W.access += get_all_centcom_access()
	M.equip_to_slot_or_del(W, slot_wear_id)

/obj/item/clothing/under/pizza
	name = "pizza delivery uniform"
	desc = "An ill-fitting, slightly stained uniform for a pizza delivery pilot. Smells of cheese."
	icon_state = "redshirt2"
	item_state = "r_suit"
	item_color = "redshirt2"

/obj/item/weapon/storage/box/pizza
	name = "Food Delivery Box"
	desc = "A space-age food storage device, capable of keeping food extra fresh. Actually, it's just a box."

	New()
		..()
		pixel_y = rand(-3,3)
		pixel_x = rand(-3,3)
		new /obj/item/weapon/reagent_containers/food/snacks/donkpocket(src)
		new /obj/item/weapon/reagent_containers/food/snacks/donkpocket(src)
		var/randsnack
		for(var/i = 1 to 3)
			randsnack = rand(0,5)
			switch(randsnack)
				if(0)
					new /obj/item/weapon/reagent_containers/food/snacks/fries(src)
				if(1)
					new /obj/item/weapon/reagent_containers/food/snacks/cheesyfries(src)
				if(2)
					new /obj/item/weapon/reagent_containers/food/snacks/bigbiteburger(src)
				if(4)
					new /obj/item/weapon/reagent_containers/food/snacks/taco(src)
				if(5)
					new /obj/item/weapon/reagent_containers/food/snacks/hotdog(src)

/client/verb/JoinResponseTeam()
	set name = "Join Response Team"
	set category = "IC"
	set desc = "Join an ongoing distress call response. You must be ghosted to do this."

	if(istype(usr,/mob/dead/observer) || istype(usr,/mob/new_player))
		if(jobban_isbanned(usr, "Syndicate") || jobban_isbanned(usr, "Military Police"))
			usr << "<font color=red><b>You are jobbanned from the emergency reponse team!"
			return
		if(!ticker || !ticker.mode || isnull(ticker.mode.picked_call))
			usr << "No distress beacons are active. You will be notified if this changes."
			return

		var/datum/emergency_call/distress = ticker.mode.picked_call //Just to simplify things a bit
		if(distress.members.len >= distress.mob_max)
			usr << "The emergency response team is already full!"
			return
		if(!distress.waiting_for_candidates)
			usr << "The distress beacon is already active. Better luck next time!"
			return

		if(!usr.client || !usr.mind) return //Somehow
		if(usr.mind in distress.candidates)
			usr << "You already joined, just be patient."
			return

		distress.candidates += usr.mind
		usr << "<B>You are enlisted in the emergency response team! If the team is full after 60 seconds you will be transferred in.</b>"
		return
	else
		usr << "You need to be an observer or new player to use this."
	return

/client/proc/admin_force_distress()
	set category = "Admin"
	set name = "Force Distress Call"

	if (!ticker  || !ticker.mode)
		return

	if(!check_rights(R_MOD))	return

	if(ticker.mode.picked_call)
		var/confirm = alert(src, "There's already been a distress call sent. Are you sure you want to send another one?", "Send a distress call?", "Yes", "No")
		if(confirm != "Yes") return

		//Reset the distress call
		ticker.mode.picked_call.members = list()
		ticker.mode.picked_call.candidates = list()
		ticker.mode.picked_call.waiting_for_candidates = 0
		ticker.mode.has_called_emergency = 0
		ticker.mode.picked_call = null

	var/list/list_of_calls = list()
	for(var/datum/emergency_call/L in ticker.mode.all_calls)
		if(L && L.name != "name")
			list_of_calls += L.name

	list_of_calls += "Randomize"
	list_of_calls += "Cancel"

	var/choice = input("Which distress call?") as null|anything in list_of_calls
	if(choice == "Cancel" || isnull(choice) || choice == "")
		return

	if(choice == "Randomize")
		ticker.mode.picked_call	= ticker.mode.get_random_call()
	else
		for(var/datum/emergency_call/C in ticker.mode.all_calls)
			if(C && C.name == choice)
				ticker.mode.picked_call = C
				break

	if(!istype(ticker.mode.picked_call))
		return

	ticker.mode.picked_call.activate()
	ticker.mode.has_called_emergency = 1

	feedback_add_details("admin_verb","DISTR") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!
	log_admin("[key_name(usr)] admin-called a distress beacon: [ticker.mode.picked_call.name]")
	message_admins("\blue [key_name_admin(usr)] admin-called a distress beacon: [ticker.mode.picked_call.name]", 1)
	return
