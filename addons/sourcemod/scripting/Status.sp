#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_EXTENSIONS
#tryinclude <geoip>
#tryinclude "serverfps.inc"
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#tryinclude <PlayerManager>
#define REQUIRE_PLUGIN

#pragma newdecls required

ConVar g_Cvar_AuthIdType;
ConVar g_Cvar_OrderBy;
ConVar g_Cvar_HostIP;
ConVar g_Cvar_HostPort;
ConVar g_Cvar_HostName;
ConVar g_Cvar_HostTags;

enum StatusOrderBy
{
	StatusOrderBy_UserId = 0,
	StatusOrderBy_PlayerName,
	StatusOrderBy_Time,
	StatusOrderBy_Ping,
	StatusOrderBy_State
};

#if !defined _serverfps_included
int g_iTickRate;
#endif

public Plugin myinfo =
{
	name         = "Status Fixer",
	author       = "zaCade + BotoX + Obus + .Rushaway",
	description  = "Fixes the \"status\" command",
	version      = "2.2.0",
	url          = "https://github.com/srcdslab/sm-plugin-Status"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_Cvar_AuthIdType = CreateConVar("sm_status_authid_type", "1", "AuthID type used [0 = Engine, 1 = Steam2, 2 = Steam3, 3 = Steam64]", FCVAR_NONE, true, 0.0, true, 3.0);
	g_Cvar_OrderBy = CreateConVar("sm_status_order_by", "0", "Order player rows by [0 = userid, 1 = playername, 2 = time, 3 = ping, 4 = steam->nosteam->spawning]", FCVAR_NONE, true, 0.0, true, 4.0);
	AutoExecConfig(true);
	
	g_Cvar_HostIP   = FindConVar("hostip");
	g_Cvar_HostPort = FindConVar("hostport");
	g_Cvar_HostName = FindConVar("hostname");
	g_Cvar_HostTags = FindConVar("sv_tags");

	AddCommandListener(Command_Status, "status");
}

public Action Command_Status(int client, const char[] command, int args)
{
	bool bGeoIP = false;
	bool bIsAdmin = false;
	bool bPlayerManager = GetFeatureStatus(FeatureType_Native, "PM_IsPlayerSteam") == FeatureStatus_Available;

	static char sHostName[128], sServerName[256];
	static char sTags[128], sServerTags[256];
	static char sAdress[128], sServerAdress[256];

	int iServerIP   = g_Cvar_HostIP.IntValue;
	int iServerPort = g_Cvar_HostPort.IntValue;

	g_Cvar_HostName.GetString(sHostName, sizeof(sHostName));
	g_Cvar_HostTags.GetString(sTags, sizeof(sTags));

	FormatEx(sServerName, sizeof(sServerName), "hostname: %s", sHostName);
	FormatEx(sServerTags, sizeof(sServerTags), "tags      : %s", sTags);
	FormatEx(sAdress, sizeof(sAdress), "%d.%d.%d.%d:%d", iServerIP >>> 24 & 255, iServerIP >>> 16 & 255, iServerIP >>> 8 & 255, iServerIP & 255, iServerPort);
	FormatEx(sServerAdress, sizeof(sServerAdress), "udp/ip  : %s", sAdress);

	if (client == 0 || GetAdminFlag(GetUserAdmin(client), Admin_RCON))
		bIsAdmin = true;

	if (GetFeatureStatus(FeatureType_Native, "GeoipCode3") == FeatureStatus_Available)
		bGeoIP = true;

	static char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));

	float fServerDataIn, fServerDataOut;
	GetServerNetStats(fServerDataIn, fServerDataOut);

	char sServerData[128], sServerMap[128];
	if (client > 0 && client <= MaxClients)
	{
		float fPosition[3];
		float fClientDataIn, fClientDataOut;

		GetClientAbsOrigin(client, fPosition);
		fClientDataIn = GetClientAvgData(client, NetFlow_Incoming);
		fClientDataOut = GetClientAvgData(client, NetFlow_Outgoing);

		FormatEx(sServerData, sizeof(sServerData), "net I/O : %.2f/%.2f KiB/s (You: %.2f/%.2f KiB/s)", fServerDataIn / 1024, fServerDataOut / 1024, fClientDataIn / 1024, fClientDataOut / 1024);
		FormatEx(sServerMap, sizeof(sServerMap), "map      : %s at: %.0f x, %.0f y, %.0f z", sMapName, fPosition[0], fPosition[1], fPosition[2]);
	}
	else
	{
		FormatEx(sServerData, sizeof(sServerData), "net I/O : %.2f/%.2f KiB/s", fServerDataIn / 1024, fServerDataOut / 1024);
		FormatEx(sServerMap, sizeof(sServerMap), "map      : %s", sMapName);
	}

	int iRealClients, iFakeClients, iTotalClients;
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientConnected(player))
		{
			iTotalClients++;

			if (IsFakeClient(player))
				iFakeClients++;
			else
				iRealClients++;
		}
	}

	char sServerPlayers[128];
	FormatEx(sServerPlayers, sizeof(sServerPlayers), "players : %d %s | %d %s (%d/%d)", 
		iRealClients, Multiple(iRealClients) ? "humans" : "human", iFakeClients, Multiple(iFakeClients) ? "bots" : "bot", iTotalClients, MaxClients);

	char sServerTickRate[128];
