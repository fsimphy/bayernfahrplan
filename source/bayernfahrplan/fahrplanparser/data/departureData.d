module bayernfahrplan.fahrplanparser.data.departuredata;

import std.datetime : DateTime, Duration;
import std.json : JSONValue;

import fluent.asserts : should;

/**
 * Holds all data relevant for a bus/train/ departure.
 */
struct DepartureData
{
    /// Short name of the bus line, e.g. `2A`.
    string line;
    /// Long name of the name, most likely its last stop.
    string direction;
    /// Scheduled departure.
    DateTime departure;
    /// Real departure, if available.
    DateTime realtimeDeparture;
    /// How much the departure is delayed, in minutes.
    long delay;

    /**
     * Creates the JSON representation needed for the FSIMPhy Infoscreen.
     * Returns: A JSON representation as string.
     */
    JSONValue toJson() const
    {
        import std.json : parseJSON;
        import std.format : format;

        // dfmt off
    return format!`{"line":"%1$s","direction":"%2$s","departure":"%3$02d:%4$02d","delay":"%5$s"}`
        (line,
        direction,
        departure.timeOfDay.hour,
        departure.timeOfDay.minute,
        delay).parseJSON;
    //dfmt on
    }

    /**
     * Evaluates, if the departure of a bus lies within a duration that is considered unreachable.
     * Params:
     *      now         =   the current date and time (best: as given by the server)
     *      threshold   =   timespan considered unreachable
     * Returns: True if the bus is reachable, False if not
     */
    bool isReachable(const ref DateTime now, const Duration threshold) const
    {
        return (realtimeDeparture - now) >= threshold;
    }
}

// toJson
@system
{
    unittest
    {
        import std.json : parseJSON;

        const expected = `{
            "line": "1A",
            "direction": "Endhalt",
            "departure": "00:01",
            "delay": "2"
        }`.parseJSON;
        //dfmt off
        const testInput = DepartureData("1A", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 3, 0),
            2);
        //dfmt on

        testInput.toJson.should.equal(expected);
    }
}

// isReachable
@system
{
    unittest
    {
        import core.time : minutes;

        //dfmt off
        const departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 11, 0),
            10);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 0, 6, 0);
        departureData.isReachable(fakeNow, 4.minutes).should.equal(true);
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        const departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 11, 0),
            10);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 0, 6, 0);
        departureData.isReachable(fakeNow, 5.minutes).should.equal(true);
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        const departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 0, 1, 0),
            DateTime(2018, 1, 1, 0, 11, 0),
            10);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 0, 6, 0);
        departureData.isReachable(fakeNow, 6.minutes).should.equal(false);
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        const departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 23, 59, 0),
            DateTime(2018, 1, 2, 0, 1, 0),
            2);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 23, 59, 0);
        departureData.isReachable(fakeNow, 1.minutes).should.equal(true);
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        const departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 23, 59, 0),
            DateTime(2018, 1, 2, 0, 1, 0),
            2);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 23, 59, 0);
        departureData.isReachable(fakeNow, 2.minutes).should.equal(true);
    }

    unittest
    {
        import core.time : minutes;

        //dfmt off
        const departureData = DepartureData("11", "Endhalt",
            DateTime(2018, 1, 1, 23, 59, 0),
            DateTime(2018, 1, 2, 0, 1, 0),
            2);
        //dfmt on

        const fakeNow = DateTime(2018, 1, 1, 23, 59, 0);
        departureData.isReachable(fakeNow, 3.minutes).should.equal(false);
    }
}
