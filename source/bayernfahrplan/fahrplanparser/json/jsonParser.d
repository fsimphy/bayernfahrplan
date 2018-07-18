module bayernfahrplan.fahrplanparser.json.jsonparser;

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

//dfmt off
import bayernfahrplan.fahrplanparser.data.departuredata : DepartureData;
import bayernfahrplan.fahrplanparser.data.fieldnames : Fields;
//dfmt on
import bayernfahrplan.fahrplanparser.json.jsonutils : parseNow, getIfKeyExists;
import fluent.asserts : should;

InputRange!DepartureData parseJsonFahrplan(ref in JSONValue data,
        const Duration reachabilityThreshold = 0.minutes)
{
    const currentDateTime = data.parseNow();
    // dfmt off
    return data.getIfKeyExists(Fields.departures)
        .array
        .map!parseJsonDepartureEntry
        .filter!(dp => dp.isReachable(currentDateTime, reachabilityThreshold))
        .array
        .sort!((a, b) => a.realtimeDeparture < b.realtimeDeparture)
        .inputRangeObject;
    // dfmt on
}

@system
{
    unittest
    {
        import bayernfahrplan.fahrplanparser.data.exceptions : NoSuchKeyException;

        const jsonData = `{"foo": "bar"}`.parseJSON;
        jsonData.parseJsonFahrplan.should.throwException!NoSuchKeyException.msg.should.contain(
                Fields.currentDateTime);
    }

    unittest
    {
        import std.algorithm.searching : count;

        auto jsonData = JSONValue();
        jsonData[Fields.departures] = JSONValue([[Fields.realtime : 1]]);

        jsonData[Fields.departures][0][Fields.realtime] = 1;

        jsonData[Fields.departures][0][Fields.lineInformation] = JSONValue();

        jsonData[Fields.departures][0][Fields.lineInformation][Fields.lineNumber] = "1A";
        jsonData[Fields.departures][0][Fields.lineInformation][Fields.destination] = "Endstation";
        jsonData[Fields.departures][0][Fields.lineInformation][Fields.delay] = 11;

        jsonData[Fields.departures][0][Fields.dateTimes] = JSONValue();
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.date] = 2018_01_01;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.time] = 1;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.realtimeDate] = 2018_01_01;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.realtimeTime] = 11;

        jsonData[Fields.currentDateTime] = "2018-01-01T00:00:00";

        jsonData.parseJsonFahrplan().count.should.equal(1);
    }

    unittest
    {
        import std.algorithm.searching : count;

        auto jsonData = JSONValue();
        jsonData[Fields.departures] = JSONValue([[Fields.realtime : 1]]);

        jsonData[Fields.departures][0][Fields.realtime] = 1;

        jsonData[Fields.departures][0][Fields.lineInformation] = JSONValue();

        jsonData[Fields.departures][0][Fields.lineInformation][Fields.lineNumber] = "1A";
        jsonData[Fields.departures][0][Fields.lineInformation][Fields.destination] = "Endstation";
        jsonData[Fields.departures][0][Fields.lineInformation][Fields.delay] = 15;

        jsonData[Fields.departures][0][Fields.dateTimes] = JSONValue();
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.date] = 2018_01_01;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.time] = 1;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.realtimeDate] = 2018_01_01;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.realtimeTime] = 11;

        jsonData[Fields.currentDateTime] = "2018-01-01T00:00:00";

        jsonData.parseJsonFahrplan(15.minutes).count.should.equal(0);
    }

    unittest
    {
        import std.algorithm.searching : count;
        import std.algorithm.sorting : isSorted;

        auto jsonData = JSONValue();
        jsonData[Fields.departures] = JSONValue([[Fields.realtime : 1], [Fields.realtime : 0], [Fields.realtime : 1]]);

        jsonData[Fields.departures][0][Fields.realtime] = 1;

        jsonData[Fields.departures][0][Fields.lineInformation] = JSONValue();

        jsonData[Fields.departures][0][Fields.lineInformation][Fields.lineNumber] = "1A";
        jsonData[Fields.departures][0][Fields.lineInformation][Fields.destination] = "Endstation";
        jsonData[Fields.departures][0][Fields.lineInformation][Fields.delay] = 19;

        jsonData[Fields.departures][0][Fields.dateTimes] = JSONValue();
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.date] = 2018_01_01;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.time] = 1;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.realtimeDate] = 2018_01_01;
        jsonData[Fields.departures][0][Fields.dateTimes][Fields.realtimeTime] = 20;

        jsonData[Fields.departures][1][Fields.lineInformation] = JSONValue();

        jsonData[Fields.departures][1][Fields.lineInformation][Fields.lineNumber] = "2A";
        jsonData[Fields.departures][1][Fields.lineInformation][Fields.destination] = "Endstation2";
        jsonData[Fields.departures][1][Fields.lineInformation][Fields.delay] = 0;

        jsonData[Fields.departures][1][Fields.dateTimes] = JSONValue();
        jsonData[Fields.departures][1][Fields.dateTimes][Fields.date] = 2018_01_01;
        jsonData[Fields.departures][1][Fields.dateTimes][Fields.time] = 1;

        jsonData[Fields.departures][2][Fields.lineInformation] = JSONValue();

        jsonData[Fields.departures][2][Fields.lineInformation][Fields.lineNumber] = "1A";
        jsonData[Fields.departures][2][Fields.lineInformation][Fields.destination] = "Endstation";
        jsonData[Fields.departures][2][Fields.lineInformation][Fields.delay] = 3;

        jsonData[Fields.departures][2][Fields.dateTimes] = JSONValue();
        jsonData[Fields.departures][2][Fields.dateTimes][Fields.date] = 2018_01_01;
        jsonData[Fields.departures][2][Fields.dateTimes][Fields.time] = 11;
        jsonData[Fields.departures][2][Fields.dateTimes][Fields.realtimeDate] = 2018_01_01;
        jsonData[Fields.departures][2][Fields.dateTimes][Fields.realtimeTime] = 13;

        jsonData[Fields.currentDateTime] = "2018-01-01T00:00:00";

        auto callResult = jsonData.parseJsonFahrplan(5.minutes);
        callResult.count.should.equal(2);
        callResult.array.isSorted!((a,
                b) => a.realtimeDeparture <= b.realtimeDeparture).should.equal(true);
    }
}

