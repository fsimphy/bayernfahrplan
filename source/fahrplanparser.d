module fahrplanparser;

import std.algorithm : map, each, joiner, filter;
import std.array : empty, front;
import std.conv : to;
import std.datetime : dur, TimeOfDay, DateTimeException;
import std.string : format;

import std.experimental.xml;
import std.experimental.xml.dom;

import substitution;
import xmldecode : xmlDecode;

version (unittest)
{
    import fluent.asserts;
}

private:

enum departureNodeName = "dp";
enum timeNodeName = "t";
enum realTimeNodeName = "rt";
enum ISOTimeNodeName = "st";
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
    auto domBuilder = data.lexer.parser.cursor.domBuilder;
    domBuilder.setSource(data);
    domBuilder.buildRecursive;
    auto dom = domBuilder.getDocument;

    // dfmt off
    return dom.getElementsByTagName(departureNodeName).map!(dp => [
        "line" : dp.childNodes.filter!(node => node.nodeName == busNodeName)
                .map!(node => node.childNodes.filter!(node => node.nodeName == lineNodeName))
                .joiner.front.textContent,
        "direction" : dp.childNodes
                .filter!(node => node.nodeName == busNodeName)
                .map!(node => node.childNodes.filter!(node => node.nodeName == destinationNodeName))
                .joiner.front.textContent.xmlDecode.substitute,
        "departure" : "%02s:%02s".format(dp.departureTime.hour, dp.departureTime.minute),
        "delay" : dp.delay.total!"minutes".to!string 
            ]);
    // dfmt on
}

///
@system unittest
{
    `
    <?xml version="1.0" encoding="UTF-8"?>
    `.parsedFahrplan.empty.should.equal(true);

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

auto departureTime(string _timeNodeName = timeNodeName, T : Node!string)(T dp)
        if (isInputRange!(typeof(T.init.childNodes)))
in
{
    assert(dp.nodeName == departureNodeName);
}
body
{
    auto timeNodes = dp.childNodes.filter!(node => node.nodeName == ISOTimeNodeName)
        .map!(ISOTimeNode => ISOTimeNode.childNodes.filter!(node => node.nodeName == _timeNodeName)).joiner();

    if (timeNodes.empty)
        throw new CouldNotFindNodeException(_timeNodeName);
    import std.stdio : stdout, writeln;

    return TimeOfDay.fromISOString(timeNodes.front.textContent ~ "00");
}

@system unittest
{
    import std.exception : assertThrown;

    auto domBuilder = "".lexer.parser.cursor.domBuilder;
    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0000</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(0, 0));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0013</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(0, 13));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>1100</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(11, 00));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>1242</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(12, 42));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>2359</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.equal(TimeOfDay(23, 59));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>2400</t>
        </st>
    </dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0061</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>2567</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t></t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>0</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>00</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>000000</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>00:00</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <t>abcd</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.departureTime.should.throwException!DateTimeException;

}

import std.range.primitives : isInputRange;

auto delay(T : Node!string)(T dp) if (isInputRange!(typeof(T.init.childNodes)))
in
{
    assert(dp.nodeName == departureNodeName);
}
body
{
    auto useRealTimeNodes = dp.childNodes.filter!(node => node.nodeName == useRealTimeNodeName);
    if (useRealTimeNodes.empty)
        throw new CouldNotFindNodeException(useRealTimeNodeName);
    immutable useRealTimeString = useRealTimeNodes.front.textContent;
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
        catch (CouldNotFindNodeException e)
        {
            return dur!"minutes"(0);
        }
    }
    else
        throw new UnexpectedValueException!string(useRealTimeString, realTimeNodeName);
}

@system unittest
{
    auto domBuilder = "".lexer.parser.cursor.domBuilder;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>0</realtime>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime></realtime>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!(UnexpectedValueException!string);

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>2</realtime>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!(UnexpectedValueException!string);

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>a</realtime>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!(UnexpectedValueException!string);

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
    </dp>
    `);
    domBuilder.buildRecursive;
    assert(domBuilder.getDocument.getElementsByTagName(departureNodeName)
            .front.delay == dur!"minutes"(0));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <t></t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt></rt>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <st>
            <rt></rt>
            <t></t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!CouldNotFindNodeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt></rt>
            <t></t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t></t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt></rt>
            <t>0000</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.throwException!DateTimeException;

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t>0000</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(0));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0001</rt>
            <t>0000</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(1));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>1753</rt>
            <t>1751</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(2));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>1010</rt>
            <t>1000</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(10));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>1301</rt>
            <t>1242</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(19));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t>1242</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(678));

    domBuilder.setSource(`
    <?xml version="1.0" encoding="UTF-8"?>
    <dp>
        <realtime>1</realtime>
        <st>
            <rt>0000</rt>
            <t>2359</t>
        </st>
    </dp>
    `);
    domBuilder.buildRecursive;
    domBuilder.getDocument.getElementsByTagName(departureNodeName)
        .front.delay.should.equal(dur!"minutes"(1));
}
