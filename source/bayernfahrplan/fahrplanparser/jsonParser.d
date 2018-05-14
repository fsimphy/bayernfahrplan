module bayernfahrplan.fahrplanparser.jsonParser;

// TODO: cleanup

import core.time : Duration, minutes;
import std.algorithm.iteration : map, each, filter;
import std.algorithm.sorting : sort;
import std.array;
import std.conv : to;
import std.datetime : DateTime, Date, TimeOfDay;
import std.format : format;
import std.json;
import std.range : take;
import std.range.interfaces : InputRange, inputRangeObject;
import std.range.primitives : isInputRange, isForwardRange, isRandomAccessRange;
import std.stdio : writeln;
import bayernfahrplan.fahrplanparser.substitution : substitute;

InputRange!DepartureData parseJsonFahrplan(ref in JSONValue data,
        Duration reachabilityThreshold = 0.minutes)
{

    const currentDateTime = data.parseNow();

    // dfmt off
    auto reachableDepartures = data["departures"].array
        .map!parseDepartureEntry
        .array
        .sort!((a, b) => a.realtimeDeparture < b.realtimeDeparture)
        .filter!(dp => dp.isReachable(currentDateTime, reachabilityThreshold))
        .inputRangeObject;
    // dfmt on

    return reachableDepartures;
}

struct DepartureData
{
    string line;
    string direction;
    DateTime departure;
    DateTime realtimeDeparture;
    long delay;
}

DepartureData parseDepartureEntry(JSONValue departureInfo)
{

    try
    {
        // dfmt off
        return DepartureData(departureInfo.getLine,
                departureInfo["mode"]["destination"].str.substitute,
                departureInfo.getDepartureTime,
                departureInfo.getRealDepartureTime,
                departureInfo["realtime"].integer == 1 ? departureInfo["mode"]["delay"].integer : 0);
        // dfmt on
    }
    catch (JSONException ex)
    {
        writeln("Error with JSON entry " ~ departureInfo.to!string);
        throw ex;
    }
}

string getLine(ref JSONValue departureInfo)
{
    auto lineNumber = departureInfo["mode"]["number"];
    switch (lineNumber.type) with (JSON_TYPE)
    {
    case STRING:
        return lineNumber.str;
    case INTEGER:
        return lineNumber.integer.to!string;
    default:
        return ""; // TODO: Create UnexpectedJsonType or the like.
    }
}

DateTime getDepartureTime(JSONValue departureInfo)
{
    return DateTime(
        departureInfo["dateTime"]["date"].str.parseDefasDate,
        TimeOfDay.fromISOExtString(departureInfo["dateTime"]["time"].str ~ ":00")
    );
}

DateTime getRealDepartureTime(JSONValue departureInfo)
{

    if (departureInfo["realtime"].integer == 1)
    {
        // TODO: Extract
        return DateTime(departureInfo["dateTime"]["rtDate"].str.parseDefasDate,
                TimeOfDay.fromISOExtString(departureInfo["dateTime"]["rtTime"].str ~ ":00"));
    }
    else
    {
        return departureInfo.getDepartureTime;
    }
}

Date parseDefasDate(string dateString)
{
    auto components = dateString.split(".").map!(to!int).array;
    return Date(components[2], components[1], components[0]);
}

DateTime parseNow(ref in JSONValue data)
{
    auto isoDateTimeString = data["now"].str;
    return DateTime.fromISOExtString(isoDateTimeString);
}

bool isReachable(ref in DepartureData realDeparture, ref in DateTime now, Duration threshold)
{
    return (realDeparture.realtimeDeparture - now) >= threshold;
}
