module bayernfahrplan.fahrplanparser.jsonParser;

import core.time : Duration, minutes;
import std.json;
import std.datetime : DateTime, Date, TimeOfDay;
import std.stdio : writeln;
import std.conv : to;
import std.algorithm;

import std.range.interfaces : InputRange;

InputRange!DepartureData parseJsonFahrplan(ref in JSONValue data, Duration reachabilityThreshold = 0.minutes) {
    import std.range : isInputRange, isForwardRange, isRandomAccessRange, inputRangeObject;
    
    import std.algorithm : each, map;
    import std.array;
    import std.range : take;
    import std.stdio : writeln;

    import std.format : format;
    import std.conv : to;

    const currentDateTime = data.parseNow();

    auto reachableDepartures = data["departures"].array
        .map!parseDepartureEntry
        .array
        .sort!((a,b) => a.realtimeDeparture < b.realtimeDeparture)
        .filter!(dp => dp.isReachable(currentDateTime, reachabilityThreshold))
        .inputRangeObject;

    return reachableDepartures;
}

struct DepartureData {
    string line;
    string direction;
    DateTime departure;
    DateTime realtimeDeparture;
    long delay;
}  

DepartureData parseDepartureEntry(JSONValue departureInfo) {
    import bayernfahrplan.fahrplanparser.substitution : substitute;
    import std.conv : to;
    import std.datetime : DateTime;

    try {
        return DepartureData(
            departureInfo.getLine,
            departureInfo["mode"]["destination"].str.substitute,
            departureInfo.getDepartureTime,
            departureInfo.getRealDepartureTime,
            departureInfo["realtime"].integer == 1 ? departureInfo["mode"]["delay"].integer : 0);
    } catch(JSONException ex) {
        import std.stdio : writeln;
        writeln("Error with JSON entry " ~ departureInfo.to!string);
        throw ex;
    }
}

string getLine(ref JSONValue departureInfo) {
    auto lineNumber = departureInfo["mode"]["number"];
    switch(lineNumber.type) with (JSON_TYPE) {
        case STRING:
            return lineNumber.str;
        case INTEGER:
            return lineNumber.integer.to!string;
        default:
            return ""; // TODO: Create UnexpectedJsonType or the like.
    }
}

DateTime getDepartureTime(JSONValue departureInfo) {
    return DateTime(
            departureInfo["dateTime"]["date"].str.parseDefasDate,
            TimeOfDay.fromISOExtString(departureInfo["dateTime"]["time"].str ~ ":00"));
}

DateTime getRealDepartureTime(JSONValue departureInfo) {

    import std.datetime;

    if (departureInfo["realtime"].integer == 1) {
        return DateTime(
            departureInfo["dateTime"]["rtDate"].str.parseDefasDate,
            TimeOfDay.fromISOExtString(departureInfo["dateTime"]["rtTime"].str ~ ":00"));
    } else {
        return departureInfo.getDepartureTime;
    }
}

Date parseDefasDate(string dateString) {
    import std.string;
    import std.algorithm;
    import std.conv;
    import std.array;

    auto components = dateString.split(".").map!(to!int).array;
    return Date(components[2], components[1], components[0]);
}

DateTime parseNow(ref in JSONValue data) {
    auto isoDateTimeString = data["now"].str;
    return DateTime.fromISOExtString(isoDateTimeString);
}

bool isReachable(ref in DepartureData realDeparture, ref in DateTime now, Duration threshold) {
    return (realDeparture.realtimeDeparture - now) >= threshold;
}
