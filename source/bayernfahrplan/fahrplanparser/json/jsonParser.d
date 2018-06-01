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
import bayernfahrplan.fahrplanparser.data.departuredata : DepartureData, isReachable;
import bayernfahrplan.fahrplanparser.json : parseNow;
import fluent.asserts : should;

InputRange!DepartureData parseJsonFahrplan(ref in JSONValue data,
        Duration reachabilityThreshold = 0.minutes)
{

    const currentDateTime = data.parseNow();

    // dfmt off
    auto reachableDepartures = data["departures"].array
        .map!parseJsonDepartureEntry
        .array
        .sort!((a, b) => a.realtimeDeparture < b.realtimeDeparture)
        .filter!(dp => dp.isReachable(currentDateTime, reachabilityThreshold))
        .inputRangeObject;
    // dfmt on

    return reachableDepartures;
}

@system
{
    unittest
    {
        import std.algorithm.searching : count;

        const objectUnderTest = `{
            "departures": [
                {
                    "realtime": 1,
                    "mode": {
                        "number": "1A",
                        "destination": "Endstation",
                        "delay": 11
                    },
                    "dateTime": {
                        "date": "1.1.2018",
                        "time": "00:01",
                        "rtDate": "01.01.2018",
                        "rtTime": "00:11"
                    }
                }
            ],
            "now": "2018-01-01T00:00:00"
        }`.parseJSON;
        auto classUnderTest = objectUnderTest.parseJsonFahrplan();
        classUnderTest.count.should.equal(1);
    }

    unittest
    {
        import std.algorithm.searching : count;

        const objectUnderTest = `{
            "departures": [
                {
                    "realtime": 1,
                    "mode": {
                        "number": "1A",
                        "destination": "Endstation",
                        "delay": 11
                    },
                    "dateTime": {
                        "date": "1.1.2018",
                        "time": "00:01",
                        "rtDate": "01.01.2018",
                        "rtTime": "00:11"
                    }
                }
            ],
            "now": "2018-01-01T00:00:00"
        }`.parseJSON;
        auto classUnderTest = objectUnderTest.parseJsonFahrplan(15.minutes);
        classUnderTest.count.should.equal(0);
    }

    unittest
    {
        import std.algorithm.searching : count;
        import std.algorithm.sorting : isSorted;

        const objectUnderTest = `{
            "departures": [
                {
                    "realtime": 1,
                    "mode": {
                        "number": "1A",
                        "destination": "Endstation",
                        "delay": 19
                    },
                    "dateTime": {
                        "date": "1.1.2018",
                        "time": "00:01",
                        "rtDate": "01.01.2018",
                        "rtTime": "00:20"
                    }
                },
                {
                    "realtime": 0,
                    "mode": {
                        "number": "2A",
                        "destination": "Endstation2",
                        "delay": 0
                    },
                    "dateTime": {
                        "date": "1.1.2018",
                        "time": "00:01"
                    }
                },
                {
                    "realtime": 1,
                    "mode": {
                        "number": "1A",
                        "destination": "Endstation",
                        "delay": 3
                    },
                    "dateTime": {
                        "date": "1.1.2018",
                        "time": "00:11",
                        "rtDate": "01.01.2018",
                        "rtTime": "00:13"
                    }
                }
            ],
            "now": "2018-01-01T00:00:00"
        }`.parseJSON;
        auto classUnderTest = objectUnderTest.parseJsonFahrplan(5.minutes);
        classUnderTest.count.should.equal(2);
        assert(classUnderTest.array.isSorted!((a, b) => a.realtimeDeparture <= b.realtimeDeparture));
    }
}


DepartureData parseJsonDepartureEntry(JSONValue departureInfo)
{
    import bayernfahrplan.fahrplanparser.substitution : substitute;
    import bayernfahrplan.fahrplanparser.json.jsonutils : getLine, getDepartureTime, getRealDepartureTime;
    import std.json : JSONException;
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

@system
{
    unittest
    {
        import std.json : parseJSON;

        auto classUnderTest = `{
                "realtime": 1,
                "mode": {
                    "number": "1A",
                    "destination": "Endstation",
                    "delay": 11
                },
                "dateTime": {
                    "date": "1.1.2018",
                    "time": "00:01",
                    "rtDate": "01.01.2018",
                    "rtTime": "00:11"
                }
            }`.parseJSON.parseJsonDepartureEntry;

        classUnderTest.line.should.equal("1A");
        // If this fails, check your replacement.txt!
        classUnderTest.direction.should.equal("Endstation");
        classUnderTest.departure.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        classUnderTest.realtimeDeparture.should.equal(DateTime(2018, 1, 1, 0, 11, 0));
        classUnderTest.delay.should.equal(11);
    }

    unittest
    {
        import std.json : parseJSON;

        auto classUnderTest = `{
                "realtime": 0,
                "mode": {
                    "number": "1A",
                    "destination": "Endstation",
                    "delay": 11
                },
                "dateTime": {
                    "date": "1.1.2018",
                    "time": "00:01",
                    "rtDate": "01.01.2018",
                    "rtTime": "00:11"
                }
            }`.parseJSON.parseJsonDepartureEntry;

        classUnderTest.line.should.equal("1A");
        classUnderTest.direction.should.equal("Endstation");
        classUnderTest.departure.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        classUnderTest.realtimeDeparture.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        classUnderTest.delay.should.equal(0);
    }

    unittest
    {
        import std.json : parseJSON, JSONException;

        `{}`.parseJSON.parseJsonDepartureEntry.should.throwException!JSONException;
    }
}
