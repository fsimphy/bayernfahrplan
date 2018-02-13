module fahrplanparser;

import std.algorithm : map, joiner, filter;
import std.array : empty, front;
import std.conv : to;
import std.datetime : dur, TimeOfDay, DateTimeException;
import std.string : format;

import dxml.dom;
import dxml.util : normalize;
import dxml.parser : XMLParsingException;

version (unittest)
{
    import fluent.asserts;
}

import substitution;

private:

enum efaNodeName = "efa";
enum departuresNodeName = "dps";
enum departureNodeName = "dp";
enum timeNodeName = "t";
enum realTimeNodeName = "rt";
enum isoTimeNodeName = "st";
enum useRealTimeNodeName = "realtime";
enum lineNodeName = "nu";
enum destinationNodeName = "des";
enum busNodeName = "m";

public:

/***********************************
* Parses the departure monitor data and returns it as an associative array.
* data is expected to contain valid XML as returned by queries sent to http://mobile.defas-fgi.de/beg/.
*/

auto parsedFahrplan(string data)
{
    return data.parseDOM!simpleXML.children.filter!(node => node.name == efaNodeName)
        .map!(efa => efa.children).joiner.filter!(node => node.name == departuresNodeName)
        .map!(dps => dps.children).joiner.filter!(node => node.name == departureNodeName)
        .map!(dp => ["line" : dp.children.filter!(node => node.name == busNodeName)
                .map!(busNodeName => busNodeName.children.filter!(node => node.name == lineNodeName)).joiner.map!(
                    node => node.children).joiner.front.text,
                "direction" : dp.children.filter!(node => node.name == busNodeName)
                .map!(busNodeName => busNodeName.children.filter!(
                    node => node.name == destinationNodeName)).joiner.map!(node => node.children)
                .joiner.front.text.normalize.substitute, "departure"
                : "%02s:%02s".format(dp.departureTime.hour, dp.departureTime.minute),
                "delay" : dp.delay.total!"minutes".to!string]);
}

///
@system unittest
{
    `
    <?xml version="1.0" encoding="UTF-8"?>
    <efa>
        <dps></dps>
    </efa>
    `.parsedFahrplan.empty.should.equal(true);

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <efa>
        <dps>
            <dp>
                <realtime>1</realtime>
                <st>
                    <t>1224</t>
                    <rt>1242</rt>
                </st>
                <m>
                    <nu>6</nu>
                    <des>Wernerwerkstraße</des>
                </m>
            </dp>
        </dps>
    </efa>
    `.parsedFahrplan.should.containOnly([["direction" : "Wernerwerkstraße",
            "line" : "6", "departure" : "12:24", "delay" : "18"]]);

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <efa>
        <dps>
            <dp>
                <realtime>0</realtime>
                <st>
                    <t>1224</t>
                </st>
                <m>
                    <nu>6</nu>
                    <des>Wernerwerkstraße</des>
                </m>
            </dp>
        </dps>
    </efa>
    `.parsedFahrplan.should.containOnly([["direction" : "Wernerwerkstraße",
            "line" : "6", "departure" : "12:24", "delay" : "0"]]);

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <efa>
        <dps>
            <dp>
                <realtime>0</realtime>
                <st>
                    <t>1224</t>
                </st>
                <m>
                    <nu>6</nu>
                    <des>Wernerwerkstraße</des>
                </m>
            </dp>
            <dp>
                <realtime>1</realtime>
                <st>
                    <t>1353</t>
                    <rt>1356</rt>
                </st>
                <m>
                    <nu>11</nu>
                    <des>Burgweinting</des>
                </m>
            </dp>
        </dps>
    </efa>
    `.parsedFahrplan.should.containOnly([["direction" : "Wernerwerkstraße", "line" : "6",
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

class CouldNotFindNodeException : Exception
{
    this(string node) @safe pure
    {
        super(`Could not find node "%s"`.format(node));
    }
}

class CouldNotFindNodeWithContentException : Exception
{
    this(string node) @safe pure
    {
        super(`Could not find node "%s"`.format(node));
    }
}

auto departureTime(string _timeNodeName = timeNodeName, T)(T dp)
in
{
    assert(dp.name == departureNodeName);
}
body
{
    import std.stdio : writeln;
    import std.traits : fullyQualifiedName;

    auto timeNodes = dp.children.filter!(node => node.name == isoTimeNodeName)
        .map!(ISOTimeNode => ISOTimeNode.children.filter!(node => node.name == _timeNodeName)).joiner.map!(
                node => node.children).joiner;

    if (timeNodes.empty)
        throw new CouldNotFindNodeWithContentException(_timeNodeName);

    return TimeOfDay.fromISOString(timeNodes.front.text ~ "00");
}

@system unittest
{
    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0000</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(0, 0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0013</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(0, 13));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>1100</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(11, 00));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>1242</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(12, 42));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>2359</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(23, 59));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>2400</t>
        </st>
    </dp>`.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0061</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>2567</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t></t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!CouldNotFindNodeWithContentException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>00</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>000000</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>00:00</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>abcd</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;
}

auto delay(T)(T dp)
in
{
    assert(dp.name == departureNodeName);
}
body
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

@system unittest
{
    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>0</realtime>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime></realtime>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.throwException!(CouldNotFindNodeWithContentException);

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>2</realtime>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.throwException!(UnexpectedValueException!string);

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>a</realtime>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.throwException!(UnexpectedValueException!string);

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <t></t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt></rt>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <rt></rt>
            <t></t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.throwException!CouldNotFindNodeWithContentException;

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt></rt>
            <t></t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t></t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt></rt>
            <t>0000</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t>0000</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0001</rt>
            <t>0000</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(1));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>1753</rt>
            <t>1751</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(2));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>1010</rt>
            <t>1000</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(10));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>1301</rt>
            <t>1242</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(19));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t>1242</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(678));

    `
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t>2359</t>
        </st>
    </dp>
    `.parseDOM!simpleXML.children.filter!(node => node.name == departureNodeName)
        .front.delay.should.equal(dur!"minutes"(1));
}
