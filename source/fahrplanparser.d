module fahrplanparser;

import dxml.dom : DOMEntity, parseDOM;
import dxml.util : normalize;

import fluent.asserts : should;

import std.algorithm : filter, joiner, map;
import std.conv : to;
import std.datetime : DateTimeException, dur, TimeOfDay, DateTime, Clock;
import std.string : format;

import substitution : substitute;

private:

enum efaNodeName = "efa";
enum departuresNodeName = "dps";
enum departureNodeName = "dp";
enum timeNodeName = "t";
enum dateNodeName = "da";
enum realTimeNodeName = "rt";
enum isoTimeNodeName = "st";
enum useRealTimeNodeName = "realtime";
enum lineNodeName = "nu";
enum destinationNodeName = "des";
enum busNodeName = "m";

const DateTime currentDateTime;

static this()
{
    version(unittest)
    {
        currentDateTime = DateTime.fromISOString("20180101T000000");
    }
    else
    {
        currentDateTime = Clock.currTime.to!DateTime;
    }
}

public:

/***********************************
* Parses the departure monitor data and returns it as an associative array.
* data is expected to contain valid XML as returned by queries sent to http://mobile.defas-fgi.de/beg/.
*/

auto parsedFahrplan(string data, int reachabilityThreshold = 0)
{// dfmt off
    return data.parseDOM.children
        .filter!(node => node.name == efaNodeName)
        .map!(efa => efa.children).joiner.filter!(node => node.name == departuresNodeName)
        .map!(dps => dps.children).joiner.filter!(node => node.name == departureNodeName)
        .filter!(dp => dp.isReachable(reachabilityThreshold))
        .map!(dp => [
            "line" : dp.children
                .filter!(node => node.name == busNodeName)
                .map!(busNodeName => busNodeName.children
                    .filter!(node => node.name == lineNodeName))
                .joiner.map!(node => node.children)
                .joiner.front.text,
            "direction" : dp.children
                .filter!(node => node.name == busNodeName)
                .map!(busNodeName => busNodeName.children
                    .filter!(node => node.name == destinationNodeName))
                .joiner.map!(node => node.children)
                .joiner.front.text.normalize.substitute,
            "departure" : "%02s:%02s".format(dp.departureTime.hour, dp.departureTime.minute),
            "delay" : dp.delay.total!"minutes".to!string]);
// dfmt on
}

///
@system
{
    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<efa>\n" ~
        "    <dps></dps>\n" ~
        "</efa>"
        // dfmt on
        ).parsedFahrplan.empty.should.equal(true);

        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<efa>\n" ~
        "    <dps>\n" ~
        "          <dp>\n" ~
        "            <realtime>1</realtime>\n" ~
        "            <st>\n" ~
        "                <t>1224</t>\n" ~
        "                <rt>1242</rt>\n" ~
        "                <da>20180101</da>\n" ~
        "            </st>\n" ~
        "            <m>\n" ~
        "                <nu>6</nu>\n" ~
        "                <des>Wernerwerkstraße</des>\n" ~
        "            </m>\n" ~
        "        </dp>\n" ~
        "    </dps>\n" ~
        "</efa>"
        //dfmt on
        ).parsedFahrplan.should.containOnly([["direction" : "Wernerwerkstraße",
                "line" : "6", "departure" : "12:24", "delay" : "18"]]);
    }

    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<efa>\n" ~
        "    <dps>\n" ~
        "          <dp>\n" ~
        "            <realtime>0</realtime>\n" ~
        "            <st>\n" ~
        "                <t>1224</t>\n" ~
        "                <da>20180101</da>\n" ~
        "            </st>\n" ~
        "            <m>\n" ~
        "                <nu>6</nu>\n" ~
        "                <des>Wernerwerkstraße</des>\n" ~
        "            </m>\n" ~
        "        </dp>\n" ~
        "    </dps>\n" ~
        "</efa>"
        // dfmt on
        ).parsedFahrplan.should.containOnly([["direction" : "Wernerwerkstraße",
                "line" : "6", "departure" : "12:24", "delay" : "0"]]);
    }

    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<efa>\n" ~
        "    <dps>\n" ~
        "          <dp>\n" ~
        "            <realtime>0</realtime>\n" ~
        "            <st>\n" ~
        "                <t>1224</t>\n" ~
        "                <da>20180101</da>\n" ~
        "            </st>\n" ~
        "            <m>\n" ~
        "                <nu>6</nu>\n" ~
        "                <des>Wernerwerkstraße</des>\n" ~
        "            </m>\n" ~
        "        </dp>\n" ~
        "          <dp>\n" ~
        "            <realtime>1</realtime>\n" ~
        "            <st>\n" ~
        "                <t>1353</t>\n" ~
        "                <da>20180101</da>\n" ~
        "                <rt>1356</rt>\n" ~
        "            </st>\n" ~
        "            <m>\n" ~
        "                <nu>11</nu>\n" ~
        "                <des>Burgweinting</des>\n" ~
        "            </m>\n" ~
        "        </dp>\n" ~
        "    </dps>\n" ~
        "</efa>"
        // dfmt on
        ).parsedFahrplan.should.containOnly([["direction" : "Wernerwerkstraße", "line" : "6",
                "departure" : "12:24", "delay" : "0"], ["direction" : "Burgweinting",
                "line" : "11", "departure" : "13:53", "delay" : "3"]]);
    }
}

