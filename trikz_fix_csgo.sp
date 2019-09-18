#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <clientprefs>
#include <trikznobug>

#define PLUGIN_VERSION "2.02 GO"

// FlashBoost Extra Settings
#define REMOVE_FLASH	1

new bool:bLateLoad = false;
new Float:g_fFlashMultiplier = 0.869325;

// FlashBoost
new bool:g_bFlashBoost[MAXPLAYERS+1];
new Float:g_vFlashAbsVelocity[MAXPLAYERS+1][3];
new bool:g_bGroundBoost[MAXPLAYERS+1];
new g_FlashHitSound[2048];

// SkyBoost
new bool:g_bSkyEnable[MAXPLAYERS+1] = {true, ...};
new Float:g_fBoosterAbsVelocityZ[MAXPLAYERS+1];
new g_SkyTouch[MAXPLAYERS+1];
new g_SkyReq[MAXPLAYERS+1];
new Float:g_vSkyBoostVel[MAXPLAYERS+1][3];

public Plugin:myinfo = 
{
	name = "[Trikz] Flash/Sky Fix",
	author = "ici & george",
	version = PLUGIN_VERSION
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {

	bLateLoad = late;
	CreateNative("Trikz_SkyFix", Native_Trikz_SkyFix);
	return APLRes_Success;
}

public Native_Trikz_SkyFix(Handle:plugin, numParams) {

	g_bSkyEnable[GetNativeCell(1)] = bool:GetNativeCell(2);
}

public OnPluginStart() {

	AddNormalSoundHook(NormalSHook:SoundsHook);
	RegServerCmd("sm_flashmul", SM_FlashMul);
	
	if (bLateLoad)
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientConnected(i) && IsClientInGame(i))
				OnClientPutInServer(i);
}

public Action:SM_FlashMul(args)
{
	decl String:sArg[64];
	GetCmdArg(1, sArg, sizeof(sArg));
	new Float:arg1 = StringToFloat(sArg);
	g_fFlashMultiplier = arg1;
	PrintToChatAll("Flash Multiplier: %f", g_fFlashMultiplier);
}

public OnClientPutInServer(client) {

	// FlashBoost
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	
	// SkyBoost
	SDKHook(client, SDKHook_Touch, Hook_Touch);
	
	g_SkyTouch[client] = 0;
	g_SkyReq[client] = 0;
}

public OnEntityDestroyed(edict) {

	if (IsValidEdict(edict)) {
		decl String:sEdictName[32];
		GetEdictClassname(edict, sEdictName, sizeof(sEdictName));
		if (StrEqual(sEdictName, "flashbang_projectile")) {
			g_FlashHitSound[edict] = 0;
		}
	}
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {

	if (g_bFlashBoost[victim]
	|| !IsValidClient(victim)
	|| GetEntityMoveType(victim) == MOVETYPE_LADDER) return Plugin_Continue;
	
	decl String:Weapon[32];
	GetEdictClassname(inflictor, Weapon, sizeof(Weapon));
	if (StrContains(Weapon, "flashbang", false) == -1) return Plugin_Continue;
	
	new GroundEntity = GetEntPropEnt(victim, Prop_Data, "m_hGroundEntity");
	if (IsValidEdict(GroundEntity)) {
		GetEdictClassname(GroundEntity, Weapon, sizeof(Weapon));
		if (StrContains(Weapon, "flashbang", false) == -1) {
			PrintToChatAll("Failed GroundEntity");
			return Plugin_Continue;
		}
	}
	
	decl Float:vFlashOrigin[3];
	decl Float:vVictimOrigin[3];
	decl Float:vVictimAbsVelocity[3];
	decl Float:vAttackerOrigin[3];
	
	GetEntPropVector(inflictor, Prop_Data, "m_vecOrigin", vFlashOrigin);
	GetEntPropVector(victim, Prop_Data, "m_vecOrigin", vVictimOrigin);
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", vVictimAbsVelocity);
	GetEntPropVector(attacker, Prop_Data, "m_vecOrigin", vAttackerOrigin);
	
	// if ((vFlashOrigin[2] > vVictimOrigin[2])
	// || ((vVictimOrigin[2] >= vAttackerOrigin[2]))
	// || (((vFlashOrigin[0] < (vVictimOrigin[0] - 16.0)) || (vFlashOrigin[0] > (vVictimOrigin[0] + 16.0)))
	// && ((vFlashOrigin[1] < (vVictimOrigin[1] - 16.0)) || (vFlashOrigin[1] > (vVictimOrigin[1] + 16.0))))) {
		// PrintToChatAll("Something else is wrong");
		// return Plugin_Continue;
	// }
	
	if (g_FlashHitSound[inflictor] > 0)
		g_bGroundBoost[victim] = true;
	
	GetEntPropVector(inflictor, Prop_Data, "m_vecAbsVelocity", g_vFlashAbsVelocity[victim]);
	g_bFlashBoost[victim] = true;
	
#if (REMOVE_FLASH == 1)
	CreateTimer(0.01, Timer_RemoveFlash, inflictor);
#endif
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client) {

	if (g_bFlashBoost[client]) {
		decl Float:vClientAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vClientAbsVelocity);
		
		PrintToChatAll("Client: %.2f %.2f %.2f Flash: %.2f %.2f %.2f",
			vClientAbsVelocity[0], vClientAbsVelocity[1], vClientAbsVelocity[2],
			g_vFlashAbsVelocity[0], g_vFlashAbsVelocity[1], g_vFlashAbsVelocity[2]);
		
		// 0,8693248760112110724220573123187
		vClientAbsVelocity[0] += g_vFlashAbsVelocity[client][0] * -g_fFlashMultiplier;
		vClientAbsVelocity[1] += g_vFlashAbsVelocity[client][1] * -g_fFlashMultiplier;
		vClientAbsVelocity[2] = g_vFlashAbsVelocity[client][2];
		
		if (g_bGroundBoost[client]) {
			g_bGroundBoost[client] = false;
		} else {
			SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", INVALID_ENT_REFERENCE);
			SetEntityFlags(client, (GetEntityFlags(client) & ~FL_ONGROUND));
		}
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vClientAbsVelocity);
		g_bFlashBoost[client] = false;
	}
	return Plugin_Continue;
}

