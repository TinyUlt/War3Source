

#include <sourcemod>
#include "W3SIncs/War3Source_Interface"


new bool:playerOwnsItem[MAXPLAYERS][MAXITEMS];
new Handle:g_OnItemPurchaseHandle;
new Handle:g_OnItemLostHandle;

new Handle:hitemRestrictionCvar;

public Plugin:myinfo= 
{
	name="War3Source Engine Item Class",
	author="Ownz",
	description="War3Source Core Plugins",
	version="1.0",
	url="http://war3source.com/"
};



public APLRes:AskPluginLoad2(Handle:myself,bool:late,String:error[],err_max)
{
	if(!InitNativesForwards())
	{
		LogError("[War3Source] There was a failure in creating the native / forwards based functions, definately halting.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	hitemRestrictionCvar=CreateConVar("war3_item_restrict","","Disallow items in shopmenu, shortname separated by comma only ie:'claw,orb'");
}

bool:InitNativesForwards()
{
	g_OnItemPurchaseHandle=CreateGlobalForward("OnItemPurchase",ET_Ignore,Param_Cell,Param_Cell);
	g_OnItemLostHandle=CreateGlobalForward("OnItemLost",ET_Ignore,Param_Cell,Param_Cell);

	CreateNative("War3_GetOwnsItem",NWar3_GetOwnsItem);
	CreateNative("War3_SetOwnsItem",NWar3_SetOwnsItem);
	
	CreateNative("W3IsItemDisabledGlobal",NW3IsItemDisabledGlobal);
	CreateNative("W3IsItemDisabledForRace",NW3IsItemDisabledForRace);
	return true;
}

public NWar3_GetOwnsItem(Handle:plugin,numParams)
{
	return _:playerOwnsItem[GetNativeCell(1)][GetNativeCell(2)];

}

public NWar3_SetOwnsItem(Handle:plugin,numParams)
{

	playerOwnsItem[GetNativeCell(1)][GetNativeCell(2)]=bool:GetNativeCell(3);
}
public NW3IsItemDisabledGlobal(Handle:plugin,numParams)
{
	new itemid=GetNativeCell(1);
	decl String:itemShort[16];
	W3GetItemShortname(itemid,itemShort,16);
	
	decl String:cvarstr[100];
	decl String:exploded[MAXITEMS][16];
	decl num;
	GetConVarString(hitemRestrictionCvar,cvarstr,99);
	if(strlen(cvarstr)>0){
		num=ExplodeString(cvarstr,",",exploded,MAXITEMS,16);
		for(new i=0;i<num;i++){
			//PrintToServer("'%s' compared to: '%s' num%d",exploded[i],itemShort,num);
			if(StrEqual(exploded[i],itemShort,false)){
				//PrintToServer("TRUE");
				return true;
			}
		}
	}
	return false;
}
public NW3IsItemDisabledForRace(Handle:plugin,numParams)
{
	new raceid=GetNativeCell(1);
	new itemid=GetNativeCell(2);
	if(raceid>0){
		decl String:itemShort[16];
		GetItemShortname(itemid,itemShort,16);
		
		decl String:cvarstr[100];
		decl String:exploded[MAXITEMS][16];
		
		W3GetRaceItemRestrictionsStr(raceid,cvarstr,99);
		
		new num;
		if(strlen(cvarstr)>0){
			num=ExplodeString(cvarstr,",",exploded,MAXITEMS,16);
			for(new i=0;i<num;i++){
				//PrintToServer("'%s' compared to: '%s' num%d",exploded[i],itemShort,num);
				if(StrEqual(exploded[i],itemShort,false)){
					//PrintToServer("TRUE");
					return true;
				}
			}
		}
	}
	return false;
}

















public OnWar3Event(W3EVENT:event,client){
	if(event==DoForwardClientBoughtItem){
		new itemid=W3GetVar(TheItemBoughtOrLost);
		War3_SetOwnsItem(client,itemid,true);
	
		Call_StartForward(g_OnItemPurchaseHandle); 
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(dummy);
	}
	if(event==DoForwardClientLostItem){
		new itemid=W3GetVar(TheItemBoughtOrLost);
		War3_SetOwnsItem(client,itemid,false);
	
		Call_StartForward(g_OnItemLostHandle); 
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(dummy);
	}
}
