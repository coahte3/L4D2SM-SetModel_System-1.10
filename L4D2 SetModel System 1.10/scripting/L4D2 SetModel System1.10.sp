// ============================================================================
// L4D2 SetModel System v1.10 (Default Random & Enable Edition)
// by ChatGPT + こあ
// ============================================================================

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.10"

public Plugin myinfo =
{
    name = "L4D2 SetModel System",
    author = "ChatGPT + こあ",
    description = "Character Model System (v1.10 Default Random)",
    version = PLUGIN_VERSION,
    url = ""
};

// クライアントごとのデータ保存用
char g_sJoinModel[MAXPLAYERS + 1][32];
bool g_bJoinEnable[MAXPLAYERS + 1];

// L4D2 公式キャラクター定義
char g_sModels[][] = { "nick", "rochelle", "coach", "ellis", "bill", "zoey", "francis", "louis" };
char g_sPaths[][] =
{
    "models/survivors/survivor_gambler.mdl",
    "models/survivors/survivor_producer.mdl",
    "models/survivors/survivor_coach.mdl",
    "models/survivors/survivor_mechanic.mdl",
    "models/survivors/survivor_namvet.mdl",
    "models/survivors/survivor_teenangst.mdl",
    "models/survivors/survivor_biker.mdl",
    "models/survivors/survivor_manager.mdl"
};

// ============================================================================
// INITIALIZATION
// ============================================================================

public void OnPluginStart()
{
    RegConsoleCmd("sm_model", Cmd_ModelMenu);
    RegConsoleCmd("sm_setmodel", Cmd_SetModel);
    RegConsoleCmd("sm_setmodeljoin", Cmd_SetModelJoin);
    RegConsoleCmd("sm_setmodeljoinon", Cmd_SetModelJoinOn);

    RegAdminCmd("sm_setmodeladmin", Cmd_SetModelAdmin, ADMFLAG_GENERIC);

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
    for (int i = 0; i < 8; i++)
    {
        if (!IsModelPrecached(g_sPaths[i]))
        {
            PrecacheModel(g_sPaths[i], true);
        }
    }
}

// ============================================================================
// DATA SAVE & LOAD ENGINE (KeyValues)
// ============================================================================

void SaveClientData(int client)
{
    if (client == 0 || IsFakeClient(client)) return;

    char auth[64];
    if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), false)) return;

    KeyValues kv = new KeyValues("SetModelSaves");
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/setmodel_saves.txt");

    kv.ImportFromFile(path);
    kv.JumpToKey(auth, true);
    kv.SetString("model", g_sJoinModel[client]);
    kv.SetNum("enable", g_bJoinEnable[client] ? 1 : 0);
    kv.Rewind();
    kv.ExportToFile(path);
    delete kv;
}

void LoadClientData(int client)
{
    if (client == 0 || IsFakeClient(client)) return;

    char auth[64];
    if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), false)) return;

    KeyValues kv = new KeyValues("SetModelSaves");
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/setmodel_saves.txt");

    kv.ImportFromFile(path);
    if (kv.JumpToKey(auth, false))
    {
        kv.GetString("model", g_sJoinModel[client], sizeof(g_sJoinModel[]), "random");
        g_bJoinEnable[client] = (kv.GetNum("enable", 1) == 1);
    }
    else
    {
        // 新規プレイヤーの初期値を「random / Enable」に設定
        strcopy(g_sJoinModel[client], sizeof(g_sJoinModel[]), "random");
        g_bJoinEnable[client] = true;
    }
    delete kv;
}

public void OnClientPutInServer(int client)
{
    LoadClientData(client);
}

// ============================================================================
// SPAWN HOOK TIMING
// ============================================================================

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (client == 0 || !IsClientInGame(client) || IsFakeClient(client)) return;

    if (GetClientTeam(client) == 2 && g_bJoinEnable[client])
    {
        CreateTimer(1.0, Timer_ApplyJoinModel, userid);
    }
}

