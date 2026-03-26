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

static int   s_iSortUserIds  [MAXPLAYERS + 1];
static char  s_sSortNames    [MAXPLAYERS + 1][MAX_NAME_LENGTH];
static float s_fSortTimes    [MAXPLAYERS + 1];
static int   s_iSortPings    [MAXPLAYERS + 1];
static int   s_iSortStates   [MAXPLAYERS + 1];
static StatusOrderBy s_eSortOrderBy;

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
	bool bGeoIP = GetFeatureStatus(FeatureType_Native, "GeoipCode3") == FeatureStatus_Available;
	bool bIsAdmin = (!client || GetAdminFlag(GetUserAdmin(client), Admin_RCON));
	bool bPlayerManager = GetFeatureStatus(FeatureType_Native, "PM_IsPlayerSteam") == FeatureStatus_Available;

	static char sHostName[128], sServerName[256];
	static char sTags[128], sServerTags[256];
	static char sAdress[128], sServerAdress[256];

	int iServerIP   = g_Cvar_HostIP.IntValue;
	int iServerPort = g_Cvar_HostPort.IntValue;

	g_Cvar_HostName.GetString(sHostName, sizeof(sHostName));
	g_Cvar_HostTags.GetString(sTags, sizeof(sTags));

	FormatEx(sServerName,   sizeof(sServerName),   "hostname: %s", sHostName);
	FormatEx(sServerTags,   sizeof(sServerTags),   "tags      : %s", sTags);
	FormatEx(sAdress,       sizeof(sAdress),        "%d.%d.%d.%d:%d", iServerIP >>> 24 & 255, iServerIP >>> 16 & 255, iServerIP >>> 8 & 255, iServerIP & 255, iServerPort);
	FormatEx(sServerAdress, sizeof(sServerAdress),  "udp/ip  : %s", sAdress);

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
		fClientDataIn  = GetClientAvgData(client, NetFlow_Incoming);
		fClientDataOut = GetClientAvgData(client, NetFlow_Outgoing);

		FormatEx(sServerData, sizeof(sServerData), "net I/O : %.2f/%.2f KiB/s (You: %.2f/%.2f KiB/s)", fServerDataIn / 1024, fServerDataOut / 1024, fClientDataIn / 1024, fClientDataOut / 1024);
		FormatEx(sServerMap,  sizeof(sServerMap),  "map      : %s at: %.0f x, %.0f y, %.0f z", sMapName, fPosition[0], fPosition[1], fPosition[2]);
	}
	else
	{
		FormatEx(sServerData, sizeof(sServerData), "net I/O : %.2f/%.2f KiB/s", fServerDataIn / 1024, fServerDataOut / 1024);
		FormatEx(sServerMap,  sizeof(sServerMap),  "map      : %s", sMapName);
	}

	int iPlayers[MAXPLAYERS + 1];
	int iRealClients, iFakeClients, iTotalClients;
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (!IsClientConnected(iPlayer))
			continue;

		if (IsFakeClient(iPlayer))
			iFakeClients++;
		else
			iRealClients++;

		iPlayers[iTotalClients++] = iPlayer;
	}

	char sServerPlayers[128];
	FormatEx(sServerPlayers, sizeof(sServerPlayers), "players : %d %s | %d %s (%d/%d)",
		iRealClients, Multiple(iRealClients) ? "humans" : "human", iFakeClients, Multiple(iFakeClients) ? "bots" : "bot", iTotalClients, MaxClients);

	char sServerTickRate[128];
#if defined _serverfps_included
	float fServerTickRate = 1.0 / GetTickInterval();
	float fServerFPS      = GetServerFPS();
	fServerFPS = fServerFPS <= fServerTickRate ? fServerFPS : fServerTickRate;

	FormatEx(sServerTickRate, sizeof(sServerTickRate), "tickrate : %.2f/%.2f (%d%%)", fServerFPS, fServerTickRate, RoundToNearest((fServerFPS / fServerTickRate) * 100));
#else
	int iServerTickRate = RoundToZero(1.0 / GetTickInterval());
	int iTickRate       = g_iTickRate;
	iTickRate = iTickRate <= iServerTickRate ? iTickRate : iServerTickRate;

	FormatEx(sServerTickRate, sizeof(sServerTickRate), "tickrate : %d/%d (%d%%)", iTickRate, iServerTickRate, RoundToNearest((float(iTickRate) / float(iServerTickRate)) * 100));
