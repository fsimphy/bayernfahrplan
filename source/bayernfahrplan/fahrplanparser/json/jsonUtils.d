module bayernfahrplan.fahrplanparser.json.jsonutils;

import std.json : JSONValue, parseJSON;
import std.datetime : DateTime, Date, TimeOfDay;
import std.conv : to;
import fluent.asserts : should;

// dfmt off
import bayernfahrplan.fahrplanparser.data;
// dfmt on

public:
string getLine(const ref JSONValue departureInfo)
{
    import std.json : JSON_TYPE;

    auto lineNumber = departureInfo.getIfKeyExists(Fields.lineInformation).getIfKeyExists(Fields.lineNumber);
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
    unittest
    {
        auto testData = JSONValue([Fields.lineInformation : [Fields.lineNumber : "1"]]);
        testData.getLine.should.equal("1");
    }

    unittest
    {
        auto testData = JSONValue([Fields.lineInformation : [Fields.lineNumber : 1]]);
        testData.getLine.should.equal("1");
    }

    unittest
    {
        auto testData = JSONValue([Fields.lineInformation : [Fields.lineNumber : ["foo" : "bar"]]]);
        testData.getLine.should.throwException!UnexpectedDataException;
    }
}

DateTime getDepartureTime(JSONValue departureInfo)
{
    import std.string : rightJustify, leftJustify;
    import std.array : array;

    auto dateTimeNode = departureInfo.getIfKeyExists(Fields.dateTimes);

    // dfmt off
    return DateTime(
        Date.fromISOString(
            dateTimeNode.getIfKeyExists(Fields.date).integer.to!string.rightJustify(8, '0').array),
        TimeOfDay.fromISOString(
            dateTimeNode.getIfKeyExists(Fields.time).integer.to!string.rightJustify(4, '0').leftJustify(6, '0').array));
    // dfmt on
}

@system
{
    unittest
    {
        auto testData = JSONValue([Fields.dateTimes : [Fields.date : 20181224, Fields.time : 1819]]);
        testData.getDepartureTime.should.equal(DateTime(2018, 12, 24, 18, 19, 0));
    }

    unittest
    {
        auto testData = JSONValue([Fields.dateTimes : [Fields.date : 2018_01_01, Fields.time : 0001]]);
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
        auto testData = JSONValue([Fields.dateTimes : [Fields.time : 1]]);
        testData.getDepartureTime.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        auto testData = JSONValue([Fields.dateTimes : [Fields.date : 2018_01_01]]);
        testData.getDepartureTime.should.throwException!NoSuchKeyException;
    }

    unittest
    {
        auto testData = JSONValue([Fields.dateTimes : [Fields.date : 2018_01_01, Fields.time : 1]]);
        testData.getDepartureTime.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
    }
}

DateTime getRealDepartureTime(ref const JSONValue departureInfo)
{
    if (departureInfo.getIfKeyExists(Fields.realtime).integer == 1)
    {
        import std.string : leftJustify, rightJustify;
        import std.array : array;

        auto dateTimeNode = departureInfo.getIfKeyExists(Fields.dateTimes);
        // dfmt off
        return DateTime(
            Date.fromISOString(
                dateTimeNode.getIfKeyExists(Fields.realtimeDate).integer.to!string.rightJustify(8, '0').array),
            TimeOfDay.fromISOString(
                dateTimeNode.getIfKeyExists(Fields.realtimeTime).integer.to!string.rightJustify(4, '0').leftJustify(6, '0').array));
        // dfmt on
    }
    else
    {
        return departureInfo.getDepartureTime;
    }
}

@system
{
    unittest
    {
        auto testData = JSONValue();
        testData[Fields.realtime] = 1;
        //dfmt off
        testData[Fields.dateTimes] = [
            Fields.realtimeDate : 2018_12_24,
            Fields.realtimeTime : 1819
        ];
        //dfmt on
        testData.getRealDepartureTime.should.equal(DateTime(2018, 12, 24, 18, 19, 0));
    }

    unittest
    {
        auto testData = JSONValue();
        testData[Fields.realtime] = 1;
        // dfmt off
        testData[Fields.dateTimes] = [
            Fields.realtimeDate : 2018_01_01,
            Fields.realtimeTime : 1
        ];
        // dfmt on
        testData.getRealDepartureTime.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
    }

    unittest
    {
        auto testData = JSONValue();
        testData[Fields.realtime] = 1;
        testData[Fields.dateTimes] = [Fields.realtimeDate : 2019_01_01];

        // dfmt off
        testData.getRealDepartureTime.should.throwException!NoSuchKeyException
            .msg.should.contain(Fields.realtimeTime);
        // dfmt on
    }

    unittest
    {
        auto testData = JSONValue();
        testData[Fields.realtime] = 1;
        testData[Fields.dateTimes] = [Fields.realtimeTime : 1];

        // dfmt off
        testData.getRealDepartureTime.should.throwException!NoSuchKeyException
            .msg.should.contain(Fields.realtimeDate);
        // dfmt on
    }

    unittest
    {
        auto testData = JSONValue();
        // dfmt off
        testData[Fields.dateTimes] = [
            Fields.realtimeDate: 2018_01_01,
            Fields.realtimeTime: 1
        ];

        testData.getRealDepartureTime.should.throwException!NoSuchKeyException
            .msg.should.contain(Fields.realtime);
        // dfmt on
    }

    unittest
    {
        auto testData = JSONValue();
        testData[Fields.realtime] = 0;
        // dfmt off
        testData[Fields.dateTimes] = [
            Fields.date: 2018_01_01,
            Fields.time: 1,
            Fields.realtimeDate: 2018_01_02,
            Fields.realtimeTime: 5
        ];
        // dfmt on
        const testCallResult = testData.getRealDepartureTime;

        testCallResult.should.not.throwAnyException;
        testCallResult.should.equal(DateTime(2018, 1, 1, 0, 1, 0));
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
        auto testData = JSONValue([Fields.currentDateTime: "2018-01-01T12:34:56"]);
        testData.parseNow.should.equal(DateTime(2018, 1, 1, 12, 34, 56));
    }

    unittest
    {
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
