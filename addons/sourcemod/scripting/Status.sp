#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <connect>

#tryinclude "serverfps.inc"

#pragma newdecls required

ConVar g_Cvar_HostIP;
ConVar g_Cvar_HostPort;
ConVar g_Cvar_HostName;
ConVar g_Cvar_HostTags;

#if !defined _serverfps_included
int g_iTickRate;
#endif

public Plugin myinfo =
{
	name         = "Status Fixer",
	author       = "zaCade + BotoX + Obus",
	description  = "Fixes the \"status\" command",
	version      = "2.0",
	url          = "https://github.com/CSSZombieEscape/sm-plugins/tree/master/Status/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	g_Cvar_HostIP   = FindConVar("hostip");
	g_Cvar_HostPort = FindConVar("hostport");
	g_Cvar_HostName = FindConVar("hostname");
	g_Cvar_HostTags = FindConVar("sv_tags");

	AddCommandListener(Command_Status, "status");
}

public Action Command_Status(int client, const char[] command, int args)
{
	if(!client)
		return Plugin_Continue;

	static char sServerName[128];
	static char sServerTags[128];
	static char sServerAdress[128];

	int iServerIP   = g_Cvar_HostIP.IntValue;
	int iServerPort = g_Cvar_HostPort.IntValue;

	g_Cvar_HostName.GetString(sServerName, sizeof(sServerName));
	g_Cvar_HostTags.GetString(sServerTags, sizeof(sServerTags));

	Format(sServerAdress, sizeof(sServerAdress), "%d.%d.%d.%d:%d", iServerIP >>> 24 & 255, iServerIP >>> 16 & 255, iServerIP >>> 8 & 255, iServerIP & 255, iServerPort);

	static char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));

	float fPosition[3];
	GetClientAbsOrigin(client, fPosition);

	float fClientDataIn = GetClientAvgData(client, NetFlow_Incoming);
	float fClientDataOut = GetClientAvgData(client, NetFlow_Outgoing);
	float fServerDataIn;
	float fServerDataOut;

	GetServerNetStats(fServerDataIn, fServerDataOut);

	int iRealClients;
	int iFakeClients;
	int iTotalClients;

	for(int player = 1; player <= MaxClients; player++)
	{
		if(IsClientConnected(player))
		{
			iTotalClients++;

			if(IsFakeClient(player))
				iFakeClients++;
			else
				iRealClients++;
		}
	}

#if defined _serverfps_included
	float fServerTickRate = 1.0 / GetTickInterval();
	float fServerFPS = GetServerFPS();

	fServerFPS = fServerFPS <= fServerTickRate ? fServerFPS : fServerTickRate;
#else
	int iServerTickRate = RoundToZero(1.0 / GetTickInterval());
	int iTickRate = g_iTickRate;

	iTickRate = iTickRate <= iServerTickRate ? iTickRate : iServerTickRate;
#endif

	PrintToConsole(client, "hostname: %s",
		sServerName);

#if defined _serverfps_included
	PrintToConsole(client, "tickrate : %.2f/%.2f (%d%%)",
		fServerFPS, fServerTickRate, RoundToNearest((fServerFPS / fServerTickRate) * 100));
#else
	PrintToConsole(client, "tickrate : %d/%d (%d%%)",
		iTickRate, iServerTickRate, RoundToNearest((float(iTickRate) / float(iServerTickRate)) * 100));