#endif

	char sServerEdicts[128];
	int iMaxEdicts  = GetMaxEntities();
	int iUsedEdicts = GetEntityCount();
	FormatEx(sServerEdicts, sizeof(sServerEdicts), "edicts : %d/%d/%d (used/max/free)", iUsedEdicts, iMaxEdicts, iMaxEdicts - iUsedEdicts);

	// Build Header
	char sHeader[2048];
	FormatEx(sHeader, sizeof(sHeader), "%s \n%s \n%s \n%s \n%s \n%s \n%s \n%s",
		sServerName, sServerTickRate, sServerAdress, sServerData, sServerMap, sServerTags, sServerEdicts, sServerPlayers);

	// Determine width for the uniqueid column based on the AuthIdType, to ensure proper alignment of the table.
	int iAuthIdWidth;
	switch (view_as<AuthIdType>(g_Cvar_AuthIdType.IntValue))
	{
		case AuthId_Steam3:
			iAuthIdWidth = 30;

		default:
			iAuthIdWidth = 24;
	}

	// Build formats for title and rows, with dynamic width for the uniqueid column
	char sTitleFmt[64], sRowFmt[64];
	FormatEx(sTitleFmt, sizeof(sTitleFmt), "# %%8s %%40s %%-%ds %%12s %%4s %%4s %%7s %%12s %%s", iAuthIdWidth);
	FormatEx(sRowFmt,   sizeof(sRowFmt),   "# %%8s %%40s %%-%ds %%12s %%4s %%4s %%7s %%12s %%s", iAuthIdWidth);

	char sTitle[256];
	FormatEx(sTitle, sizeof(sTitle), sTitleFmt,
		"userid", "name", "uniqueid", "connected", "ping", "loss", "state", "addr", "country");

	PrintToConsole(client, "%s \n%s", sHeader, sTitle);

	SortPlayers(iPlayers, iTotalClients, view_as<StatusOrderBy>(g_Cvar_OrderBy.IntValue), bPlayerManager);

	AuthIdType eAuthType = view_as<AuthIdType>(g_Cvar_AuthIdType.IntValue);

	for (int i = 0; i < iTotalClients; i++)
	{
		int iPlayer = iPlayers[i];

		char sPlayerID[8];
		char sPlayerName[MAX_NAME_LENGTH + 2];
		char sPlayerAuth[32];
		char sPlayerTime[12];
		char sPlayerPing[8];
		char sPlayerLoss[8];
		char sPlayerState[16];
		char sPlayerAddr[32];
		char sGeoIP[4] = "N/A";

		FormatEx(sPlayerID,   sizeof(sPlayerID),   "%d", GetClientUserId(iPlayer));
		FormatEx(sPlayerName, sizeof(sPlayerName), "\"%N\"", iPlayer);

		if (!GetClientAuthId(iPlayer, eAuthType, sPlayerAuth, sizeof(sPlayerAuth)))
			FormatEx(sPlayerAuth, sizeof(sPlayerAuth), "STEAM_ID_PENDING");

		if (!IsFakeClient(iPlayer))
		{
			int iTime    = RoundToFloor(GetClientTime(iPlayer));
			int iHours   = iTime / 3600;
			int iMinutes = (iTime - (iHours * 3600)) / 60;
			int iSeconds = iTime - (iHours * 3600) - (iMinutes * 60);

			if (iHours)
				FormatEx(sPlayerTime, sizeof(sPlayerTime), "%d:%02d:%02d", iHours, iMinutes, iSeconds);
			else
				FormatEx(sPlayerTime, sizeof(sPlayerTime), "%d:%02d", iMinutes, iSeconds);

			FormatEx(sPlayerPing, sizeof(sPlayerPing), "%d", RoundFloat(GetClientLatency(iPlayer, NetFlow_Outgoing) * 1000));
			FormatEx(sPlayerLoss, sizeof(sPlayerLoss), "%d", RoundFloat(GetClientAvgLoss(iPlayer, NetFlow_Outgoing) * 100));
		}

		GetPlayerStateLabel(iPlayer, bPlayerManager, sPlayerState, sizeof(sPlayerState));

		if (!IsFakeClient(iPlayer) && (bIsAdmin || bGeoIP))
			GetClientIP(iPlayer, sPlayerAddr, sizeof(sPlayerAddr));

		if (bGeoIP && !IsFakeClient(iPlayer))
			GeoipCode3(sPlayerAddr, sGeoIP);

		PrintToConsole(client, sRowFmt,
			sPlayerID, sPlayerName, sPlayerAuth, sPlayerTime, sPlayerPing, sPlayerLoss,
			sPlayerState, bIsAdmin ? sPlayerAddr : "Private", sGeoIP);
	}

	return Plugin_Handled;
}

