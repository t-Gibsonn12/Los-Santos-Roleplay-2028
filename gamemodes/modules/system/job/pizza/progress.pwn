// Pizza progression uses the existing job_type=1 rows for each character.

#define PIZZA_MAX_LEVEL (5)

new const g_PizzaLevelExperience[PIZZA_MAX_LEVEL + 1] = {0, 0, 150, 400, 800, 1400};

new
    s_PizzaProgressCharacter[MAX_PLAYERS],
    s_PizzaProgressToken[MAX_PLAYERS],
    bool:s_PizzaProgressLoading[MAX_PLAYERS],
    bool:s_PizzaProgressReady[MAX_PLAYERS],
    s_PizzaExperience[MAX_PLAYERS],
    s_PizzaCompletedRuns[MAX_PLAYERS],
    s_PizzaCompletedDeliveries[MAX_PLAYERS],
    s_PizzaCurrentStreak[MAX_PLAYERS],
    s_PizzaBestStreak[MAX_PLAYERS],
    s_PizzaTotalEarnings[MAX_PLAYERS];

stock Pizza_ResetProgress(playerid)
{
    s_PizzaProgressCharacter[playerid] = INVALID_CHARACTER_ID;
    s_PizzaProgressToken[playerid]++;
    s_PizzaProgressLoading[playerid] = false;
    s_PizzaProgressReady[playerid] = false;
    s_PizzaExperience[playerid] = 0;
    s_PizzaCompletedRuns[playerid] = 0;
    s_PizzaCompletedDeliveries[playerid] = 0;
    s_PizzaCurrentStreak[playerid] = 0;
    s_PizzaBestStreak[playerid] = 0;
    s_PizzaTotalEarnings[playerid] = 0;
}

stock Pizza_GetLevel(playerid)
{
    new level = 1;
    while (level < PIZZA_MAX_LEVEL &&
        s_PizzaExperience[playerid] >= g_PizzaLevelExperience[level + 1])
    {
        level++;
    }
    return level;
}

forward OnPizzaProgressLoaded(playerid, characterID, loadToken);

stock Pizza_LoadProgress(playerid)
{
    new const characterID = GetPlayerCharacterID(playerid);
    if (!IsPlayerCharacterLoaded(playerid) || characterID == INVALID_CHARACTER_ID)
    {
        return 0;
    }

    if (s_PizzaProgressCharacter[playerid] != characterID)
    {
        Pizza_ResetProgress(playerid);
        s_PizzaProgressCharacter[playerid] = characterID;
    }

    if (s_PizzaProgressLoading[playerid] || s_PizzaProgressReady[playerid])
    {
        return 1;
    }

    new query[256];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `experience`,`completed_runs`,`completed_tasks`,`best_streak`,`total_earnings` FROM `character_jobs` WHERE `character_id`=%d AND `job_type`=%d;",
        characterID, PIZZA_JOB_ID);
    s_PizzaProgressLoading[playerid] = bool:mysql_tquery(g_DatabaseHandle, query,
        "OnPizzaProgressLoaded", "ddd", playerid, characterID, s_PizzaProgressToken[playerid]);
    return 1;
}

public OnPizzaProgressLoaded(playerid, characterID, loadToken)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerCharacterLoaded(playerid) ||
        GetPlayerCharacterID(playerid) != characterID ||
        s_PizzaProgressCharacter[playerid] != characterID ||
        s_PizzaProgressToken[playerid] != loadToken)
    {
        return 1;
    }

    if (cache_num_rows() > 0)
    {
        cache_get_value_name_int(0, "experience", s_PizzaExperience[playerid]);
        cache_get_value_name_int(0, "completed_runs", s_PizzaCompletedRuns[playerid]);
        cache_get_value_name_int(0, "completed_tasks", s_PizzaCompletedDeliveries[playerid]);
        cache_get_value_name_int(0, "best_streak", s_PizzaBestStreak[playerid]);
        cache_get_value_name_int(0, "total_earnings", s_PizzaTotalEarnings[playerid]);
    }

    s_PizzaProgressLoading[playerid] = false;
    s_PizzaProgressReady[playerid] = true;
    return 1;
}

stock Pizza_Reward(playerid, cash, experience, bool:finishedShift)
{
    GivePlayerMoney(playerid, cash);
    s_CharacterCash[playerid] = GetPlayerMoney(playerid);

    new const characterID = GetPlayerCharacterID(playerid);
    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `player_characters` SET `cash`=%d WHERE `character_id`=%d AND `account_id`=%d;",
        s_CharacterCash[playerid], characterID, GetPlayerAccountID(playerid));
    mysql_tquery(g_DatabaseHandle, query);

    if (!finishedShift)
    {
        s_PizzaCurrentStreak[playerid]++;
    }

    if (s_PizzaProgressReady[playerid] && s_PizzaProgressCharacter[playerid] == characterID)
    {
        new const oldLevel = Pizza_GetLevel(playerid);
        s_PizzaExperience[playerid] += experience;
        s_PizzaCompletedRuns[playerid] += _:finishedShift;
        s_PizzaCompletedDeliveries[playerid] += _:(!finishedShift);
        s_PizzaTotalEarnings[playerid] += cash;
        if (s_PizzaCurrentStreak[playerid] > s_PizzaBestStreak[playerid])
        {
            s_PizzaBestStreak[playerid] = s_PizzaCurrentStreak[playerid];
        }

        new const level = Pizza_GetLevel(playerid);
        if (level > oldLevel)
        {
            new message[96];
            format(message, sizeof(message), "Ban da dat cap %d trong nghe Pizza Boy.", level);
            SendClientMessage(playerid, COLOR_WHITE, message);
        }
    }

    // Persist each delivery even when the history query has not completed.
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `character_jobs` (`character_id`,`job_type`,`experience`,`completed_runs`,`completed_tasks`,`best_streak`,`total_earnings`) VALUES (%d,%d,%d,%d,%d,%d,%d) ON DUPLICATE KEY UPDATE `experience`=`experience`+VALUES(`experience`),`completed_runs`=`completed_runs`+VALUES(`completed_runs`),`completed_tasks`=`completed_tasks`+VALUES(`completed_tasks`),`best_streak`=GREATEST(`best_streak`,VALUES(`best_streak`)),`total_earnings`=`total_earnings`+VALUES(`total_earnings`);",
        characterID, PIZZA_JOB_ID, experience, _:finishedShift, _:(!finishedShift),
        s_PizzaCurrentStreak[playerid], cash);
    mysql_tquery(g_DatabaseHandle, query);

    // A pending read may have selected the previous totals. Refresh after the write.
    if (!s_PizzaProgressReady[playerid] || s_PizzaProgressCharacter[playerid] != characterID)
    {
        s_PizzaProgressLoading[playerid] = false;
        s_PizzaProgressToken[playerid]++;
        Pizza_LoadProgress(playerid);
    }
}
