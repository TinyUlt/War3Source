/* ============================================================================ */
/*										                                        */
/*   naix.sp									                                */
/*   (c) 2009 Stinkyfax								                            */
/*										                                        */
/*										                                        */
/* ============================================================================	*/


#include <sourcemod>
#include <sdktools_functions>	//For teleport
#include <sdktools_sound>		//For sound effect
#include "W3SIncs/War3Source_Interface"


// Colors
#define COLOR_DEFAULT 0x01
#define COLOR_LIGHTGREEN 0x03
#define COLOR_GREEN 0x04 // DOD = Red //kinda already defiend in war3 interface

//Skills Settings
 
new Float:HPPercentHealPerKill[5] = { 0.0,0.2,  0.3,  0.35,  0.40 }; //SKILL_INFEST settings
//Skill 1_1 really has 5 settings, so it's not a mistake
new HPIncrease[5]       = { 30, 50, 70, 85, 100 };     //Increases Maximum health

new Float:feastPercent[5] = { 0.0, 0.04,  0.06,  0.08,  0.10 };   //Feast ratio (leech based on current victim hp


new Float:RageAttackSpeed[5] = {1.0, 1.15,  1.25,  1.3334,  1.4001 };   //Rage Attack Rate
new Float:RageDuration[5] = {0.0, 3.0,  4.0,   5.0,  6.0 };   //Rage duration

//End of skill Settings

new Handle:ultCooldownCvar;

new thisRaceID, SKILL_INFEST, SKILL_BLOODBATH, SKILL_FEAST, ULT_RAGE;

public Plugin:myinfo = 
{
	name = "War3Source Race - Lifestealer",
	author = "Stinkyfax and Ownz",
	description = "N'aix - the embodiment of lust and greed,\nbent on stealing the life of every living creature he encounters.",
	version = "1.0",
	url = "war3source.com"//http://sugardas.lt/~jozh/
};



public OnPluginStart()
{
	ultCooldownCvar=CreateConVar("war3_naix_ult_cooldown","20","Cooldown time for Rage.");
}
public OnWar3LoadRaceOrItemOrdered(num)
{
	if(num==120)
	{
		thisRaceID=War3_CreateNewRace("Naix - Lifestealer", "naix");


		SKILL_INFEST = War3_AddRaceSkill(thisRaceID, "Infest", "The Lifestealer tears its way into the unfortunate body of a target unit,\nconsumes it and come to out killing the target.\nRegains health from the infested unit.", false);
		SKILL_BLOODBATH = War3_AddRaceSkill(thisRaceID, "Blood Bath", "Increases maximum health of the Naix,\nmaking all his other skills worthy.", false);
		SKILL_FEAST = War3_AddRaceSkill(thisRaceID, "Feast", "Regenerates a portion of enemys current HP.", false);
		ULT_RAGE = War3_AddRaceSkill(thisRaceID, "Rage", "Naix goes into a maddened Rage, gaining increased attack speed.", true);
		
		War3_CreateRaceEnd(thisRaceID);
	}
}

stock bool:IsOurRace(client) {
  return War3_GetRace(client)==thisRaceID;
}


public OnMapStart() { //some precaches
  PrecacheSound("npc/zombie/zombie_pain2.wav");
}

public OnWar3EventPostHurt(victim,attacker,amount){
	if(War3_ValidPlayer(victim)&&War3_ValidPlayer(attacker)&&IsOurRace(attacker)){
		new level = War3_GetSkillLevel(attacker, thisRaceID, SKILL_FEAST);
		if(level>0){
			if(!War3_GetImmunity(victim,Immunity_Skills)){	
				new targetHp = GetClientHealth(victim)+amount;
				new restore = RoundToNearest( float(targetHp) * feastPercent[level] );
				War3_HealToMaxHP(attacker,restore);
			}
		}
	}
}
public OnWar3EventSpawn(client){
	if(IsOurRace(client)){
		new level = War3_GetSkillLevel(client, thisRaceID, SKILL_BLOODBATH);
		if(level>=0){ //zeroth level passive
			War3_SetMaxHP(client, War3_GetMaxHP(client) + HPIncrease[level]);
			War3_ChatMessage(client, "Your Maximum Increased by %d",HPIncrease[level]);    
		}
	}
}
public OnWar3EventDeath(victim,attacker){
	if(War3_ValidPlayer(victim)&&War3_ValidPlayer(attacker)&&IsOurRace(attacker)){
		new iSkillLevel=War3_GetSkillLevel(attacker,thisRaceID,SKILL_INFEST);
		if (iSkillLevel>0)
		{
			
			if (War3_GetImmunity(victim,Immunity_Skills))  
			{	
				decl String:name[50];
				GetClientName(victim, name, sizeof(name));
				PrintHintText(attacker,"Could not infest, enemy immunity");
			}
			else{
				
				

				decl Float:location[3];
				GetClientAbsOrigin(victim,location);
				TeleportEntity(attacker, location, NULL_VECTOR, NULL_VECTOR);
				
				new addHealth = RoundFloat(FloatMul(float(War3_GetMaxHP(victim)),HPPercentHealPerKill[iSkillLevel]));
				
				War3_HealToMaxHP(attacker,addHealth);
				//Effects?
				EmitAmbientSound("npc/zombie/zombie_pain2.wav",location);
			}
		}
	}
}


public OnUltimateCommand(client,race,bool:pressed)
{
    if(race==thisRaceID && pressed && War3_ValidPlayer(client))
    {
        new ultLevel=War3_GetSkillLevel(client,thisRaceID,ULT_RAGE);
        if(ultLevel>0)
        {	
			//PrintToChatAll("level %d %f %f",ultLevel,RageDuration[ultLevel],RageAttackSpeed[ultLevel]);
			if(War3_SkillNotInCooldown(client,thisRaceID,ULT_RAGE,true ))
			{
				War3_ChatMessage(client, 
				"You rage for %c%.1f%c seconds, %c+%.0f%c percent attack speed",
				COLOR_LIGHTGREEN, 
				RageDuration[ultLevel],
				COLOR_DEFAULT, 
				COLOR_LIGHTGREEN, 
				(RageAttackSpeed[ultLevel]-1.0)*100.0 ,
				COLOR_DEFAULT
				);

				War3_SetBuff(client,fAttackSpeed,thisRaceID,RageAttackSpeed[ultLevel]);
				
				CreateTimer(RageDuration[ultLevel],stopRage,client);
				War3_CooldownMGR(client,GetConVarFloat(ultCooldownCvar),thisRaceID,ULT_RAGE);
			}
			
			
        }
		else{
			PrintHintText(client,"No Ultimate Leveled");
		}

    }
}
public Action:stopRage(Handle:t,any:client){
	War3_SetBuff(client,fAttackSpeed,thisRaceID,1.0);
	if(War3_ValidPlayer(client)){
		PrintHintText(client,"You are no longer in rage mode");
	}
}
