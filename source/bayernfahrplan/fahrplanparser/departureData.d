module bayernfahrplan.fahrplanparser.departuredata;

import std.datetime : DateTime, Duration;
import std.json : JSONValue;

import bayernfahrplan.fahrplanparser.jsonutils : getLine, getDepartureTime,
    getRealDepartureTime;

import fluent.asserts : should;

public struct DepartureData
{
    string line;
    string direction;
    DateTime departure;
    DateTime realtimeDeparture;
    long delay;
}

JSONValue toJson(DepartureData dp)
{
    import std.json : parseJSON;
    import std.format : format;

    with (dp)
    {
        // dfmt off
        return format!`{"line":"%1$s","direction":"%2$s","departure":"%3$02d:%4$02d","delay":"%5$s"}`
            (line,
            direction,
            departure.timeOfDay.hour,
            departure.timeOfDay.minute,
            delay).parseJSON;
        //dfmt on
    }
}

@system
{
    unittest
    {
        import std.json : parseJSON;

        auto expected = `{
            "line": "1A",
            "direction": "Endhalt",
            "departure": "00:01",
            "delay": "2"
        }`.parseJSON;
        //dfmt off
        auto classUnderTest = DepartureData("1A", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 3, 0),
            2);
        //dfmt on

        classUnderTest.toJson.should.equal(expected);
    }
}

DepartureData parseDepartureEntry(JSONValue departureInfo)
{
    import bayernfahrplan.fahrplanparser.substitution : substitute;
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
            }`.parseJSON.parseDepartureEntry;

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
            }`.parseJSON.parseDepartureEntry;

        classUnderTest.line.should.equal("1A");
        classUnderTest.direction.should.equal("Endstation");
        classUnderTest.departure.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        classUnderTest.realtimeDeparture.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
        classUnderTest.delay.should.equal(0);
    }

    unittest
    {
        import std.json : parseJSON, JSONException;

        `{}`.parseJSON.parseDepartureEntry.should.throwException!JSONException;
    }
}

bool isReachable(ref in DepartureData realDeparture, ref in DateTime now, Duration threshold)
{
    return (realDeparture.realtimeDeparture - now) >= threshold;
}

@system
{
    unittest
    {
        import core.time : minutes;

        //dfmt off
        auto departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 11, 0),
            10);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 0, 6, 0);
        assert(departureData.isReachable(fakeNow, 4.minutes));
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        auto departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 11, 0),
            10);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 0, 6, 0);
        assert(departureData.isReachable(fakeNow, 5.minutes));
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        auto departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 11, 0),
            10);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 0, 6, 0);
        assert(!departureData.isReachable(fakeNow, 6.minutes));
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        auto departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 23, 59, 0),
            DateTime(2018, 1, 2, 0, 1, 0),
            2);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 23, 59, 0);
        assert(departureData.isReachable(fakeNow, 1.minutes));
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        auto departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 23, 59, 0),
            DateTime(2018, 1, 2, 0, 1, 0),
            2);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 23, 59, 0);
        assert(departureData.isReachable(fakeNow, 2.minutes));
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        auto departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 23, 59, 0),
            DateTime(2018, 1, 2, 0, 1, 0),
            2);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 23, 59, 0);
        assert(!departureData.isReachable(fakeNow, 3.minutes));
    }
}
