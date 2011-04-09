/**
* vim: set ai et ts=4 sw=4 :
* File: War3Source_SuccubusHunter.sp
* Description: The Succubus Hunter race for SourceCraft.
* Author(s): DisturbeD 
* Adapted to TF2 by: -=|JFH|=-Naris (Murray Wilson)
* Offcially ported to War3Source by Ownz
*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools_tempents>
#include <sdktools_functions>
#include <sdktools_tempents_stocks>
#include <sdktools_entinput>
#include <sdktools_sound>

#include "W3SIncs/War3Source_Interface"

new thisRaceID, SKILL_HEADHUNTER, SKILL_TOTEM, SKILL_ASSAULT, ULT_TRANSFORM;
new m_iAccount = -1, m_vecVelocity_0, m_vecVelocity_1, m_vecBaseVelocity; //offsets


new bool:hurt_flag = true;
new bool:m_IsULT_TRANSFORMformed[MAXPLAYERS+1];
new skulls[MAXPLAYERS+1];
new g_GameType;
//Effects
new BeamSprite;
new Laser;

new assaultskip[MAXPLAYERS+1];
new Handle:ultCooldownCvar;
public Plugin:myinfo = 
{
	name = "Succubus Hunter",
	author = "DisturbeD",
	description = "",
	version = "2.0.6",
	url = "http://war3source.com/"
};

public OnMapStart()
{
	PrecacheSound("npc/fast_zombie/claw_strike1.wav");
	PrecacheModel("models/gibs/hgibs.mdl", true);
	BeamSprite=PrecacheModel("materials/sprites/purpleglow1.vmt");
	Laser=PrecacheModel("materials/sprites/laserbeam.vmt");
}

public OnWar3PluginReady()
{
	thisRaceID=War3_CreateNewRace("Succubus Hunter", "succubus");
	
	SKILL_HEADHUNTER = War3_AddRaceSkill(thisRaceID, "Head Hunter","Chance to do extra damage porortioal\nto the number of skulls you have.\nYou gain your victim's SKULLs on\nheadshots / skill proc / criticals.\nYou lose a skull on death.", false);
	
	SKILL_TOTEM = War3_AddRaceSkill(thisRaceID, "Totem Incantation", "You gain 1-2% HP, 25-50$ or credits and 1-5XP on spawn for each skull you collected.", false);
	
	SKILL_ASSAULT = War3_AddRaceSkill(thisRaceID, "Assault Tackle", "Makes you jump farther.\nOnly your first and every other jump will be boosted.\nIf your last jump was 2 seconds ago your\nnext jump will be boosted.", false);
	
	ULT_TRANSFORM = War3_AddRaceSkill(thisRaceID, "Deamonic Transformation","Get less gravity, more speed, and more HP. Costs 1/2/3/4 SKULLs.", true);
	
	War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
	m_vecVelocity_0 = FindSendPropOffs("CBasePlayer","m_vecVelocity[0]");
	
	HookEvent("player_hurt",PlayerHurtEvent);
	HookEvent("player_death",PlayerDeathEvent);
	
	g_GameType = War3_GetGame();
	switch (g_GameType)
	{
		case Game_CS:
		{
			HookEvent("player_jump",PlayerJumpEvent);
			m_iAccount = FindSendPropOffs("CCSPlayer", "m_iAccount");
			m_vecVelocity_1 = FindSendPropOffs("CBasePlayer","m_vecVelocity[1]");
			m_vecBaseVelocity = FindSendPropOffs("CBasePlayer","m_vecBaseVelocity");
		}
		case Game_TF:
		{
		}
	}
	
	AddCommandListener(SayCommand, "say");
	AddCommandListener(SayCommand, "say_team");
	
	ultCooldownCvar=CreateConVar("war3_succ_ult_cooldown","20","Cooldown for succubus ultimate");
}

public OnWar3EventSpawn(client)
{
	new race=War3_GetRace(client); 
	if (race==thisRaceID) 
	{
		m_IsULT_TRANSFORMformed[client]=false;
		War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0);
		War3_SetBuff(client,fLowGravitySkill,thisRaceID,1.0);	
	
	
		new skillleveltotem=War3_GetSkillLevel(client,race,SKILL_TOTEM); 
		if (skillleveltotem )
		{
			new maxhp = War3_GetMaxHP(client);
			new hp, dollar, xp; 
			switch(skillleveltotem)
			{
				case 1: 
				{
					hp=RoundToNearest(float(maxhp) * 0.01);
					dollar=25;
					xp=1;
				}
				case 2: 
				{
					hp=RoundToNearest(float(maxhp) * 0.01);
					dollar=30;
					xp=2;
				}
				case 3: 
				{
					hp=RoundToNearest(float(maxhp) * 0.02);
					dollar=35;
					xp=3;
				}
				case 4:
				{
					hp=RoundToNearest(float(maxhp) * 0.02);
					dollar=50;
					xp=5;
				}
			}
			
			hp *= skulls[client];
			dollar *= skulls[client];
			xp *= skulls[client];
			
			new old_health=GetClientHealth(client);
			SetEntityHealth(client,old_health+hp);
			
			new old_XP = War3_GetXP(client,thisRaceID);
			new kill_XP = War3_GetKillXP(client,thisRaceID);
			if (xp > kill_XP)
				xp = kill_XP;
			
			War3_SetXP(client,thisRaceID,old_XP+xp);
			
			if (m_iAccount>0) //game with money
			{
				new old_cash=GetEntData(client, m_iAccount);
				SetEntData(client, m_iAccount, old_cash + dollar);
			}
			else
			{
				new max=100;
				
				new old_credits=War3_GetCredits(client);
				
				dollar /= max;
				new new_credits = old_credits + dollar;
				if (new_credits > max)
					new_credits = max;
				
				
				War3_SetCredits(client,new_credits);
				new_credits = War3_GetCredits(client);
				
				if (new_credits > 0){
					dollar = new_credits-old_credits;
				}
			}
			PrintToChat(client,"\x04[Totem Incanation]:\x01You gained %d HP, %d %s and %d XP.",hp,dollar,m_iAccount>0?"dollars":"credits",xp);
		}
	}
}

public PlayerHurtEvent(Handle:event,const String:name[],bool:dontBroadcast)
{
	if (hurt_flag == false)
	{
		hurt_flag=true; //for skipping your own damage?
		return;
	}
	
	new victim = GetClientOfUserId(GetEventInt(event,"userid"));
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	if (victim && attacker && victim!=attacker) // &&hurt_flag==true)
	{
		new race=War3_GetRace(attacker);
		if (race==thisRaceID)
		{
			new dmgamount;
			switch (g_GameType)
			{
				case Game_CS: dmgamount = GetEventInt(event,"dmg_health");
				case Game_TF: dmgamount = GetEventInt(event,"damageamount");
				case Game_DOD: dmgamount = GetEventInt(event,"damage");
			}
			
			new totaldamage = dmgamount;
			
			// Head Hunter
			new skilllevelheadhunter = War3_GetSkillLevel(attacker,race,SKILL_HEADHUNTER);
			if (skilllevelheadhunter > 0 && dmgamount > 0 && !War3_GetImmunity(victim,Immunity_Skills))
			{
				decl String: weapon[MAX_NAME_LENGTH+1];
				new bool:is_equipment=GetWeapon(event,attacker,weapon,sizeof(weapon));
				new bool:is_melee=IsMelee(weapon, is_equipment, attacker, victim);
				
				new damage;
				if (is_melee)
				{
					new Float:percent;
					switch(skilllevelheadhunter)
					{
						case 1:
						percent=0.50;
						case 2:
						percent=0.75;
						case 3:
						percent=0.90;
						case 4:
						percent=1.00;
					}
					damage= RoundFloat(float(dmgamount) * percent);
					totaldamage += damage;
					
					new Float:vec[3];
					GetClientAbsOrigin(attacker,vec);
					vec[2]+=50.0;
					TE_SetupGlowSprite(vec, BeamSprite, 2.0, 10.0, 5);
					TE_SendToAll();
					
					PrintToConsole(attacker,"\x04[Daemonic Knife] You inflicted +%d Damage",damage);
				}
				else
				{
					new percent;
					switch (skilllevelheadhunter)
					{
						case 1:
						percent=10;
						case 2:
						percent=15;
						case 3:
						percent=20;
						case 4:
						percent=30;
					}
					if(GetRandomInt(1,100)<=percent)
					{
						damage= RoundFloat(dmgamount * GetRandomFloat(0.20,0.40)); // 1.20-1.00,1.40-1.00
						totaldamage += damage;
						PrintToChat(attacker,"[Head Hunter] You inflicted +%d Damage",damage);
					}
				}
				
				if (damage>0)
				{
					new health=GetEventInt(event, "health");
					if (health>damage)
						SetEntityHealth(victim,health-damage); //reduce health
					
					//u killed them
					else {
						if (skulls[attacker]<(5*skilllevelheadhunter)){
							skulls[attacker]++;
							War3_ChatMessage(attacker,"You gained a SKULL (%d/%d).",skulls[attacker],(5*skilllevelheadhunter));
						}
						
						EmitSoundToClient(attacker,"npc/fast_zombie/claw_strike1.wav");
						decl Float:Origin[3], Float:Direction[3];
						GetClientAbsOrigin(victim, Origin);
						Direction[0] = GetRandomFloat(-1.0, 1.0);
						Direction[1] = GetRandomFloat(-1.0, 1.0);
						Direction[2] = 500.0;
						Gib(Origin, Direction, "models/gibs/hgibs.mdl");
						
						hurt_flag = false;
						War3_DealDamage(victim,damage,attacker,_,"headhunter");
					}
				}
			}
		}
	}
}

public PlayerDeathEvent(Handle:event,const String:name[],bool:dontBroadcast)
{
	#define DF_FEIGNDEATH   32
	#define DMG_CRITS       1048576    //crits = DAMAGE_ACID
	
	static const String:tf2_decap_weapons[][] = { "sword",   "club",      "axtinguisher",
	"fireaxe", "battleaxe", "tribalkukri"};
	
	new victim = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if (victim > 0)
	{
		if (War3_GetRace(victim) == thisRaceID){
			if(skulls[victim]>0){
				skulls[victim]--;
				PrintToConsole(victim,"You lost your own skull");
			}
		}

		new client = GetClientOfUserId(GetEventInt(event,"attacker"));
		if (client > 0 && client != victim)
		{
			if (War3_GetRace(client) == thisRaceID)
			{
				new bool:headshot;
				switch (g_GameType)
				{
					case Game_CS:
					{
						headshot = GetEventBool(event, "headshot");
					}
					case Game_TF:
					{
						// Don't count dead ringer fake deaths
						if ((GetEventInt(event, "death_flags") & DF_FEIGNDEATH) == 0)
						{
							// Check for headshot or backstab
							new customkill = GetEventInt(event, "customkill");
							headshot = (customkill == 1 || customkill == 2);
						}
					}
					case Game_DOD:
					{
						headshot = false;
					}
				}
				
				// Head Hunter
				new skilllevelheadhunter=War3_GetSkillLevel(client,thisRaceID,SKILL_HEADHUNTER);
				if (skilllevelheadhunter)
				{
					new bool:decap = false;
					if (g_GameType == Game_TF)
					{
						decl String:weapon[128];
						GetEventString(event, "weapon", weapon, sizeof(weapon));
						
						for (new i = 0; i < sizeof(tf2_decap_weapons); i++)
						{
							if (StrEqual(weapon,tf2_decap_weapons[i],false))
							{
								decap = ((GetEventInt(event, "damagebits") & DMG_CRITS) != 0);
								break;
							}
						}
					}
					else
					decap = false;
					
					if (headshot || decap )
					{
						if (skulls[client]<(5*skilllevelheadhunter))
						{
							skulls[client]++;
							War3_ChatMessage(client,"You gained a SKULL [%d/%d].",skulls[client],(5*skilllevelheadhunter));
						}							
						decl Float:Origin[3], Float:Direction[3];
						GetClientAbsOrigin(victim, Origin);
						Direction[0] = GetRandomFloat(-1.0, 1.0);
						Direction[1] = GetRandomFloat(-1.0, 1.0);
						Direction[2] = 500.0;
						Gib(Origin, Direction, "models/gibs/hgibs.mdl");
					}
				}
			}
		}
	}
}

public PlayerJumpEvent(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event,"userid"));
	new race=War3_GetRace(client);
	if (race==thisRaceID)
	{
		
		new skill_SKILL_ASSAULT=War3_GetSkillLevel(client,race,SKILL_ASSAULT);
		
		if (skill_SKILL_ASSAULT){
			assaultskip[client]--;
			if(assaultskip[client]<1||War3_SkillNotInCooldown(client,thisRaceID,SKILL_ASSAULT))
			{
				assaultskip[client]+=2;
				new Float:velocity[3]={0.0,0.0,0.0};
				velocity[0]= GetEntDataFloat(client,m_vecVelocity_0);
				velocity[1]= GetEntDataFloat(client,m_vecVelocity_1);
				velocity[0]*=float(skill_SKILL_ASSAULT)*0.25;
				velocity[1]*=float(skill_SKILL_ASSAULT)*0.25;
				
				//new Float:len=GetVectorLength(velocity,false);
				//if(len>100.0){
				//	velocity[0]*=100.0/len;
				//	velocity[1]*=100.0/len;
				//}
				//PrintToChatAll("speed vector length %f cd %d",len,War3_SkillNotInCooldown(client,thisRaceID,SKILL_ASSAULT)?0:1);
				/*len=GetVectorLength(velocity,false);
				PrintToChatAll("speed vector length %f",len);
				*/
				
				SetEntDataVector(client,m_vecBaseVelocity,velocity,true);
				War3_CooldownMGR(client,2.0,thisRaceID,SKILL_ASSAULT,_,_,false);
				
				new String:wpnstr[32];
				GetClientWeapon(client, wpnstr, 32);
				for(new slot=0;slot<10;slot++){
					
					new wpn=GetPlayerWeaponSlot(client, slot);
					if(wpn>0){
						//PrintToChatAll("wpn %d",wpn);
						new String:comparestr[32];
						GetEdictClassname(wpn, comparestr, 32);
						//PrintToChatAll("%s %s",wpn, comparestr);
						if(StrEqual(wpnstr,comparestr,false)){
							
							TE_SetupKillPlayerAttachments(wpn);
							TE_SendToAll();
							
							new color[4]={0,25,255,200};
							if(GetClientTeam(client)==TEAM_T||GetClientTeam(client)==TEAM_RED){
								color[0]=255;
								color[2]=0;
							}
							TE_SetupBeamFollow(wpn,Laser,0,0.5,2.0,7.0,1,color);
							TE_SendToAll();
							break;
						}
					}
				}
			}
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_GameType != Game_CS && (buttons & IN_JUMP)) //assault for non CS games
	{
		if (War3_GetRace(client) == thisRaceID)
		{
			new skill_SKILL_ASSAULT=War3_GetSkillLevel(client,thisRaceID,SKILL_ASSAULT);
			if (skill_SKILL_ASSAULT)
			{
				decl Float:velocity[3];
				GetEntDataVector(client, m_vecVelocity_0, velocity);
				
				if (!(GetEntityFlags(client) & FL_ONGROUND))
				{
					new Float:absvel = velocity[0];
					if (absvel < 0.0)
						absvel *= -1.0;
					
					if (velocity[1] < 0.0)
						absvel -= velocity[1];
					else
						absvel += velocity[1];
					
					new Float:maxvel = m_IsULT_TRANSFORMformed[client] ? 1000.0 : 500.0;
					if (absvel > maxvel)
						return Plugin_Continue;
				}
				
				if (TF2_HasTheFlag(client))
					return Plugin_Continue;
				
				new Float:amt = 1.0 + (float(skill_SKILL_ASSAULT)*0.20);
				velocity[0]*=amt;
				velocity[1]*=amt;
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
				
				//new color[4] = {255,127,0,255};
				new color[4] = {255,25,0,255};
				if (m_IsULT_TRANSFORMformed[client])
					color[2] = 255;
				
				TE_SetupKillPlayerAttachments(client);
				TE_SendToAll();
				
				if (!War3_IsCloaked(client))
				{
					TE_SetupBeamFollow(client,Laser,0,0.5,2.0,7.0,1,color);
					TE_SendToAll();
				}
			}
		}
	}
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	skulls[client] = 0;
	m_IsULT_TRANSFORMformed[client]=false;
	
	War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0);
	War3_SetBuff(client,fLowGravitySkill,thisRaceID,1.0);	
}