public Action:SoundsHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags) {

	if (!IsValidEdict(entity)) return Plugin_Continue;
	
	decl String:sEntityName[32];
	GetEdictClassname(entity, sEntityName, sizeof(sEntityName));
	if (!StrEqual(sEntityName, "flashbang_projectile")) return Plugin_Continue;
	
	++g_FlashHitSound[entity];
	return Plugin_Continue;
}

public Action:Hook_Touch(victim, other) {

	if (!g_bSkyEnable[victim]
	|| g_bFlashBoost[victim]
	|| !IsValidClient(other)
	|| GetEntityMoveType(victim) == MOVETYPE_LADDER
	|| GetEntityMoveType(other) == MOVETYPE_LADDER) return Plugin_Continue;
	
	new col = GetEntProp(other, Prop_Data, "m_CollisionGroup");
	if (col != 5) return Plugin_Continue;
	
	decl Float:vVictimOrigin[3];
	decl Float:vBoosterOrigin[3];
	
	GetEntPropVector(victim, Prop_Data, "m_vecOrigin", vVictimOrigin);
	GetEntPropVector(other, Prop_Data, "m_vecOrigin", vBoosterOrigin);
	
	if ((Math_Abs(vVictimOrigin[0] - vBoosterOrigin[0]) > 32.0)
	|| (Math_Abs(vVictimOrigin[1] - vBoosterOrigin[1]) > 32.0)
	|| (vVictimOrigin[2] - vBoosterOrigin[2]) < 45.0)
		return Plugin_Continue;
	
	decl Float:vBoosterAbsVelocity[3];
	GetEntPropVector(other, Prop_Data, "m_vecAbsVelocity", vBoosterAbsVelocity);
	if (vBoosterAbsVelocity[2] <= 0.0) return Plugin_Continue;
	
	g_fBoosterAbsVelocityZ[victim] += vBoosterAbsVelocity[2];
	++g_SkyTouch[victim];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", g_vSkyBoostVel[victim]);
	
	RequestFrame(SkyFrame_Callback, victim);
	return Plugin_Continue;
}

public SkyFrame_Callback(any:victim) {

	if (g_SkyTouch[victim] == 0)
		return;
	
	if (g_bFlashBoost[victim]) {
		g_fBoosterAbsVelocityZ[victim] = 0.0;
		g_SkyTouch[victim] = 0;
		g_SkyReq[victim] = 0;
		return;
	}
	
	++g_SkyReq[victim];
	decl Float:vVictimAbsVelocity[3];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", vVictimAbsVelocity);
	
	if (vVictimAbsVelocity[2] > 0.0) {
		g_vSkyBoostVel[victim][2] = vVictimAbsVelocity[2] + g_fBoosterAbsVelocityZ[victim] * 0.5;
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, g_vSkyBoostVel[victim]);
		g_fBoosterAbsVelocityZ[victim] = 0.0;
		g_SkyTouch[victim] = 0;
		g_SkyReq[victim] = 0;
	} else {
		if (g_SkyReq[victim] > 150) {
			g_fBoosterAbsVelocityZ[victim] = 0.0;
			g_SkyTouch[victim] = 0;
			g_SkyReq[victim] = 0;
			return;
		}
		// Recurse for a few more frames
		RequestFrame(SkyFrame_Callback, victim);
	}
}

bool:IsValidClient(client) {

	return (0 < client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}

Float:Math_Abs(Float:value) {

	return (value >= 0.0 ? value : -value);
}

#if (REMOVE_FLASH == 1)
public Action:Timer_RemoveFlash(Handle:timer, any:inflictor) {

	if (IsValidEdict(inflictor)) {
		AcceptEntityInput(inflictor, "Kill");
	}
}
#endif
