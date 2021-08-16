#if defined _serverfps_included
  #endinput
#endif
#define _serverfps_included

#include <sourcemod>
#include <sdktools>

stock float GetServerFPS()
{
	return 1.0 / view_as<float>(LoadFromAddress(GetHostTimeFrame(), NumberType_Int32));
}

/*
* Internal Functions
*/
stock Handle GetServerFPSConf()
{
	static Handle hGameConf = null;

	if (hGameConf == null)
	{
		hGameConf = LoadGameConfigFile("serverfps.games");

		if (hGameConf == null)
		{
			SetFailState("Couldn't find \"serverfps.games\" configuration file");
		}
	}

	return hGameConf;
}

stock Address GetHostTimeFrame()
{
	static Address pHostTimeFrame = Address_Null;

	if (pHostTimeFrame == Address_Null)
	{
		pHostTimeFrame = GameConfGetAddress(GetServerFPSConf(), "HostTimeFrame");

		if (pHostTimeFrame == Address_Null)
		{
			SetFailState("Failed to find time frame address");
		}
	}

	return pHostTimeFrame;
}