#if defined _serverfps_included

	float fServerTickRate = 1.0 / GetTickInterval();
	float fServerFPS = GetServerFPS();
	fServerFPS = fServerFPS <= fServerTickRate ? fServerFPS : fServerTickRate;

	FormatEx(sServerTickRate, sizeof(sServerTickRate), "tickrate : %.2f/%.2f (%d%%)", fServerFPS, fServerTickRate, RoundToNearest((fServerFPS / fServerTickRate) * 100));
#else
	int iServerTickRate = RoundToZero(1.0 / GetTickInterval());
	int iTickRate = g_iTickRate;
	iTickRate = iTickRate <= iServerTickRate ? iTickRate : iServerTickRate;

	FormatEx(sServerTickRate, sizeof(sServerTickRate), "tickrate : %d/%d (%d%%)", iTickRate, iServerTickRate, RoundToNearest((float(iTickRate) / float(iServerTickRate)) * 100));
#endif

	char sServerEdicts[128];
	int iMaxEdicts = GetMaxEntities();
	int iUsedEdicts = GetEntityCount();
	FormatEx(sServerEdicts, sizeof(sServerEdicts), "edicts : %d/%d/%d (used/max/free)", iUsedEdicts, iMaxEdicts, iMaxEdicts - iUsedEdicts);

	// Build Header + Content title
	char sHeader[2048];
	FormatEx(sHeader, sizeof(sHeader), "%s \n%s \n%s \n%s \n%s \n%s \n%s \n%s", 
		sServerName, sServerTickRate, sServerAdress, sServerData, sServerMap, sServerTags, sServerEdicts, sServerPlayers);

	char sTitle[256];
	FormatEx(sTitle, sizeof(sTitle), "# %8s %40s %24s %12s %4s %4s %7s %12s %s", "userid", "name", "uniqueid", "connected", "ping", "loss", "state", "addr", "country");

	PrintToConsole(client, "%s \n%s", sHeader, sTitle);

	int iPlayers[MAXPLAYERS + 1];
	int iPlayerCount;

	for (int player = 1; player <= MaxClients; player++)
	{
		if (!IsClientConnected(player))
			continue;

		iPlayers[iPlayerCount++] = player;
	}

	SortPlayers(iPlayers, iPlayerCount, view_as<StatusOrderBy>(g_Cvar_OrderBy.IntValue), bPlayerManager);

	for (int i = 0; i < iPlayerCount; i++)
	{
		int player = iPlayers[i];

		static char sPlayerID[8];
		static char sPlayerName[MAX_NAME_LENGTH + 2];
		static char sPlayerAuth[24];
		char sPlayerTime[12];
		char sPlayerPing[8];
		char sPlayerLoss[8];
		char sPlayerState[16];
		char sPlayerAddr[32];
		char sGeoIP[4] = "N/A";

		FormatEx(sPlayerID, sizeof(sPlayerID), "%d", GetClientUserId(player));
		FormatEx(sPlayerName, sizeof(sPlayerName), "\"%N\"", player);

		AuthIdType authType = view_as<AuthIdType>(g_Cvar_AuthIdType.IntValue);
		if (!GetClientAuthId(player, authType, sPlayerAuth, sizeof(sPlayerAuth)))
			FormatEx(sPlayerAuth, sizeof(sPlayerAuth), "STEAM_ID_PENDING");

		if (!IsFakeClient(player))
		{
			float fTime = GetClientTime(player);
			int iHours   = RoundToFloor((fTime / 3600));
			int iMinutes = RoundToFloor((fTime - (iHours * 3600)) / 60);
			int iSeconds = RoundToFloor((fTime - (iHours * 3600)) - (iMinutes * 60));

			if (iHours)
				FormatEx(sPlayerTime, sizeof(sPlayerTime), "%d:%02d:%02d", iHours, iMinutes, iSeconds);
			else
				FormatEx(sPlayerTime, sizeof(sPlayerTime), "%d:%02d", iMinutes, iSeconds);

			FormatEx(sPlayerPing, sizeof(sPlayerPing), "%d", RoundFloat(GetClientLatency(player, NetFlow_Outgoing) * 1000));
			FormatEx(sPlayerLoss, sizeof(sPlayerLoss), "%d", RoundFloat(GetClientAvgLoss(player, NetFlow_Outgoing) * 100));
		}

		GetPlayerStateLabel(player, bPlayerManager, sPlayerState, sizeof(sPlayerState));

		if (!IsFakeClient(player))	
			GetClientIP(player, sPlayerAddr, sizeof(sPlayerAddr));

		if (bGeoIP && !IsFakeClient(player))
			GeoipCode3(sPlayerAddr, sGeoIP);

		PrintToConsole(client, "# %8s %40s %24s %12s %4s %4s %7s %12s %s",
			sPlayerID, sPlayerName, sPlayerAuth, sPlayerTime, sPlayerPing, sPlayerLoss, sPlayerState, bIsAdmin ? sPlayerAddr : "Private", sGeoIP);
	}

	return Plugin_Handled;
}

