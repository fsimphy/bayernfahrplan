module fahrplanparser;

import core.time : Duration;

import std.algorithm : map, filter;
import std.array : empty, front;
import std.conv : to;
import std.datetime;
import std.string : format;

import kxml.xml : XmlNode;

import substitution;

private:

enum departureNodeName = "dp";
enum timeNodeName = "t";
enum dateNodeName = "da";
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

auto parsedFahrplan(in string data, in long walkingDelay = 0, in SysTime currentTime = Clock.currTime)
{
    import core.time : minutes;
    import kxml.xml : readDocument;

    auto walkingDuration = minutes(walkingDelay);
    
    // dfmt off
    return data.readDocument
        .parseXPath(departuresXPath)
        .map!(dp => ScheduleXmlNode(dp))
        .filter!(dp => dp.isReachable(walkingDuration, currentTime))
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

    auto testCurrentTime = SysTime(
        DateTime(2018, 1, 1, 0, 0, 0)
    );

    auto xml = "";
    assert(xml.parsedFahrplan(0, testCurrentTime).array == []);

    xml = "<efa><dps></dps></efa>";
    assert(xml.parsedFahrplan(0, testCurrentTime).array == []);

    xml = "<efa><dps><dp><realtime>1</realtime><st><da>20180101</da><t>1224</t><rt>1242</rt></st><m><nu>6</nu><des>Wernerwerkstraße</des></m></dp></dps></efa>";
    assert(xml.parsedFahrplan(0, testCurrentTime).array == [["direction" : "Wernerwerkstraße",
            "line" : "6", "departure" : "12:24", "delay" : "18"]]);

    xml = "<efa><dps><dp><realtime>0</realtime><st><da>20180101</da><t>1224</t></st><m><nu>6</nu><des>Wernerwerkstraße</des></m></dp></dps></efa>";
    assert(xml.parsedFahrplan(0, testCurrentTime).array == [["direction" : "Wernerwerkstraße",
            "line" : "6", "departure" : "12:24", "delay" : "0"]]);

    xml = "<efa><dps><dp><realtime>0</realtime><st><da>20180101</da><t>1224</t></st><m><nu>6</nu><des>Wernerwerkstraße</des></m></dp><dp><realtime>1</realtime><st><da>20180101</da><t>1353</t><rt>1356</rt></st><m><nu>11</nu><des>Burgweinting</des></m></dp></dps></efa>";
    assert(xml.parsedFahrplan(0, testCurrentTime).array == [["direction" : "Wernerwerkstraße", "line" : "6",
            "departure" : "12:24", "delay" : "0"], ["direction" : "Burgweinting",
            "line" : "11", "departure" : "13:53", "delay" : "3"]]);
}

struct ScheduleXmlNode {
    private XmlNode innerNode;
    alias innerNode this;