public OnUltimateCommand(client,race,bool:pressed)
{
	if(pressed && race==thisRaceID)
	{
		new skill_trans=War3_GetSkillLevel(client,race,ULT_TRANSFORM);
		if (skill_trans>0)
		{
			if (War3_SkillNotInCooldown(client,thisRaceID,ULT_TRANSFORM)){
			
				if (skulls[client] < skill_trans)
				{
					new required = skill_trans - skulls[client];
					PrintToChat(client,"\x04[Daemonic transformation] \x01You don't have enough skulls: %d more required.", required);
				}
				else
				{
					skulls[client]-=skill_trans;
					
					m_IsULT_TRANSFORMformed[client]=true;
					
					
					War3_SetBuff(client,fMaxSpeed,thisRaceID,float(skill_trans)/5.00+1.00);
					War3_SetBuff(client,fLowGravitySkill,thisRaceID,1.00-float(skill_trans)/5.00);
					
					new old_health=GetClientHealth(client);
					SetEntityHealth(client,old_health+skill_trans*10);
					
					PrintToChat(client,"\x04[Daemonic transformation] \x01Your daemonic powers boost your strength.");
					CreateTimer(10.0,Finishtrans,client);
					War3_CooldownMGR(client,GetConVarFloat(ultCooldownCvar),thisRaceID,ULT_TRANSFORM,_,_,_,"Daemonic transformation");
				}
			}
		}
	}
}