#endif

	PrintToConsole(client, "udp/ip  : %s",
		sServerAdress);

	PrintToConsole(client, "net I/O : %.2f/%.2f KiB/s (You: %.2f/%.2f KiB/s)",
		fServerDataIn / 1024, fServerDataOut / 1024, fClientDataIn / 1024, fClientDataOut / 1024);

	PrintToConsole(client, "map      : %s at: %.0f x, %.0f y, %.0f z",
		sMapName, fPosition[0], fPosition[1], fPosition[2]);

	PrintToConsole(client, "tags      : %s",
		sServerTags);

	PrintToConsole(client, "edicts : %d/%d/%d (used/max/free)",
		GetEntityCount(), GetMaxEntities(), GetMaxEntities() - GetEntityCount());

	PrintToConsole(client, "players : %d %s | %d %s (%d/%d)",
		iRealClients, Multiple(iRealClients) ? "humans" : "human", iFakeClients, Multiple(iFakeClients) ? "bots" : "bot", iTotalClients, MaxClients);

	PrintToConsole(client, "# %8s %40s %24s %12s %4s %4s %s %s",
		"userid", "name", "uniqueid", "connected", "ping", "loss", "state", "addr");

	for(int player = 1; player <= MaxClients; player++)
	{
		if(!IsClientConnected(player))
			continue;

		static char sPlayerID[8];
		static char sPlayerName[MAX_NAME_LENGTH + 2];
		static char sPlayerAuth[24];
		char sPlayerTime[12];
		char sPlayerPing[4];
		char sPlayerLoss[4];
		static char sPlayerState[16];
		char sPlayerAddr[16];

		FormatEx(sPlayerID, sizeof(sPlayerID), "%d", GetClientUserId(player));
		FormatEx(sPlayerName, sizeof(sPlayerName), "\"%N\"", player);

		if(!GetClientAuthId(player, AuthId_Steam2, sPlayerAuth, sizeof(sPlayerAuth)))
			FormatEx(sPlayerAuth, sizeof(sPlayerAuth), "STEAM_ID_PENDING");

		if(!IsFakeClient(player))
		{
			int iHours   = RoundToFloor((GetClientTime(player) / 3600));
			int iMinutes = RoundToFloor((GetClientTime(player) - (iHours * 3600)) / 60);
			int iSeconds = RoundToFloor((GetClientTime(player) - (iHours * 3600)) - (iMinutes * 60));

			if (iHours)
				FormatEx(sPlayerTime, sizeof(sPlayerTime), "%d:%02d:%02d", iHours, iMinutes, iSeconds);
			else
				FormatEx(sPlayerTime, sizeof(sPlayerTime), "%d:%02d", iMinutes, iSeconds);

			FormatEx(sPlayerPing, sizeof(sPlayerPing), "%d", RoundFloat(GetClientLatency(player, NetFlow_Outgoing) * 800));
			FormatEx(sPlayerLoss, sizeof(sPlayerLoss), "%d", RoundFloat(GetClientAvgLoss(player, NetFlow_Outgoing) * 100));
		}

		if(IsClientInGame(player))
			if (SteamClientAuthenticated(sPlayerAuth))	
				FormatEx(sPlayerState, sizeof(sPlayerState), "active");	
			else	
				FormatEx(sPlayerState, sizeof(sPlayerState), "nosteam");
		else
			FormatEx(sPlayerState, sizeof(sPlayerState), "spawning");

		if(GetAdminFlag(GetUserAdmin(client), Admin_Custom3))
			GetClientIP(player, sPlayerAddr, sizeof(sPlayerAddr));

		PrintToConsole(client, "# %8s %40s %24s %12s %4s %4s %s %s",
			sPlayerID, sPlayerName, sPlayerAuth, sPlayerTime, sPlayerPing, sPlayerLoss, sPlayerState, sPlayerAddr);
	}

	return Plugin_Handled;
}

public void OnGameFrame()
{
#if !defined _serverfps_included //Inaccurate fallback
	static float fLastEngineTime;
	static int iTicks;
	float fCurEngineTime = GetEngineTime(); //GetEngineTime() will become less and less accurate as server uptime goes up!

	iTicks++;

	if (fCurEngineTime - fLastEngineTime >= 1.0)
	{
		g_iTickRate = iTicks;
		iTicks = 0;
		fLastEngineTime = fCurEngineTime;
	}
#endif
}

stock bool Multiple(int num)
{
	return (!num || num > 1);
}