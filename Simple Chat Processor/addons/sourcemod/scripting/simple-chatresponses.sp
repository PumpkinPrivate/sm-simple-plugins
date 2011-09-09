/************************************************************************
*************************************************************************
Simple Chat Responses
Description:
		Provides automatic respondes based on a players chat message
*************************************************************************
*************************************************************************
This file is part of Simple Plugins project.

This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id$
$Author$
$Revision$
$Date$
$LastChangedBy$
$LastChangedDate$
$URL$
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************
*/

#include <sourcemod>
#include <sdktools>
#include <scp>
#include <smlib>

#define PLUGIN_VERSION			"0.1.$Rev$"

#define ADDKEY(%1,%2,%3) SetTrieString(g_aResponseHandles[%1], %2, %3)

#define RESPONSE_MAX				50
#define RESPONSE_INVLAID 	-1
#define CVAR_DISABLED 			"OFF"
#define CVAR_ENABLED  			"ON"

new Handle:g_aPhrases = INVALID_HANDLE;
new Handle:g_aResponseHandles[RESPONSE_MAX] = { INVALID_HANDLE, ... };
new aIndex = 0;

public Plugin:myinfo =
{
	name = "Simple Chat Responses",
	author = "Simple Plugins",
	description = "Provides automatic respondes based on a players chat message.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

public OnPluginStart()
{
	CreateConVar("scr_version", PLUGIN_VERSION, "Simple Chat Responses", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegAdminCmd("sm_reloadscr", Command_Reload, ADMFLAG_CONFIG,  "Reloads settings from the config file");
	g_aPhrases = CreateArray(MAXLENGTH_INPUT, 1);
	
	ProcessConfigFile("configs/simple-chatresponses.cfg");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "scp"))
	{
		SetFailState("Simple Chat Processor Unloaded.  Plugin Disabled.");
	}
}

