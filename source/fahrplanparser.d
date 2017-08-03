module fahrplanparser;

import std.algorithm : map;
import std.array : empty, front;
import std.conv : to;
import std.datetime : dur, TimeOfDay, DateTimeException;
import std.string : format;

import kxml.xml : readDocument, XmlNode;

import substitution;

private:

enum departureNodeName = "dp";
enum timeNodeName = "t";
enum realTimeNodeName = "rt";

enum departuresXPath = "/efa/dps/" ~ departureNodeName;
template timeXPath(string _timeNodeName = timeNodeName)
{
    enum timeXPath = "/st/" ~ _timeNodeName;
}

enum useRealTimeXPath = "/realtime";
enum lineXPath = "/m/nu";
enum directionXPath = "/m/des";

public:

/***********************************
* Parses the departure monitor data and returns it as an associative array.
* data is expected to contain valid XML as returned by queries sent to http://mobile.defas-fgi.de/beg/.
*/

auto parsedFahrplan(in string data)
{
    // dfmt off
    return data.readDocument
        .parseXPath(departuresXPath)
        .map!(dp => ["departure" : "%02s:%02s".format(dp.departureTime.hour, dp.departureTime.minute),
                     "delay" : dp.delay.total!"minutes".to!string,
                     "line": dp.parseXPath(lineXPath).front.getCData,
                     "direction": dp.parseXPath(directionXPath).front.getCData.substitute]);
    // dfmt on
}

///
@system unittest
{
    import std.array : array;

    auto xml = "";
    assert(xml.parsedFahrplan.array == []);

    xml = "<efa><dps></dps></efa>";
    assert(xml.parsedFahrplan.array == []);

    xml = "<efa><dps><dp><realtime>1</realtime><st><t>1224</t><rt>1242</rt></st><m><nu>6</nu><des>Wernerwerkstraße</des></m></dp></dps></efa>";
    assert(xml.parsedFahrplan.array == [["direction" : "Wernerwerkstraße",
            "line" : "6", "departure" : "12:24", "delay" : "18"]]);

    xml = "<efa><dps><dp><realtime>0</realtime><st><t>1224</t></st><m><nu>6</nu><des>Wernerwerkstraße</des></m></dp></dps></efa>";
    assert(xml.parsedFahrplan.array == [["direction" : "Wernerwerkstraße",
            "line" : "6", "departure" : "12:24", "delay" : "0"]]);

    xml = "<efa><dps><dp><realtime>0</realtime><st><t>1224</t></st><m><nu>6</nu><des>Wernerwerkstraße</des></m></dp><dp><realtime>1</realtime><st><t>1353</t><rt>1356</rt></st><m><nu>11</nu><des>Burgweinting</des></m></dp></dps></efa>";
    assert(xml.parsedFahrplan.array == [["direction" : "Wernerwerkstraße", "line" : "6",
            "departure" : "12:24", "delay" : "0"], ["direction" : "Burgweinting",
            "line" : "11", "departure" : "13:53", "delay" : "3"]]);
}

private:

class UnexpectedValueException(T) : Exception
{
    this(T t, string node) @safe pure
    {
        super(`Unexpected value "%s" for node "%s"`.format(t, node));
    }
}

class CouldNotFindeNodeException : Exception
{
    this(string node) @safe pure
    {
        super(`Could not find node "%s"`.format(node));
    }
}

auto departureTime(string _timeNodeName = timeNodeName)(XmlNode dp)
in
{
    assert(dp.getName == departureNodeName);
}
body
{
    auto timeNodes = dp.parseXPath(timeXPath!_timeNodeName);
    if (timeNodes.empty)
        throw new CouldNotFindeNodeException(_timeNodeName);

    return TimeOfDay.fromISOString(timeNodes.front.getCData ~ "00");
}

@system unittest
{
    import std.exception : assertThrown;

    auto xml = "<dp><st><t>0000</t></st></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.departureTime == TimeOfDay(0, 0));

    xml = "<dp><st><t>0013</t></st></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.departureTime == TimeOfDay(0, 13));

    xml = "<dp><st><t>1100</t></st></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.departureTime == TimeOfDay(11, 00));

    xml = "<dp><st><t>1242</t></st></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.departureTime == TimeOfDay(12, 42));

    xml = "<dp><st><t>2359</t></st></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.departureTime == TimeOfDay(23, 59));

    assertThrown!DateTimeException("<dp><st><t>2400</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t>0061</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t>2567</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t></t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t>0</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t>00</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t>000000</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t>00:00</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
    assertThrown!DateTimeException("<dp><st><t>abcd</t></st></dp>".readDocument.parseXPath("/dp")
            .front.departureTime);
}

auto delay(XmlNode dp)
in
{
    assert(dp.getName == departureNodeName);
}
body
{
    immutable useRealtimeString = dp.parseXPath(useRealTimeXPath).front.getCData;
    if (useRealtimeString == "0")
        return dur!"minutes"(0);
    else if (useRealtimeString == "1")
    {
        try
        {
            immutable expectedTime = dp.departureTime;
            immutable realTime = dp.departureTime!realTimeNodeName;
            auto timeDiff = realTime - expectedTime;
            if (timeDiff < dur!"minutes"(0))
                timeDiff = dur!"hours"(24) + timeDiff;
            return timeDiff;
        }
        catch (CouldNotFindeNodeException e)
        {
            return dur!"minutes"(0);
        }
    }
    else
        throw new UnexpectedValueException!string(useRealtimeString, "realtime");
}

@system unittest
{
    import std.exception : assertThrown;
    import core.exception : AssertError;

    auto xml = "<dp><realtime>0</realtime></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(0));

    xml = "<dp><realtime></realtime></dp>".readDocument.parseXPath("/dp").front;
    assertThrown!(UnexpectedValueException!string)(xml.delay);

    xml = "<dp><realtime>2</realtime></dp>".readDocument.parseXPath("/dp").front;
    assertThrown!(UnexpectedValueException!string)(xml.delay);

    xml = "<dp><realtime>a</realtime></dp>".readDocument.parseXPath("/dp").front;
    assertThrown!(UnexpectedValueException!string)(xml.delay);

    xml = "<dp><realtime>1</realtime></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"seconds"(0));

    xml = "<dp><realtime>1</realtime><st><t></t></st></dp>".readDocument.parseXPath("/dp").front;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt></rt></st></dp>".readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"seconds"(0));

    xml = "<dp><st><rt></rt><t></t></st></dp>".readDocument.parseXPath("/dp").front;
    assertThrown!AssertError(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt></rt><t></t></st></dp>".readDocument.parseXPath("/dp")
        .front;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t></t></st></dp>".readDocument.parseXPath("/dp")
        .front;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt></rt><t>0000</t></st></dp>".readDocument.parseXPath("/dp")
        .front;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t>0000</t></st></dp>"
        .readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(0));

    xml = "<dp><realtime>1</realtime><st><rt>0001</rt><t>0000</t></st></dp>"
        .readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(1));

    xml = "<dp><realtime>1</realtime><st><rt>1753</rt><t>1751</t></st></dp>"
        .readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(2));

    xml = "<dp><realtime>1</realtime><st><rt>1010</rt><t>1000</t></st></dp>"
        .readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(10));

    xml = "<dp><realtime>1</realtime><st><rt>1301</rt><t>1242</t></st></dp>"
        .readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(19));

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t>1242</t></st></dp>"
        .readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(678));

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t>2359</t></st></dp>"
        .readDocument.parseXPath("/dp").front;
    assert(xml.delay == dur!"minutes"(1));
}
