module fahrplanparser;

import core.time : Duration;

import std.algorithm : map, filter;
import std.array : empty, front;
import std.conv : to;
import std.datetime;
import std.string : format;

import kxml.xml : XmlNode;

import substitution;
import scheduleXmlNode : ScheduleXmlNode;
import xmlconstants;

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