public Action:Command_Reload(client, args)
{
	ProcessConfigFile("configs/simple-chatresponses.cfg");
	LogAction(client, 0, "[SCP] Config file has been reloaded");
	ReplyToCommand(client, "[SCP] Config file has been reloaded");
	return Plugin_Handled;
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	new userid = GetClientUserId(author);
	new ResponseIndex = RESPONSE_INVLAID;
	
	decl String:sMessageBuffer[MAXLENGTH_INPUT];
	Color_StripFromChatText(message, sMessageBuffer, MAXLENGTH_INPUT);
	TrimString(sMessageBuffer);
	
	new index = 1;
	while (g_aResponseHandles[index] != INVALID_HANDLE)
	{
		decl String:sMatchBuffer[32];
		GetTrieString(g_aResponseHandles[index], "match", sMatchBuffer, sizeof(sMatchBuffer));
		if (StrEqual("exact", sMatchBuffer))
		{
			decl String:sPhraseBuffer[MAXLENGTH_INPUT];
			GetArrayString(g_aPhrases, index, sPhraseBuffer, sizeof(sPhraseBuffer));
			if (StrEqual(sMessageBuffer, sPhraseBuffer, false))
			{
				ResponseIndex= index;
				break;
			}
		}
		index++;
	}
	
	if (ResponseIndex == RESPONSE_INVLAID)
	{
		index = 0;
		while (g_aResponseHandles[index] != INVALID_HANDLE)
		{
			decl String:sMatchBuffer[32];
			GetTrieString(g_aResponseHandles[index], "match", sMatchBuffer, sizeof(sMatchBuffer));
			if (StrEqual("contains", sMatchBuffer))
			{
				decl String:sPhraseBuffer[MAXLENGTH_INPUT];
				GetArrayString(g_aPhrases, index, sPhraseBuffer, sizeof(sPhraseBuffer));
				if (StrContains(sMessageBuffer, sPhraseBuffer) != -1)
				{
					ResponseIndex = index;
					break;
				}
			}
			index++;
		}
	}
	
	if (ResponseIndex != RESPONSE_INVLAID)
	{
		new Handle:hPack;
		new numClients = GetArraySize(recipients);
		CreateDataTimer(0.2, Timer_ChatResponse, hPack, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(hPack, userid);
		WritePackCell(hPack, ResponseIndex);
		WritePackCell(hPack, numClients);
		for (new i = 0; i < numClients; i++)
		{
			new x = GetArrayCell(recipients, i);
			WritePackCell(hPack, x);
		}
	}
	return Plugin_Continue;
}

public Action:Timer_ChatResponse(Handle:timer, any:pack)
{
	ResetPack(pack);
	new client	= GetClientOfUserId(ReadPackCell(pack));
	if (client == 0)
	{
		return Plugin_Stop;
	}
	
	new ResponseIndex = ReadPackCell(pack);
	new numClients = ReadPackCell(pack);
	new clients[numClients];
	
	for (new i = 0; i < numClients; i++)
	{
		clients[i] = ReadPackCell(pack);
	}
	
	decl String:sResponse[MAXLENGTH_INPUT], String:sType[16];
	GetTrieString(g_aResponseHandles[ResponseIndex], "type", sType, sizeof(sType));
	
	if (IsStringBlank(sType) || StrEqual(sType, "static"))
	{
		GetTrieString(g_aResponseHandles[ResponseIndex], "text", sResponse, sizeof(sResponse));
	}
	else if (StrEqual(sType, "random"))
	{
		decl String:sKey[16];
		new tCount;
		
		GetTrieValue(g_aResponseHandles[ResponseIndex], "tcount", tCount);
		new random = Math_GetRandomInt(1, tCount);
		
		Format(sKey, sizeof(sKey), "text%i", random);
		
		GetTrieString(g_aResponseHandles[ResponseIndex], sKey, sResponse, sizeof(sResponse));
	}
	else if (StrEqual(sType, "linear"))
	{
		decl String:sKey[16];
		new tCount, tIndex;
		
		GetTrieValue(g_aResponseHandles[ResponseIndex], "tcount", tCount);
		GetTrieValue(g_aResponseHandles[ResponseIndex], "tindex", tIndex);
		Format(sKey, sizeof(sKey), "text%i", tIndex);
		GetTrieString(g_aResponseHandles[ResponseIndex], sKey, sResponse, sizeof(sResponse));
		
		tIndex++;
		if (tIndex > tCount)
		{
			tIndex = 1;
		}
		SetTrieValue(g_aResponseHandles[ResponseIndex], "tindex", tIndex);
	}
	
	ReplaceTags(client, sResponse, sizeof(sResponse));
	
	Color_ChatSetSubject(client);
	for (new i = 0; i < numClients; i++)
	{
		if (Client_IsValid(clients[i]))
		{
			Client_PrintToChat(clients[i], true, sResponse);
		}
	}
	Color_ChatClearSubject();
	
	return Plugin_Stop;
}

stock ProcessConfigFile(const String:file[])
{
	new String:sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), file);
	if (!FileExists(sConfigFile)) 
	{
		LogError("[SCR] Simple Chat Responses is not running! Could not find file %s", sConfigFile);
		SetFailState("Could not find file %s", sConfigFile);
	}
	else if (!ParseConfigFile(sConfigFile))
	{
		LogError("[SCR] Simple Chat Responses is not running! Failed to parse %s", sConfigFile);
		SetFailState("Parse error on file %s", sConfigFile);
	}
}

bool:ParseConfigFile(const String:file[]) 
{
	
	for (new i = 0; i < RESPONSE_MAX; i++)
	{
		if (g_aResponseHandles[i] != INVALID_HANDLE)
		{
			CloseHandle(g_aResponseHandles[i])
			g_aResponseHandles[i] = INVALID_HANDLE;
		}
	}
	
	new Handle:hParser = SMC_CreateParser();
	new String:error[128];
	new line = 0;
	new col = 0;
	
	SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(hParser, Config_End);
	
	new SMCError:result = SMC_ParseFile(hParser, file, line, col);
	CloseHandle(hParser);

	if (result != SMCError_Okay) 
	{
		SMC_GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, file);
	}
	
	return (result == SMCError_Okay);
}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) 
{
	if (StrEqual(section, "auto_responses"))
	{
		return SMCParse_Continue;
	}
	aIndex = PushArrayString(g_aPhrases, section);
	g_aResponseHandles[aIndex] = CreateTrie();
	return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	ADDKEY(aIndex, key, value);
	if (StrContains(key, "text") != -1)
	{
		new tCount;
		GetTrieValue(g_aResponseHandles[aIndex], "tcount", tCount);
		SetTrieValue(g_aResponseHandles[aIndex], "tcount", ++tCount);
		SetTrieValue(g_aResponseHandles[aIndex], "tindex", 1);
	}
	return SMCParse_Continue;
}

public SMCResult:Config_EndSection(Handle:parser) 
{
	return SMCParse_Continue;
}

public Config_End(Handle:parser, bool:halted, bool:failed) 
{
	//nothing
}

stock bool:IsStringBlank(const String:input[])
{
	new len = strlen(input);
	for (new i=0; i<len; i++)
	{
		if (!IsCharSpace(input[i]))
		{
			return false;
		}
	}
	return true;
}

