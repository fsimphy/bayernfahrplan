module bayernfahrplan.fahrplanparser.departuredata;

import bayernfahrplan.fahrplanparser.jsonutils : getLine, getDepartureTime, getRealDepartureTime;
import std.json : JSONValue;
import std.datetime : DateTime, Duration;



public struct DepartureData
{

    string line;
    string direction;
    DateTime departure;
    DateTime realtimeDeparture;
    long delay;

    public JSONValue toJson() {
        import std.json : parseJSON;
        import std.format : format;

        // dfmt off
        return format!`{"line":"%1$s","direction":"%2$s","departure":"%3$02d:%4$02d","delay":"%5$s"}`
            (line,
            direction,
            departure.timeOfDay.hour,
            departure.timeOfDay.minute,
            delay).parseJSON;
        //dfmt off
    }
}

DepartureData parseDepartureEntry(JSONValue departureInfo)
{

import bayernfahrplan.fahrplanparser.substitution : substitute;
import std.json;
import std.stdio : writeln;
import std.conv : to;
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

bool isReachable(ref in DepartureData realDeparture, ref in DateTime now, Duration threshold)
{
    return (realDeparture.realtimeDeparture - now) >= threshold;
}