    public auto departureDate(string _dateNodeName = dateNodeName)()
    in
    {
        assert(this.getName == departureNodeName);
    }
    body
    {
        import std.datetime.date : Date;
        auto dateNodes = this.parseXPath(timeXPath!_dateNodeName);
        if(dateNodes.empty) {
            throw new CouldNotFindNodeException(_dateNodeName);
        }
        return Date.fromISOString(dateNodes.front.getCData);
    }
    @system unittest
    {
        import std.exception : assertThrown;
        import testutils : toScheduleXmlNode;

        auto xml = "<dp><st><da>19700101</da></st></dp>".toScheduleXmlNode;
        assert(xml.departureDate == Date(1970, 1, 1));
        
        xml = "<dp><st><da>19700124</da></st></dp>".toScheduleXmlNode;
        assert(xml.departureDate == Date(1970, 1, 24));
        
        xml = "<dp><st><da>19701101</da></st></dp>".toScheduleXmlNode;
        assert(xml.departureDate == Date(1970, 11, 1));
        
        xml = "<dp><st><da>20180101</da></st></dp>".toScheduleXmlNode;
        assert(xml.departureDate == Date(2018, 1, 1));

        xml = "<dp><st><da>20181124</da></st></dp>".toScheduleXmlNode;
        assert(xml.departureDate == Date(2018, 11, 24));

        assertThrown!DateTimeException("<dp><st><da>00000000</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da>00001300</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da>00000032</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da>20180229</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da></da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da>11</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da>201801011</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da>2018.01.01</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!DateTimeException("<dp><st><da>2018-a0-01</da></st></dp>".toScheduleXmlNode.departureDate);
        assertThrown!CouldNotFindNodeException("<dp><st><t>00:00</t></st></dp>".toScheduleXmlNode.departureDate);
    }

    auto departureTime(string _timeNodeName = timeNodeName)()
    in
    {
        assert(this.getName == departureNodeName);
    }
    body
    {
        auto timeNodes = this.parseXPath(timeXPath!_timeNodeName);
        if (timeNodes.empty)
            throw new CouldNotFindNodeException(_timeNodeName);

        return TimeOfDay.fromISOString(timeNodes.front.getCData ~ "00");
    }
    @system unittest
    {
        import std.exception : assertThrown;
        import testutils : toScheduleXmlNode;

        auto xml = "<dp><st><t>0000</t></st></dp>".toScheduleXmlNode;
        assert(xml.departureTime == TimeOfDay(0, 0));

        xml = "<dp><st><t>0013</t></st></dp>".toScheduleXmlNode;
        assert(xml.departureTime == TimeOfDay(0, 13));

        xml = "<dp><st><t>1100</t></st></dp>".toScheduleXmlNode;
        assert(xml.departureTime == TimeOfDay(11, 00));

        xml = "<dp><st><t>1242</t></st></dp>".toScheduleXmlNode;
        assert(xml.departureTime == TimeOfDay(12, 42));

        xml = "<dp><st><t>2359</t></st></dp>".toScheduleXmlNode;
        assert(xml.departureTime == TimeOfDay(23, 59));

        assertThrown!DateTimeException("<dp><st><t>2400</t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t>0061</t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t>2567</t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t></t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t>0</t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t>00</t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t>000000</t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t>00:00</t></st></dp>".toScheduleXmlNode.departureTime);
        assertThrown!DateTimeException("<dp><st><t>abcd</t></st></dp>".toScheduleXmlNode.departureTime);
    }
}

private:
class UnexpectedValueException(T) : Exception
{
    this(T t, string node) @safe pure
    {
        super(`Unexpected value "%s" for node "%s"`.format(t, node));
    }
}

class CouldNotFindNodeException : Exception
{
    this(string node) @safe pure
    {
        super(`Could not find node "%s"`.format(node));
    }
}

/**
 * Checks if a departure given as XMLNode can be reached within a given duration.
 */
bool isReachable(ScheduleXmlNode dp, Duration walkingDuration, SysTime currentTime = Clock.currTime) in 
{
   assert(walkingDuration >= Duration.zero);
}
body
{
    import std.datetime.date : Date;
    import std.datetime : DateTime;

    auto departureDateTime = DateTime(dp.departureDate, dp.departureTime);

    auto timeUntilDeparture = SysTime(departureDateTime) - currentTime;
    return timeUntilDeparture >= walkingDuration;
}
@system unittest
{
    import core.time : minutes;
    import std.datetime : DateTime;
    import testutils : toScheduleXmlNode;

    // easily reachable
    auto walkingDuration = minutes(9);
    auto testCurrentTime = SysTime(
        DateTime(2018, 1, 1, 0, 0, 0)
    );
    auto xml = "<dp><st><da>20180101</da><t>0010</t></st></dp>".toScheduleXmlNode;
    assert(xml.isReachable(walkingDuration, testCurrentTime));

    // exactly reachable
    walkingDuration = minutes(10);
    assert(xml.isReachable(walkingDuration, testCurrentTime));
    
    // unreachable
    walkingDuration = minutes(11);
    assert(!xml.isReachable(walkingDuration, testCurrentTime));
}

auto delay(ScheduleXmlNode dp)
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
        catch (CouldNotFindNodeException e)
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
    import testutils : toScheduleXmlNode;

    auto xml = "<dp><realtime>0</realtime></dp>".toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(0));

    xml = "<dp><realtime></realtime></dp>".toScheduleXmlNode;
    assertThrown!(UnexpectedValueException!string)(xml.delay);

    xml = "<dp><realtime>2</realtime></dp>".toScheduleXmlNode;
    assertThrown!(UnexpectedValueException!string)(xml.delay);

    xml = "<dp><realtime>a</realtime></dp>".toScheduleXmlNode;
    assertThrown!(UnexpectedValueException!string)(xml.delay);

    xml = "<dp><realtime>1</realtime></dp>".toScheduleXmlNode;
    assert(xml.delay == dur!"seconds"(0));

    xml = "<dp><realtime>1</realtime><st><t></t></st></dp>".toScheduleXmlNode;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt></rt></st></dp>".toScheduleXmlNode;
    assert(xml.delay == dur!"seconds"(0));

    xml = "<dp><st><rt></rt><t></t></st></dp>".toScheduleXmlNode;
    assertThrown!AssertError(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt></rt><t></t></st></dp>".toScheduleXmlNode;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t></t></st></dp>".toScheduleXmlNode;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt></rt><t>0000</t></st></dp>".toScheduleXmlNode;
    assertThrown!DateTimeException(xml.delay);

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t>0000</t></st></dp>"
        .toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(0));

    xml = "<dp><realtime>1</realtime><st><rt>0001</rt><t>0000</t></st></dp>"
        .toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(1));

    xml = "<dp><realtime>1</realtime><st><rt>1753</rt><t>1751</t></st></dp>"
        .toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(2));

    xml = "<dp><realtime>1</realtime><st><rt>1010</rt><t>1000</t></st></dp>"
        .toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(10));

    xml = "<dp><realtime>1</realtime><st><rt>1301</rt><t>1242</t></st></dp>"
        .toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(19));

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t>1242</t></st></dp>"
        .toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(678));

    xml = "<dp><realtime>1</realtime><st><rt>0000</rt><t>2359</t></st></dp>"
        .toScheduleXmlNode;
    assert(xml.delay == dur!"minutes"(1));
}