public Action Timer_ApplyJoinModel(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2) return Plugin_Stop;

    if (strlen(g_sJoinModel[client]) <= 0) return Plugin_Stop;

    // 設定が "random" の場合は、0~7の番号を毎回ランダム抽選して適用
    if (StrEqual(g_sJoinModel[client], "random", false))
    {
        int randIdx = GetRandomInt(0, 7);
        ApplyModel(client, g_sModels[randIdx]);
    }
    else
    {
        ApplyModel(client, g_sJoinModel[client]);
    }
    return Plugin_Stop;
}

// ============================================================================
// CORE MODEL LOGIC
// ============================================================================

bool ApplyModel(int client, const char[] modelname)
{
    if (client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2) return false;

    int targetIdx = -1;
    for (int i = 0; i < 8; i++)
    {
        if (StrEqual(modelname, g_sModels[i], false))
        {
            targetIdx = i;
            break;
        }
    }

    if (targetIdx == -1) return false;

    SetEntityModel(client, g_sPaths[targetIdx]);
    SetEntProp(client, Prop_Send, "m_survivorCharacter", targetIdx);
    return true;
}

// ============================================================================
// SYSTEM MENUS (v1.10 Multi-Layer System)
// ============================================================================

void OpenMainMenu(int client)
{
    if (client == 0 || !IsClientInGame(client)) return;

    Menu menu = new Menu(Handler_MainMenu);
    menu.SetTitle("◆ L4D2 SetModel System v1.10");

    menu.AddItem("setmodel", "SetModel");

    char buffer[64];
    Format(buffer, sizeof(buffer), "JoinModel: %s", g_sJoinModel[client]);
    menu.AddItem("joinmodel", buffer);

    Format(buffer, sizeof(buffer), "JoinModel: %s", g_bJoinEnable[client] ? "Enable" : "Disable");
    menu.AddItem("joinon", buffer);

    if (CheckCommandAccess(client, "setmodel_admin", ADMFLAG_GENERIC))
    {
        menu.AddItem("adminmenu", "AdminSetModel");
    }

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_MainMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "setmodel"))
        {
            OpenSurvivorSelectMenu(param1, false);
        }
        else if (StrEqual(info, "joinmodel"))
        {
            OpenSurvivorSelectMenu(param1, true);
        }
        else if (StrEqual(info, "joinon"))
        {
            g_bJoinEnable[param1] = !g_bJoinEnable[param1];
            SaveClientData(param1);
            OpenMainMenu(param1);
        }
        else if (StrEqual(info, "adminmenu"))
        {
            OpenAdminMainMenu(param1);
        }
    }
    else if (action == MenuAction_End) delete menu;
    return 0;
}

void OpenSurvivorSelectMenu(int client, bool isJoinSetting)
{
    Menu menu = new Menu(isJoinSetting ? Handler_JoinModelSelect : Handler_ImmediateModelSelect);
    menu.SetTitle(isJoinSetting ? "> Select Join Character" : "> Select Character");

    if (isJoinSetting)
    {
        menu.AddItem("random", "random");
    }

    for (int i = 0; i < 8; i++)
    {
        char info[32], disp[32];
        strcopy(info, sizeof(info), g_sModels[i]);
        Format(disp, sizeof(disp), "%s", g_sModels[i]);
        menu.AddItem(info, disp);
    }

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_ImmediateModelSelect(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        ApplyModel(param1, info);
        PrintToChat(param1, "\x01[\x04Model\x01] Changed to: \x05%s", info);
        OpenMainMenu(param1);
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack) OpenMainMenu(param1);
    }
    else if (action == MenuAction_End) delete menu;
    return 0;
}

public int Handler_JoinModelSelect(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        strcopy(g_sJoinModel[param1], sizeof(g_sJoinModel[]), info);
        SaveClientData(param1);
        PrintToChat(param1, "\x01[\x04Model\x01] Join Model Set: \x05%s", info);
        OpenMainMenu(param1);
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack) OpenMainMenu(param1);
    }
    else if (action == MenuAction_End) delete menu;
    return 0;
}

