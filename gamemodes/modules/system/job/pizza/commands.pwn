//-----------------------------------------------------------------------------
// Pizza job - commands
//-----------------------------------------------------------------------------

CMD:giaobanh(playerid, params[])
{
    #pragma unused params
    return Pizza_StartDelivery(playerid);
}

CMD:pizza(playerid, params[])
{
    if (!strcmp(params, "quit", true) || !strcmp(params, "stop", true) ||
        !strcmp(params, "nghi", true))
    {
        if (!Pizza_IsOnShift(playerid))
        {
            SendClientMessage(playerid, COLOR_RED, "Ban khong trong ca giao pizza.");
            return 1;
        }

        Pizza_DestroyRentalVehicle(playerid);
        SendClientMessage(playerid, COLOR_WHITE, "Ban da ket thuc ca giao pizza.");
        return 1;
    }

    if (!pJobLoaded[playerid])
    {
        return Pizza_LoadCharacterJob(playerid);
    }

    if (Pizza_IsEmployee(playerid))
    {
        return Pizza_ShowEmployeeMenu(playerid);
    }

    return Pizza_ShowApplication(playerid);
}