DepartureData parseJsonDepartureEntry(JSONValue departureInfo)
{
    import bayernfahrplan.fahrplanparser.substitution : substitute;
    import bayernfahrplan.fahrplanparser.json.jsonutils : getLine,
        getDepartureTime, getRealDepartureTime;
    import std.json : JSONException;
    import std.stdio : writeln;
    import std.conv : to;

    try
    {
        // dfmt off
        return DepartureData(departureInfo.getLine,
                departureInfo.getIfKeyExists(Fields.lineInformation).getIfKeyExists(Fields.destination).str.substitute,
                departureInfo.getDepartureTime,
                departureInfo.getRealDepartureTime,
                departureInfo.getIfKeyExists(Fields.realtime).integer == 1
                    ? departureInfo.getIfKeyExists(Fields.lineInformation).getIfKeyExists(Fields.delay).integer
                    : 0);
        // dfmt on
    }
    catch (JSONException ex)
    {
        version (unittest)
        {
            // Intentionally left blank.
        }
        else
        {
            writeln("Error with JSON entry " ~ departureInfo.to!string);
        }
        throw ex;
    }
}

@system
{
    unittest
    {
        import std.json : parseJSON;

        auto jsonData = JSONValue();

        jsonData[Fields.realtime] = 1;

        jsonData[Fields.lineInformation] = JSONValue();

        jsonData[Fields.lineInformation][Fields.lineNumber] = "1A";
        jsonData[Fields.lineInformation][Fields.destination] = "Endstation";
        jsonData[Fields.lineInformation][Fields.delay] = 11;

        jsonData[Fields.dateTimes] = JSONValue();
        jsonData[Fields.dateTimes][Fields.date] = 2018_01_01;
        jsonData[Fields.dateTimes][Fields.time] = 1;
        jsonData[Fields.dateTimes][Fields.realtimeDate] = 2018_01_01;
        jsonData[Fields.dateTimes][Fields.realtimeTime] = 11;

        auto testData = jsonData.parseJsonDepartureEntry;

        testData.line.should.equal("1A");
        // If this fails, check your replacement.txt!
        testData.direction.should.equal("Endstation");
        testData.departure.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        testData.realtimeDeparture.should.equal(DateTime(2018, 1, 1, 0, 11, 0));
        testData.delay.should.equal(11);
    }

    unittest
    {
        import std.json : parseJSON;


        auto jsonData = JSONValue();

        jsonData[Fields.realtime] = 0;

        jsonData[Fields.lineInformation] = JSONValue();

        jsonData[Fields.lineInformation][Fields.lineNumber] = "1A";
        jsonData[Fields.lineInformation][Fields.destination] = "Endstation";
        jsonData[Fields.lineInformation][Fields.delay] = 11;

        jsonData[Fields.dateTimes] = JSONValue();
        jsonData[Fields.dateTimes][Fields.date] = 2018_01_01;
        jsonData[Fields.dateTimes][Fields.time] = 1;
        jsonData[Fields.dateTimes][Fields.realtimeDate] = 2018_01_01;
        jsonData[Fields.dateTimes][Fields.realtimeTime] = 11;

        auto testData = jsonData.parseJsonDepartureEntry;

        testData.line.should.equal("1A");
        testData.direction.should.equal("Endstation");
        testData.departure.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        testData.realtimeDeparture.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        testData.delay.should.equal(0);
    }

    unittest
    {
        import std.json : parseJSON, JSONException;
        import bayernfahrplan.fahrplanparser.data : NoSuchKeyException;

        `{}`.parseJSON.parseJsonDepartureEntry.should.throwException!NoSuchKeyException.msg.should.contain(Fields.lineInformation);
    }
}