// ============================================================================
// ADMIN MENUS
// ============================================================================

void OpenAdminMainMenu(int client)
{
    Menu menu = new Menu(Handler_AdminMainMenu);
    menu.SetTitle("== Admin SetModel Menu ==");

    menu.AddItem("all_survivors", "AllSurvivor");
    menu.AddItem("all_bots", "AllBot");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2)
        {
            char name[MAX_NAME_LENGTH], info[64], disp[64];
            GetClientName(i, name, sizeof(name));
            Format(info, sizeof(info), "target_%d", GetClientUserId(i));
            Format(disp, sizeof(disp), "%s%s", name, IsFakeClient(i) ? " (Bot)" : "");
            menu.AddItem(info, disp);
        }
    }

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

char g_sAdminTarget[MAXPLAYERS + 1][64];
// 管理者が選択したターゲットを一時記憶

public int Handler_AdminMainMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[64];
        menu.GetItem(param2, info, sizeof(info));

        strcopy(g_sAdminTarget[param1], 64, info);
        OpenAdminCharacterSelect(param1);
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack) OpenMainMenu(param1);
    }
    else if (action == MenuAction_End) delete menu;
    return 0;
}

void OpenAdminCharacterSelect(int client)
{
    Menu menu = new Menu(Handler_AdminCharacterSelect);
    menu.SetTitle("> Select Model for Target");

    for (int i = 0; i < 8; i++)
    {
        char disp[32];
        Format(disp, sizeof(disp), "%s", g_sModels[i]);
        menu.AddItem(g_sModels[i], disp);
    }

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_AdminCharacterSelect(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char model[32];
        menu.GetItem(param2, model, sizeof(model));
        char targetInfo[64];
        strcopy(targetInfo, sizeof(targetInfo), g_sAdminTarget[param1]);

        if (StrEqual(targetInfo, "all_survivors"))
        {
            for (int i = 1; i <= MaxClients; i++)
                if (IsClientInGame(i) && GetClientTeam(i) == 2) ApplyModel(i, model);
            PrintToChat(param1, "\x01[\x04Admin\x01] Changed \x05All Survivors \x01to \x04%s", model);
        }
        else if (StrEqual(targetInfo, "all_bots"))
        {
            for (int i = 1; i <= MaxClients; i++)
                if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i)) ApplyModel(i, model);
            PrintToChat(param1, "\x01[\x04Admin\x01] Changed \x05All Bots \x01to \x04%s", model);
        }
        else if (StrContains(targetInfo, "target_") == 0)
        {
            int userid = StringToInt(targetInfo[7]);
            // "target_" (7文字) をスキップして数値化
            int targetClient = GetClientOfUserId(userid);

            if (targetClient > 0 && IsClientInGame(targetClient) && GetClientTeam(targetClient) == 2)
            {
                ApplyModel(targetClient, model);
                char name[MAX_NAME_LENGTH];
                GetClientName(targetClient, name, sizeof(name));
                PrintToChat(param1, "\x01[\x04Admin\x01] Changed \x05%s \x01to \x04%s", name, model);
            }
            else
            {
                PrintToChat(param1, "\x01[\x04Admin\x01] Target is no longer valid or not a Survivor.");
            }
        }
        OpenAdminMainMenu(param1);
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack) OpenAdminMainMenu(param1);
    }
    else if (action == MenuAction_End) delete menu;
    return 0;
}

// ============================================================================
// CONSOLE COMMANDS LOGIC
// ============================================================================

public Action Cmd_ModelMenu(int client, int args)
{
    if (client > 0) OpenMainMenu(client);
    return Plugin_Handled;
}

