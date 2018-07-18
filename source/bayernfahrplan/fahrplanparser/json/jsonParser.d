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
        jsonData.parseJsonFahrplan.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        import std.algorithm.searching : count;

        const jsonData = `{
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
        jsonData.parseJsonFahrplan().count.should.equal(1);
    }

    unittest
    {
        import std.algorithm.searching : count;

        const jsonData = `{
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
        jsonData.parseJsonFahrplan(15.minutes).count.should.equal(0);
    }

    unittest
    {
        import std.algorithm.searching : count;
        import std.algorithm.sorting : isSorted;

        const jsonData = `{
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
        auto callResult = jsonData.parseJsonFahrplan(5.minutes);
        callResult.count.should.equal(2);
        callResult.array.isSorted!((a, b) => a.realtimeDeparture <= b.realtimeDeparture).should.equal(true);
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
                departureInfo.getIfKeyExists(Fields.mode).getIfKeyExists(Fields.destination).str.substitute,
                departureInfo.getDepartureTime,
                departureInfo.getRealDepartureTime,
                departureInfo.getIfKeyExists(Fields.realtime).integer == 1
                    ? departureInfo.getIfKeyExists(Fields.mode).getIfKeyExists(Fields.delay).integer
                    : 0);
        // dfmt on
    }
    catch (JSONException ex)
    {
        version(unittest) {
            // Intentionally left blank.
        } else {
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

        auto testData = `{
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

        auto testData = `{
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

        `{}`.parseJSON.parseJsonDepartureEntry.should.throwException!NoSuchKeyException;
    }
}
