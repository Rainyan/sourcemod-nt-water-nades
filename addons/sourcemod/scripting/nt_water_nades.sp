#include <sourcemod>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.1.1"

#define WATERLVL_LAND 0

int _waterlvls[32 + 1];
int _offs_waterlvl;
bool _spoofing;


public Plugin myinfo = {
	name = "NT Water Nades",
	description = "Make players on land take damage from nearby submerged explosives.",
	author = "Rain",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rainyan/sourcemod-nt-water-nades"
};

public void OnPluginStart()
{
	_offs_waterlvl = FindSendPropInfo("CNEOPlayer", "m_nWaterLevel");
	if (_offs_waterlvl <= 0)
	{
		SetFailState("Failed to find sendprop offset");
	}
}

public void OnMapStart()
{
	DynamicHook dh = DHookCreate(50, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if (!dh)
	{
		SetFailState("Failed to setup dynamic hook");
	}
	DHookAddParam(dh, HookParamType_ObjectPtr); // const CTakeDamageInfo &info
	DHookAddParam(dh, HookParamType_VectorPtr); // const Vector &vecSrcIn
	DHookAddParam(dh, HookParamType_Float); // float flRadius
	DHookAddParam(dh, HookParamType_Int); // int iClassIgnore
	DHookAddParam(dh, HookParamType_CBaseEntity); // CBaseEntity *pEntityIgnore
	if (INVALID_HOOK_ID == DHookGamerules(dh, false, _, RadiusDamage))
	{
		SetFailState("Failed to hook");
	}
	if (INVALID_HOOK_ID == DHookGamerules(dh, true, _, RadiusDamage_Post))
	{
		SetFailState("Failed to hook");
	}
	delete dh;
}

public MRESReturn RadiusDamage_Post(DHookParam hParams)
{
	if (!_spoofing)
	{
		return MRES_Ignored;
	}

	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			if (_waterlvls[client] == WATERLVL_LAND)
			{
				// Undo the waterlevel serverside spoofing.
				SetEntData(client, _offs_waterlvl, WATERLVL_LAND, 2, false);
			}
		}
	}
	return MRES_Ignored;
}

public MRESReturn RadiusDamage(DHookParam hParams)
{
	float vecSrcIn[3];
	hParams.GetVector(2, vecSrcIn);

	_spoofing = (TR_GetPointContents(vecSrcIn) & MASK_WATER) ? true : false;
	if (!_spoofing)
	{
		//PrintToServer("Land grenade; NOT spoofing");
		return MRES_Ignored;
	}

	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			_waterlvls[client] = GetEntData(client, _offs_waterlvl, 2);
			if (_waterlvls[client] == WATERLVL_LAND)
			{
				// If on land, spoof the waterlevel to bypass land
				// players skipping submerged nade damage.
				// Don't send to client because it's a one-off serverside hack.
				SetEntData(client, _offs_waterlvl, 1, 2, false);
			}
		}
	}
	return MRES_Handled;
}
