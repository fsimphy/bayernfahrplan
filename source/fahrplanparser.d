module fahrplanparser;

import std.algorithm : map, each, joiner;
import std.array : empty, front;
import std.conv : to;
import std.datetime : dur, TimeOfDay, DateTimeException;
import std.string : format, replace;
import std.regex;

import std.experimental.xml;
import std.experimental.xml.dom : Node;

/* import kxml.xml : readDocument, XmlNode; */

import substitution;

private:

enum departureNodeName = "dp";
enum timeNodeName = "t";
enum realTimeNodeName = "rt";
enum ISOTimeNodeName = "st";
/*
enum departuresXPath = "/efa/dps/" ~ departureNodeName;
template timeXPath(string _timeNodeName = timeNodeName)
{
    enum timeXPath = "/st/" ~ _timeNodeName;
}

enum useRealTimeXPath = "/realtime";
enum lineXPath = "/m/nu";
enum directionXPath = "/m/des"; */

string regrep(string input, string pattern, string delegate(string) translator)
{
    string tmpdel(Captures!(string) m)
    {
        return translator(m.hit);
    }

    return std.regex.replace!(tmpdel)(input, regex(pattern, "g"));
}

string xmlDecode(string src)
{
    src = replace(src, "&lt;", "<");
    src = replace(src, "&gt;", ">");
    src = replace(src, "&apos;", "'");
    src = replace(src, "&quot;", "\"");
    // take care of decimal character entities
    src = regrep(src, "&#\\d{1,8};", (string m) {
        auto cnum = m[2 .. $ - 1];
        dchar dnum = cast(dchar) cnum.to!int;
        return quickUTF8(dnum);
    });
    // take care of hex character entities
    src = regrep(src, "&#[xX][0-9a-fA-F]{1,8};", (string m) {
        auto cnum = m[3 .. $ - 1];
        dchar dnum = hex2dchar(cnum);
        return quickUTF8(dnum);
    });
    src = replace(src, "&amp;", "&");
    return src;
}

// a quick dchar to utf8 conversion
string quickUTF8(dchar dachar)
{
    char[] ret;
    foreach (char r; [dachar])
    {
        ret ~= r;
    }
    return cast(string) ret;
}

// convert a hex string to a raw dchar
dchar hex2dchar(string hex)
{
    dchar res = 0;
    foreach (digit; hex)
    {
        res <<= 4;
        res |= toHVal(digit);
    }
    return res;
}

// convert a single hex digit to its raw value
private dchar toHVal(char digit)
{
    if (digit >= '0' && digit <= '9')
    {
        return digit - '0';
    }
    if (digit >= 'a' && digit <= 'f')
    {
        return digit - 'a' + 10;
    }
    if (digit >= 'A' && digit <= 'F')
    {
        return digit - 'A' + 10;
    }
    return 0;
}

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
    import std.stdio : writeln;

    return dom.getElementsByTagName("dp").map!(dp => ["line" : dp.getElementsByTagName("nu")
            .front.textContent, "direction" : dp.getElementsByTagName("des")
            .front.textContent.xmlDecode.substitute, "departure"
            : "%02s:%02s".format(dp.departureTime.hour, dp.departureTime.minute)]);

    // dfmt off
/*     return data.readDocument
        .parseXPath(departuresXPath)
        .map!(dp => ["departure" : "%02s:%02s".format(dp.departureTime.hour, dp.departureTime.minute),
                     "delay" : dp.delay.total!"minutes".to!string,
                     "line": dp.parseXPath(lineXPath).front.getCData,
                     "direction": dp.parseXPath(directionXPath).front.getCData.substitute]); */
    // dfmt on
}

///
/* @system unittest
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
} */

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

auto departureTime(string _timeNodeName = timeNodeName, T)(T dp)
in
{
    assert(dp.nodeName == departureNodeName);
}
body
{
    auto timeNodes = dp.getElementsByTagName(ISOTimeNodeName)
        .map!(ISOTimeNode => ISOTimeNode.getElementsByTagName(_timeNodeName)).joiner();

    if (timeNodes.empty)
        throw new CouldNotFindeNodeException(_timeNodeName);
    import std.stdio : writeln;

    return TimeOfDay.fromISOString(timeNodes.front.textContent ~ "00");
}

@system unittest
{
    import std.exception : assertThrown;

    auto domBuilder = "".lexer.parser.cursor.domBuilder;
    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>0000</t></st></dp>`);
    domBuilder.buildRecursive;
    assert(domBuilder.getDocument.getElementsByTagName(departureNodeName)
            .front.departureTime == TimeOfDay(0, 0));

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>0013</t></st></dp>`);
    domBuilder.buildRecursive;
    assert(domBuilder.getDocument.getElementsByTagName(departureNodeName)
            .front.departureTime == TimeOfDay(0, 13));

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>1100</t></st></dp>`);
    domBuilder.buildRecursive;
    assert(domBuilder.getDocument.getElementsByTagName(departureNodeName)
            .front.departureTime == TimeOfDay(11, 00));

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>1242</t></st></dp>`);
    domBuilder.buildRecursive;
    assert(domBuilder.getDocument.getElementsByTagName(departureNodeName)
            .front.departureTime == TimeOfDay(12, 42));

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>2359</t></st></dp>`);
    domBuilder.buildRecursive;
    assert(domBuilder.getDocument.getElementsByTagName(departureNodeName)
            .front.departureTime == TimeOfDay(23, 59));

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>2400</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>0061</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>2567</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t></t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>0</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>00</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>000000</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>00:00</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

    domBuilder.setSource(`<?xml version="1.0" encoding="UTF-8"?><dp><st><t>abcd</t></st></dp>`);
    domBuilder.buildRecursive;
    assertThrown!DateTimeException(domBuilder.getDocument.getElementsByTagName(
            departureNodeName).front.departureTime);

}
/*
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
 */