public Action:Finishtrans(Handle:timer,any:client)
{
	
	m_IsULT_TRANSFORMformed[client]=false;
	War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0);
	War3_SetBuff(client,fLowGravitySkill,thisRaceID,1.0);	
	if(War3_ValidPlayer(client,true)){
		
		PrintToChat(client,"\x04[Daemonic transformation] \x01You transformed back to normal.");
		if(GetClientHealth(client)>War3_GetMaxHP(client)){
			SetEntityHealth(client,War3_GetMaxHP(client));
		}
	}
}












































































stock Gib(Float:Origin[3], Float:Direction[3], String:Model[])
{
	if (!IsEntLimitReached(.message="unable to create gibs"))
	{
		new Ent = CreateEntityByName("prop_physics");
		DispatchKeyValue(Ent, "model", Model);
		SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 1); 
		DispatchSpawn(Ent);
		TeleportEntity(Ent, Origin, Direction, Direction);
		CreateTimer(GetRandomFloat(15.0, 30.0), RemoveGib,EntIndexToEntRef(Ent));
	}
}

public Action:RemoveGib(Handle:Timer, any:Ref)
{
	new Ent = EntRefToEntIndex(Ref);
	if (Ent > 0 && IsValidEdict(Ent))
	{
		RemoveEdict(Ent);
	}
}