/**
Thanks to DJ Tsunami for the great code below
I basically just made a function from his advertisements plugin replacement features
http://forums.alliedmods.net/showthread.php?t=155705

Explination of fuction is a quote from this thread...

This [function] supports the following variables: {CURRENTMAP}, {DATE}, {TICKRATE}, {TIME}, {TIME24} and {TIMELEFT}.
Next to that you can print the value of a cvar by enclosing the name with {}. For example you can use {SM_NEXTMAP} to show the name of the next map. 
Last but not least, for a boolean cvar you might want to have it print OFF/ON instead of 0/1. For that you can use {BOOL:name}. 
For example {BOOL:MP_FRIENDLYFIRE} will print OFF if mp_friendlyfire is set to 0, and ON if it's set to 1. 
If you want it to print something other than OFF/ON, you will have to open the source code, change the defines at the top and recompile.
*/
stock ReplaceTags(const client, String:text[], const maxlength)
{
	decl String:sBuffer[128];
	
	if (StrContains(text, "{NAME}") != -1)
	{
		GetClientName(client, sBuffer, sizeof(sBuffer));
		ReplaceString(text, maxlength, "{NAME}", sBuffer);
	}
	
	if (StrContains(text, "{CURRENTMAP}") != -1)
	{
		GetCurrentMap(sBuffer, sizeof(sBuffer));
		ReplaceString(text, maxlength, "{CURRENTMAP}", sBuffer);
	}
	
	if (StrContains(text, "{DATE}") != -1) 
	{
		FormatTime(sBuffer, sizeof(sBuffer), "%m/%d/%Y");
		ReplaceString(text, maxlength, "{DATE}", sBuffer);
	}
	
	if (StrContains(text, "{TIME}") != -1) 
	{
		FormatTime(sBuffer, sizeof(sBuffer), "%I:%M:%S%p");
		ReplaceString(text, maxlength, "{TIME}", sBuffer);
	}
	
	if (StrContains(text, "{TIME24}") != -1) 
	{
		FormatTime(sBuffer, sizeof(sBuffer), "%H:%M:%S");
		ReplaceString(text, maxlength, "{TIME24}",     sBuffer);
	}
	
	if (StrContains(text, "{TIMELEFT}") != -1) 
	{
		new iMins, iSecs, iTimeLeft;
		if (GetMapTimeLeft(iTimeLeft) && iTimeLeft > 0) 
		{
			iMins = iTimeLeft / 60;
			iSecs = iTimeLeft % 60;
		}
		Format(sBuffer, sizeof(sBuffer), "%d:%02d", iMins, iSecs);
		ReplaceString(text, maxlength, "{TIMELEFT}",   sBuffer);
	}
	
	new iStart = StrContains(text, "{BOOL:");
	while (iStart != -1) 
	{
		new iEnd = StrContains(text[iStart + 6], "}");
		if (iEnd != -1) 
		{
			decl String:sConVar[64], String:sName[64];
			strcopy(sConVar, iEnd + 1, text[iStart + 6]);
			Format(sName, sizeof(sName), "{BOOL:%s}", sConVar);
			new Handle:hConVar = FindConVar(sConVar);
			if (hConVar != INVALID_HANDLE) 
			{
				ReplaceString(text, maxlength, sName, GetConVarBool(hConVar) ? CVAR_ENABLED : CVAR_DISABLED);
			}
		}
		
		new iStart2 = StrContains(text[iStart + 1], "{BOOL:") + iStart + 1;
		if (iStart == iStart2) 
		{
			break;
		} 
		else 
		{
			iStart = iStart2;
		}
	}
	
	iStart = StrContains(text, "{");
	while (iStart != -1) 
	{
		new iEnd = StrContains(text[iStart + 1], "}");
		
		if (iEnd != -1) 
		{
			decl String:sConVar[64], String:sName[64];
			
			strcopy(sConVar, iEnd + 1, text[iStart + 1]);
			Format(sName, sizeof(sName), "{%s}", sConVar);
			
			new Handle:hConVar = FindConVar(sConVar);
			if (hConVar != INVALID_HANDLE) 
			{
				GetConVarString(hConVar, sBuffer, sizeof(sBuffer));
				ReplaceString(text, maxlength, sName, sBuffer);
			}
		}
		
		new iStart2 = StrContains(text[iStart + 1], "{") + iStart + 1;
		if (iStart == iStart2) 
		{
			break;
		} 
		else 
		{
			iStart = iStart2;
		}
	}
}