void PrecomputeSortKeys(int[] iPlayers, int iCount, StatusOrderBy eOrderBy, bool bPlayerManager)
{
	s_eSortOrderBy = eOrderBy;

	for (int i = 0; i < iCount; i++)
	{
		int iPlayer = iPlayers[i];
		s_iSortUserIds[i] = GetClientUserId(iPlayer);

		switch (eOrderBy)
		{
			case StatusOrderBy_PlayerName:
				GetClientName(iPlayer, s_sSortNames[i], MAX_NAME_LENGTH);

			case StatusOrderBy_Time:
				s_fSortTimes[i] = IsFakeClient(iPlayer) ? 0.0 : GetClientTime(iPlayer);

			case StatusOrderBy_Ping:
				s_iSortPings[i] = IsFakeClient(iPlayer) ? 9999 : RoundFloat(GetClientLatency(iPlayer, NetFlow_Outgoing) * 1000.0);

			case StatusOrderBy_State:
				s_iSortStates[i] = GetPlayerStateSortRank(iPlayer, bPlayerManager);
		}
	}
}

public int SortPlayers_Comparator(int iElemA, int iElemB, const int[] iArray, Handle hHandle)
{
	switch (s_eSortOrderBy)
	{
		case StatusOrderBy_UserId:
		{
			// Ascending: lowest userid first
			if (s_iSortUserIds[iElemA] < s_iSortUserIds[iElemB])
				return -1;
			if (s_iSortUserIds[iElemA] > s_iSortUserIds[iElemB])
				return 1;
		}
		case StatusOrderBy_PlayerName:
		{
			int iCmp = strcmp(s_sSortNames[iElemA], s_sSortNames[iElemB], false);
			if (iCmp != 0)
				return iCmp; // negative → A comes first (ascending)
		}
		case StatusOrderBy_Time:
		{
			// Descending: longest-connected first
			if (s_fSortTimes[iElemA] > s_fSortTimes[iElemB])
				return -1;
			if (s_fSortTimes[iElemA] < s_fSortTimes[iElemB])
				return  1;
		}
		case StatusOrderBy_Ping:
		{
			// Ascending: lowest ping first
			if (s_iSortPings[iElemA] < s_iSortPings[iElemB])
				return -1;
			if (s_iSortPings[iElemA] > s_iSortPings[iElemB])
				return 1;
		}
		case StatusOrderBy_State:
		{
			// Ascending: active first, then nosteam, then spawning
			if (s_iSortStates[iElemA] < s_iSortStates[iElemB])
				return -1;
			if (s_iSortStates[iElemA] > s_iSortStates[iElemB])
				return 1;
		}
	}
	return 0;
}

void SortPlayers(int[] iPlayers, int iCount, StatusOrderBy eOrderBy, bool bPlayerManager)
{
	if (iCount <= 1)
		return;

	PrecomputeSortKeys(iPlayers, iCount, eOrderBy, bPlayerManager);

	// Build an index array [0 … iCount-1] that we hand to SortCustom1D.
	int iIndices[MAXPLAYERS + 1];
	for (int i = 0; i < iCount; i++)
		iIndices[i] = i;

	SortCustom1D(iIndices, iCount, SortPlayers_Comparator);

	// Apply the permutation into a temp buffer, then copy back.
	int iSorted[MAXPLAYERS + 1];
	for (int i = 0; i < iCount; i++)
		iSorted[i] = iPlayers[iIndices[i]];

	for (int i = 0; i < iCount; i++)
		iPlayers[i] = iSorted[i];
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