stock TE_SetupKillPlayerAttachments(client)
{
	TE_Start("KillPlayerAttachments");
	TE_WriteNum("m_nPlayer",client);
}

/**
* Detect when changing classes in TF2
*/

public OnWar3PlayerAuthed(client)
{
	m_IsULT_TRANSFORMformed[client]=false;
	skulls[client] = 0;
}


public Action:SayCommand(client, const String:command[], argc)
{
	if (client > 0 && IsClientInGame(client))
	{
		decl String:text[128];
		GetCmdArg(1,text,sizeof(text));
		
		decl String:arg[2][64];
		ExplodeString(text, " ", arg, 2, 64);
		
		new String:firstChar[] = " ";
		firstChar{0} = arg[0]{0};
		if (StrContains("!/\\",firstChar) >= 0)
			strcopy(arg[0], sizeof(arg[]), arg[0]{1});
		
		if (StrEqual(arg[0],"skulls"))
		{
			new skilllevelheadhunter = (War3_GetRace(client)==thisRaceID) ? War3_GetSkillLevel(client,thisRaceID,SKILL_HEADHUNTER) : 0;
			if (skilllevelheadhunter)
				War3_ChatMessage(client,"You have (%d/%d) \x04SKULL\x01s.",skulls[client],(5*skilllevelheadhunter));
			else
			War3_ChatMessage(client,"You have %d \x04SKULL\x01s.",skulls[client]);
			
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

/**
* Weapons related functions.
*/
#tryinclude <sc/weapons>
#if !defined _weapons_included
stock bool:GetWeapon(Handle:event, index,
String:buffer[], buffersize)
{
	new bool:is_equipment;
	
	buffer[0] = 0;
	GetEventString(event, "weapon", buffer, buffersize);
	
	if (buffer[0] == '\0' && index && IsPlayerAlive(index))
	{
		is_equipment = true;
		GetClientWeapon(index, buffer, buffersize);
	}
	else
	is_equipment = false;
	
	return is_equipment;
}

stock bool:IsEquipmentMelee(const String:weapon[])
{
	switch (g_GameType)
	{
		case Game_CS:
		{
			return StrEqual(weapon,"weapon_knife");
		}
		case Game_DOD:
		{
			return (StrEqual(weapon,"weapon_amerknife") ||
			StrEqual(weapon,"weapon_spade"));
		}
		case Game_TF:
		{
			return (StrEqual(weapon,"tf_weapon_knife") ||
			StrEqual(weapon,"tf_weapon_shovel") ||
			StrEqual(weapon,"tf_weapon_wrench") ||
			StrEqual(weapon,"tf_weapon_bat") ||
			StrEqual(weapon,"tf_weapon_bat_wood") ||
			StrEqual(weapon,"tf_weapon_bonesaw") ||
			StrEqual(weapon,"tf_weapon_bottle") ||
			StrEqual(weapon,"tf_weapon_club") ||
			StrEqual(weapon,"tf_weapon_fireaxe") ||
			StrEqual(weapon,"tf_weapon_fists") ||
			StrEqual(weapon,"tf_weapon_sword"));
		}
	}
	return false;
}

stock bool:IsDamageFromMelee(const String:weapon[])
{
	switch (g_GameType)
	{
		case Game_CS:
		{
			return StrEqual(weapon,"weapon_knife");
		}
		case Game_DOD:
		{
			return (StrEqual(weapon,"amerknife") ||
			StrEqual(weapon,"spade") ||
			StrEqual(weapon,"punch"));
		}
		case Game_TF:
		{
			return (StrEqual(weapon,"knife") ||
			StrEqual(weapon,"shovel") ||
			StrEqual(weapon,"wrench") ||
			StrEqual(weapon,"bat") ||
			StrEqual(weapon,"bonesaw") ||
			StrEqual(weapon,"bottle") ||
			StrEqual(weapon,"club") ||
			StrEqual(weapon,"fireaxe") ||
			StrEqual(weapon,"axtinguisher") ||
			StrEqual(weapon,"fists") ||
			StrEqual(weapon,"sandman") ||
			StrEqual(weapon,"pickaxe") ||
			StrEqual(weapon,"sword") ||
			StrEqual(weapon,"demoshield") ||
			StrEqual(weapon,"taunt_scout") ||
			StrEqual(weapon,"taunt_sniper") ||
			StrEqual(weapon,"taunt_pyro") ||
			StrEqual(weapon,"taunt_demoman") ||
			StrEqual(weapon,"taunt_heavy") ||
			StrEqual(weapon,"taunt_spy") ||
			StrEqual(weapon,"taunt_soldier"));
		}
	}
	return false;
}

stock bool:IsMelee(const String:weapon[], bool:is_equipment, index, victim, Float:range=100.0)
{
	if (is_equipment)
	{
		if (IsEquipmentMelee(weapon))
			return IsInRange(index,victim,range);
		else
		return false;
	}
	else
	return IsDamageFromMelee(weapon);
}
#endif

/**
* Range and Distance functions and variables
*/
#tryinclude <range>
#if !defined _range_included
stock Float:TargetRange(client,index)
{
	new Float:start[3];
	new Float:end[3];
	GetClientAbsOrigin(client,start);
	GetClientAbsOrigin(index,end);
	return GetVectorDistance(start,end);
}

stock bool:IsInRange(client,index,Float:maxdistance)
{
	return (TargetRange(client,index)<maxdistance);
}
#endif

/**
* Determine if client has the flag
*/
#tryinclude <tf2_flag>
#if !defined _tf2_flag_included
stock bool:TF2_HasTheFlag(client)
{
	if (g_GameType == Game_TF)
	{
		new ent = -1;
		while ((ent = FindEntityByClassname(ent, "item_teamflag")) != -1)
		{
			if (GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity")==client)
				return true;
		}
	}
	return false;
}
#endif

/**
* Description: Function to check the entity limit.
*              Use before spawning an entity.
*/
#tryinclude <entlimit>
#if !defined _entlimit_included
stock IsEntLimitReached(warn=20,critical=16,client=0,const String:message[]="")
{
	new max = GetMaxEntities();
	new count = GetEntityCount();
	new remaining = max - count;
	if (remaining <= warn)
	{
		if (count <= critical)
		{
			PrintToServer("Warning: Entity limit is nearly reached! Please switch or reload the map!");
			LogError("Entity limit is nearly reached: %d/%d (%d):%s", count, max, remaining, message);
			
			if (client > 0)
			{
				PrintToConsole(client, "Entity limit is nearly reached: %d/%d (%d):%s",
				count, max, remaining, message);
			}
		}
		else
		{
			PrintToServer("Caution: Entity count is getting high!");
			LogMessage("Entity count is getting high: %d/%d (%d):%s", count, max, remaining, message);
			
			if (client > 0)
			{
				PrintToConsole(client, "Entity count is getting high: %d/%d (%d):%s",
				count, max, remaining, message);
			}
		}
		return count;
	}
	else
	return 0;
}
#endif
