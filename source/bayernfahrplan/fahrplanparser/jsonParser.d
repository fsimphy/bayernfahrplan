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
import bayernfahrplan.fahrplanparser.departuredata : DepartureData, parseDepartureEntry, isReachable;
import bayernfahrplan.fahrplanparser.jsonutils : parseNow;

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