void SortPlayers(int[] players, int count, StatusOrderBy orderBy, bool bPlayerManager)
{
	for (int i = 0; i < count - 1; i++)
	{
		for (int j = i + 1; j < count; j++)
		{
			if (!ShouldPlayerComeBefore(players[j], players[i], orderBy, bPlayerManager))
				continue;

			int temp = players[i];
			players[i] = players[j];
			players[j] = temp;
		}
	}
}

bool ShouldPlayerComeBefore(int candidatePlayer, int currentPlayer, StatusOrderBy orderBy, bool bPlayerManager)
{
	switch (orderBy)
	{
		case StatusOrderBy_PlayerName:
		{
			char candidateName[MAX_NAME_LENGTH];
			char currentName[MAX_NAME_LENGTH];

			GetClientName(candidatePlayer, candidateName, sizeof(candidateName));
			GetClientName(currentPlayer, currentName, sizeof(currentName));

			int compare = strcmp(candidateName, currentName, false);
			if (compare < 0)
				return true;

			if (compare > 0)
				return false;
		}
		case StatusOrderBy_Time:
		{
			float candidateTime = GetClientTime(candidatePlayer);
			float currentTime = GetClientTime(currentPlayer);

			if (candidateTime > currentTime)
				return true;

			if (candidateTime < currentTime)
				return false;
		}
		case StatusOrderBy_Ping:
		{
			int candidatePing = IsFakeClient(candidatePlayer) ? 9999 : RoundFloat(GetClientLatency(candidatePlayer, NetFlow_Outgoing) * 1000.0);
			int currentPing = IsFakeClient(currentPlayer) ? 9999 : RoundFloat(GetClientLatency(currentPlayer, NetFlow_Outgoing) * 1000.0);

			if (candidatePing < currentPing)
				return true;

			if (candidatePing > currentPing)
				return false;
		}
		case StatusOrderBy_State:
		{
			int candidateState = GetPlayerStateSortRank(candidatePlayer, bPlayerManager);
			int currentState = GetPlayerStateSortRank(currentPlayer, bPlayerManager);

			if (candidateState < currentState)
				return true;

			if (candidateState > currentState)
				return false;
		}
	}

	return GetClientUserId(candidatePlayer) < GetClientUserId(currentPlayer);
}

int GetPlayerStateSortRank(int player, bool bPlayerManager)
{
	if (!IsClientInGame(player))
		return 2;

#if defined _PlayerManager_included
	if (bPlayerManager && !IsFakeClient(player) && !PM_IsPlayerSteam(player))
		return 1;
#endif

	return 0;
}

void GetPlayerStateLabel(int player, bool bPlayerManager, char[] buffer, int maxlen)
{
	if (!IsClientInGame(player))
	{
		FormatEx(buffer, maxlen, "spawning");
		return;
	}

#if defined _PlayerManager_included
	if (bPlayerManager && !IsFakeClient(player) && !PM_IsPlayerSteam(player))
	{
		FormatEx(buffer, maxlen, "nosteam");
		return;
	}
#endif

	FormatEx(buffer, maxlen, "active");
}

#if !defined _serverfps_included //Inaccurate fallback
public void OnGameFrame()
{
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
}
#endif

stock bool Multiple(int num)
{
	return (!num || num > 1);
}
