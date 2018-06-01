module bayernfahrplan.fahrplanparser.json.jsonutils;

import std.json : JSONValue;
import std.datetime : DateTime, Date, TimeOfDay;
import std.conv : to;
import fluent.asserts : should;

public:
// Todo: Implement proper error handling
string getLine(ref JSONValue departureInfo)
{
    import std.json : JSON_TYPE;

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

@system
{
    import std.stdio : writeln;

    unittest
    {
        auto classUnderTest = JSONValue(["mode" : ["number" : "1"]]);
        classUnderTest.getLine.should.equal("1");
    }

    unittest
    {
        auto classUnderTest = JSONValue(["mode" : ["number" : 1]]);
        classUnderTest.getLine.should.equal("1");
    }

    unittest
    {
        auto classUnderTest = JSONValue(["mode" : ["number" : ["foo" : "bar"]]]);
        classUnderTest.getLine.should.equal("");
    }
}

DateTime getDepartureTime(JSONValue departureInfo)
{
    return DateTime(departureInfo["dateTime"]["date"].str.parseDefasDate,
            TimeOfDay.fromISOExtString(departureInfo["dateTime"]["time"].str ~ ":00"));
}

@system
{
    import std.stdio : writeln;
    import std.format : format;

    unittest
    {
        auto classUnderTest = JSONValue(["dateTime" : ["date" : "01.01.2018", "time" : "00:01"]]);
        classUnderTest.getDepartureTime.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = JSONValue("");
        classUnderTest.getDepartureTime.should.throwException!JSONException;
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = JSONValue(["dateTime" : ["time" : "00:01"]]);
        classUnderTest.getDepartureTime.should.throwException!JSONException;
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = JSONValue(["dateTime" : ["date" : "01.01.2018"]]);
        classUnderTest.getDepartureTime.should.throwException!JSONException;
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = JSONValue(["dateTime" : ["date" : "01.01.2018", "time" : "00:01"]]);
        classUnderTest.getDepartureTime.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
    }
}

DateTime getRealDepartureTime(ref in JSONValue departureInfo)
{
    // TODO : Error handling
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

@system
{
    import std.json : parseJSON;

    unittest
    {
        auto classUnderTest = `{"realtime": 1, "dateTime": {"rtDate": "1.1.2018", "rtTime": "00:01"}}`
            .parseJSON;
        classUnderTest.getRealDepartureTime.should.equal(DateTime(2018, 1, 1, 00, 01, 00));
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = `{"realtime": 1, "dateTime": {"rtDate": "1.1.2018"}}`.parseJSON;
        classUnderTest.getRealDepartureTime.should.throwException!JSONException;
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = `{"realtime": 1, "dateTime": {"rtTime": "00:01"}}`.parseJSON;
        classUnderTest.getRealDepartureTime.should.throwException!JSONException;
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = `{"dateTime": {"rtDate": "1.1.2018", "rtTime": "00:01"}}`.parseJSON;
        classUnderTest.getRealDepartureTime.should.throwException!JSONException;
    }

    unittest
    {
        auto classUnderTest = `{"realtime": 0,
                "dateTime": {"date": "1.1.2018", "time": "00:01", "rtDate": "1.1.2018", "rtTime": "00:05"}}`
            .parseJSON;
        classUnderTest.getRealDepartureTime.should.not.throwAnyException;
        classUnderTest.getRealDepartureTime.should.equal(DateTime(2018, 1, 1, 00, 01, 00));
    }
}

Date parseDefasDate(string dateString)
{
    import std.array : array, split;
    import std.algorithm.iteration : map;

    auto components = dateString.split(".").map!(to!int).array;
    return Date(components[2], components[1], components[0]);
}

@system
{
    unittest
    {
        auto testDateString = "01.01.2018";
        testDateString.parseDefasDate.should.equal(Date(2018, 1, 1));
    }

    unittest
    {
        auto testDateString = "1.1.2018";
        testDateString.parseDefasDate.should.equal(Date(2018, 1, 1));
    }

    unittest
    {
        import std.conv : ConvException;

        auto testDateString = "1-1-2018";
        testDateString.parseDefasDate.should.throwException!ConvException;
    }

    unittest
    {
        import std.datetime : DateTimeException;

        auto testDateString = "0.0.2018";
        testDateString.parseDefasDate.should.throwException!DateTimeException;
    }
}

// TODO: Error handling
DateTime parseNow(ref in JSONValue data)
{
    auto isoDateTimeString = data["now"].str;
    return DateTime.fromISOExtString(isoDateTimeString);
}

@system
{
    unittest
    {
        auto classUnderTest = JSONValue(["now" : "2018-01-01T12:34:56"]);
        classUnderTest.parseNow.should.equal(DateTime(2018, 1, 1, 12, 34, 56));
    }

    unittest
    {
        import std.json : JSONException;

        auto classUnderTest = JSONValue(["foo" : "bar"]);
        classUnderTest.parseNow.should.throwException!JSONException.msg.should.equal(
                "Key not found: now");
    }
}