private:

class UnexpectedValueException(T) : Exception
{
    this(T t,
        string node,
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable next = null) @safe pure nothrow
    {
        super(`Unexpected value "` ~ t.to!string ~`" for node "` ~ node ~ `"`,
        file, line, next);
    }
}

class CouldNotFindNodeWithContentException : Exception
{
    this(string node,
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable next = null) @safe pure nothrow
    {
        super(`Could not find node "` ~ node ~`"`,
        file, line, next);
    }
}

auto departureTime(string _timeNodeName = timeNodeName)(DOMEntity!string dp)
in
{
    assert(dp.name == departureNodeName);
}
do
{
    auto timeNodes = dp.children.filter!(node => node.name == isoTimeNodeName)
        .map!(ISOTimeNode => ISOTimeNode.children.filter!(node => node.name == _timeNodeName)).joiner.map!(
                node => node.children).joiner;

    if (timeNodes.empty)
        throw new CouldNotFindNodeWithContentException(_timeNodeName);

    return TimeOfDay.fromISOString(timeNodes.front.text ~ "00");
}

@system 
{
    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>0000</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.equal(TimeOfDay(0, 0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>0013</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.equal(TimeOfDay(0, 13));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>1100</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.equal(TimeOfDay(11, 00));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>1242</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.equal(TimeOfDay(12, 42));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>2359</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.equal(TimeOfDay(23, 59));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>2400</t>\n" ~
        "    </st>\n" ~
        "</dp>"  // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>0061</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>2567</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t></t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!CouldNotFindNodeWithContentException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>0</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>00</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>000000</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>00:00</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <t>abcd</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.departureTime.should.throwException!DateTimeException;
    }
}

auto departureDate(string _dateNodeName = dateNodeName)(DOMEntity!string dp)
in
{
    assert(dp.name == departureNodeName);
}
do
{
    import std.datetime.date : Date;
    auto dateNodes = dp.children.filter!(node => node.name == isoTimeNodeName)
        .map!(isoTimeNode => isoTimeNode.children.filter!(node => node.name == _dateNodeName))
        .joiner
        .map!(node => node.children)
        .joiner;
    
    if (dateNodes.empty)
    {
        throw new CouldNotFindNodeWithContentException(_dateNodeName);
    }

    return Date.fromISOString(dateNodes.front.text);
}

// ToDo: Unittests

auto delay(DOMEntity!string dp)
in
{
    assert(dp.name == departureNodeName);
}
do
{
    auto useRealTimeNodes = dp.children.filter!(node => node.name == useRealTimeNodeName)
        .map!(node => node.children).joiner;
    if (useRealTimeNodes.empty)
        throw new CouldNotFindNodeWithContentException(useRealTimeNodeName);
    immutable useRealTimeString = useRealTimeNodes.front.text;
    if (useRealTimeString == "0")
        return dur!"minutes"(0);
    else if (useRealTimeString == "1")
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
        catch (CouldNotFindNodeWithContentException e)
        {
            return dur!"minutes"(0);
        }
    }
    else
        throw new UnexpectedValueException!string(useRealTimeString, realTimeNodeName);
}

@system
{
    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>0</realtime>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime></realtime>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.throwException!(CouldNotFindNodeWithContentException);
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>2</realtime>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.throwException!(UnexpectedValueException!string);
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>a</realtime>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.throwException!(UnexpectedValueException!string);
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <t></t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt></rt>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <st>\n" ~
        "        <rt></rt>\n" ~
        "        <t></t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.throwException!CouldNotFindNodeWithContentException;
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt></rt>\n" ~
        "        <t></t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>0000</rt>\n" ~
        "        <t></t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt></rt>\n" ~
        "        <t>0000</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>0000</rt>\n" ~
        "        <t>0000</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(0));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>0001</rt>\n" ~
        "        <t>0000</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(1));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>1753</rt>\n" ~
        "        <t>1751</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(2));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>1010</rt>\n" ~
        "        <t>1000</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(10));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>1301</rt>\n" ~
        "        <t>1242</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(19));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>0000</rt>\n" ~
        "        <t>1242</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(678));
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<dp>\n" ~
        "    <realtime>1</realtime>\n" ~
        "    <st>\n" ~
        "        <rt>0000</rt>\n" ~
        "        <t>2359</t>\n" ~
        "    </st>\n" ~
        "</dp>"
        // dfmt on
        ).parseDOM.children.filter!(node => node.name == departureNodeName)
            .front.delay.should.equal(dur!"minutes"(1));
    }
}

bool isReachable(DOMEntity!string dp, in int reachabilityThreshold,
        in DateTime currentTime = currentDateTime)
{
    import std.datetime : minutes;

    auto reachingDuration = minutes(reachabilityThreshold);

    auto departureDateTime = DateTime(dp.departureDate, dp.departureTime);

    return departureDateTime - currentTime >= reachingDuration;
}

// TODO Unittests