public Action Cmd_SetModel(int client, int args)
{
    if (client == 0) return Plugin_Handled;

    if (args < 1)
    {
        ReplyToCommand(client, "[Model] Usage: !setmodel <SurvivorName>");
        return Plugin_Handled;
    }
    char model[32];
    GetCmdArg(1, model, sizeof(model));
    if (ApplyModel(client, model)) ReplyToCommand(client, "[Model] Changed to: %s", model);
    else ReplyToCommand(client, "[Model] Invalid character name.");
    return Plugin_Handled;
}

public Action Cmd_SetModelJoin(int client, int args)
{
    if (client == 0) return Plugin_Handled;

    if (args < 1)
    {
        ReplyToCommand(client, "[Model] Current Join Model: %s", g_sJoinModel[client]);
        return Plugin_Handled;
    }
    GetCmdArg(1, g_sJoinModel[client], sizeof(g_sJoinModel[]));
    SaveClientData(client);
    ReplyToCommand(client, "[Model] Join Model Set: %s", g_sJoinModel[client]);
    return Plugin_Handled;
}

public Action Cmd_SetModelJoinOn(int client, int args)
{
    if (client == 0) return Plugin_Handled;

    if (args < 1)
    {
        ReplyToCommand(client, "[Model] Join Enable State: %s", g_bJoinEnable[client] ? "Enable" : "Disable");
        return Plugin_Handled;
    }
    char arg[16];
    GetCmdArg(1, arg, sizeof(arg));

    if (StrEqual(arg, "1") || StrEqual(arg, "enable", false)) g_bJoinEnable[client] = true;
    else if (StrEqual(arg, "0") || StrEqual(arg, "disable", false)) g_bJoinEnable[client] = false;
    else
    {
        ReplyToCommand(client, "[Model] Invalid argument. Use 1/0/enable/disable.");
        return Plugin_Handled;
    }
    SaveClientData(client);
    ReplyToCommand(client, "[Model] Join Apply Set to: %s", g_bJoinEnable[client] ? "Enable" : "Disable");
    return Plugin_Handled;
}

public Action Cmd_SetModelAdmin(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Model] Usage: !setmodeladmin <Target> <SurvivorName>");
        return Plugin_Handled;
    }

    char targetStr[64], model[32];
    GetCmdArg(1, targetStr, sizeof(targetStr));
    GetCmdArg(2, model, sizeof(model));

    int directIdx = StringToInt(targetStr);
    if (directIdx >= 1 && directIdx <= MaxClients)
    {
        if (IsClientInGame(directIdx) && GetClientTeam(directIdx) == 2)
        {
            ApplyModel(directIdx, model);
            ReplyToCommand(client, "[Model] Applied model '%s' to client index %d.", model, directIdx);
        }
        return Plugin_Handled;
    }

    if (StrEqual(targetStr, "all", false) || StrEqual(targetStr, "survivor", false))
    {
        for (int i = 1; i <= MaxClients; i++)
            if (IsClientInGame(i) && GetClientTeam(i) == 2) ApplyModel(i, model);
        ReplyToCommand(client, "[Model] Applied model '%s' to All Survivors.", model);
    }
    else if (StrEqual(targetStr, "bot", false) || StrEqual(targetStr, "bots", false))
    {
        for (int i = 1; i <= MaxClients; i++)
            if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i)) ApplyModel(i, model);
        ReplyToCommand(client, "[Model] Applied model '%s' to All Bots.", model);
    }
    else if (StrEqual(targetStr, "me", false) || StrEqual(targetStr, "@me", false))
    {
        if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2)
        {
            ApplyModel(client, model);
            ReplyToCommand(client, "[Model] Applied model '%s' to yourself.", model);
        }
    }
    else
    {
        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS], target_count;
        bool tn_is_ml;

        if ((target_count = ProcessTargetString(targetStr, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
        {
            ReplyToTargetError(client, target_count);
            return Plugin_Handled;
        }

        for (int i = 0; i < target_count; i++)
        {
            if (GetClientTeam(target_list[i]) == 2) ApplyModel(target_list[i], model);
        }
        ReplyToCommand(client, "[Model] Applied model '%s' to target: %s", model, target_name);
    }
    return Plugin_Handled;
}