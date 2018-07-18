module bayernfahrplan.fahrplanparser.json.jsonutils;

import std.json : JSONValue;
import std.datetime : DateTime, Date, TimeOfDay;
import std.conv : to;
import fluent.asserts : should;

// dfmt off
import bayernfahrplan.fahrplanparser.data : NoSuchKeyException,  UnexpectedDataException, Fields;
// dfmt on

public:
string getLine(const ref JSONValue departureInfo)
{
    import std.json : JSON_TYPE;

    auto lineNumber = departureInfo.getIfKeyExists(Fields.mode).getIfKeyExists(Fields.lineNumber);
    switch (lineNumber.type) with (JSON_TYPE)
    {
    case STRING:
        return lineNumber.str;
    case INTEGER:
        return lineNumber.integer.to!string;
    default:
        throw new UnexpectedDataException(departureInfo, "mode.number",
                [JSON_TYPE.INTEGER, JSON_TYPE.STRING], lineNumber.type);
    }
}

@system
{
    import std.stdio : writeln;

    unittest
    {
        auto testData = `{"mode": {"number": "1"}}`.parseJSON;
        testData.getLine.should.equal("1");
    }

    unittest
    {
        auto testData = `{"mode":{"number": 1}}`.parseJSON;
        testData.getLine.should.equal("1");
    }

    unittest
    {
        auto testData = `{"mode" : {"number" : {"foo" : "bar"}}}`.parseJSON;
        testData.getLine.should.throwException!UnexpectedDataException;
    }
}

DateTime getDepartureTime(JSONValue departureInfo)
{
    auto dateTimeNode = departureInfo.getIfKeyExists(Fields.dateTimes);
    return DateTime(
        dateTimeNode.getIfKeyExists(Fields.date).str.parseDefasDate,
        TimeOfDay.fromISOExtString(dateTimeNode.getIfKeyExists(Fields.time).str ~ ":00"));
}

@system
{
    import std.stdio : writeln;
    import std.format : format;

    unittest
    {
        auto testData = JSONValue(["dateTime" : ["date" : "01.01.2018", "time" : "00:01"]]);
        testData.getDepartureTime.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = JSONValue("");
        testData.getDepartureTime.should.throwException!JSONException;
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = JSONValue(["dateTime" : ["time" : "00:01"]]);
        testData.getDepartureTime.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = JSONValue(["dateTime" : ["date" : "01.01.2018"]]);
        testData.getDepartureTime.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = JSONValue(["dateTime" : ["date" : "01.01.2018", "time" : "00:01"]]);
        testData.getDepartureTime.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
    }
}

DateTime getRealDepartureTime(ref in JSONValue departureInfo)
{
    if (departureInfo.getIfKeyExists(Fields.realtime).integer == 1)
    {
        auto dateTimeNode = departureInfo.getIfKeyExists(Fields.dateTimes);
        return DateTime(dateTimeNode.getIfKeyExists(Fields.realtimeDate).str.parseDefasDate,
                TimeOfDay.fromISOExtString(dateTimeNode.getIfKeyExists(Fields.realtimeTime).str ~ ":00"));
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
        auto testData = `{"realtime": 1, "dateTime": {"rtDate": "1.1.2018", "rtTime": "00:01"}}`
            .parseJSON;
        testData.getRealDepartureTime.should.equal(DateTime(2018, 1, 1, 00, 01, 00));
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = `{"realtime": 1, "dateTime": {"rtDate": "1.1.2018"}}`.parseJSON;
        testData.getRealDepartureTime.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = `{"realtime": 1, "dateTime": {"rtTime": "00:01"}}`.parseJSON;
        testData.getRealDepartureTime.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = `{"dateTime": {"rtDate": "1.1.2018", "rtTime": "00:01"}}`.parseJSON;
        testData.getRealDepartureTime.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        auto testData = `{"realtime": 0,
                "dateTime": {"date": "1.1.2018", "time": "00:01", "rtDate": "1.1.2018", "rtTime": "00:05"}}`
            .parseJSON;
        const testCallResult = testData.getRealDepartureTime;

        testCallResult.should.not.throwAnyException;
        testCallResult.should.equal(DateTime(2018, 1, 1, 00, 01, 00));
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
        testDateString.parseDefasDate.should.throwException!(ConvException);
    }

    unittest
    {
        import std.datetime : DateTimeException;

        auto testDateString = "0.0.2018";
        testDateString.parseDefasDate.should.throwException!DateTimeException;
    }
}

DateTime parseNow(ref in JSONValue data)
{
    auto isoDateTimeString = data.getIfKeyExists(Fields.currentDateTime).str;
    return DateTime.fromISOExtString(isoDateTimeString);
}

@system
{
    unittest
    {
        auto testData = `{"now":"2018-01-01T12:34:56"}`.parseJSON;
        testData.parseNow.should.equal(DateTime(2018, 1, 1, 12, 34, 56));
    }

    unittest
    {
        import std.json : JSONException;

        auto testData = `{"foo":"bar"}`.parseJSON;
        testData.parseNow.should.throwException!NoSuchKeyException;
    }
}

JSONValue getIfKeyExists(JSONValue data, string key, string file = __FILE__, size_t line = __LINE__)
{
    if (key in data)
    {
        return data[key];
    }
    else
    {
        throw new NoSuchKeyException(data, key, file, line, null);
    }
}

@system
{
    unittest
    {
        const testData = `{"key": "value"}`.parseJSON;
        testData.getIfKeyExists("key").should.equal(`"value"`.parseJSON);
    }

    unittest
    {
        const testData = `{"key": "value"}`.parseJSON;
        testData.getIfKeyExists("key2").should.throwException!NoSuchKeyException;
    }
}
