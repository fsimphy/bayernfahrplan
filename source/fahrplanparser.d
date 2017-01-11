module fahrplanparser;

import std.algorithm : filter, map;
import std.array : empty, front, replace;
import std.conv : to;
import std.datetime : dur, TimeOfDay;
import std.regex : ctRegex, matchAll;
import std.string : strip;
import std.typecons : tuple, Tuple;

import kxml.xml : readDocument, XmlNode;

import substitution;

private:

enum ScheduleHeadings
{
    date,
    departure,
    line,
    direction,
    platform
}

public:

auto parsedFahrplan(in string data)
{
    // dfmt off
    return data.readDocument
        .parseXPath(`//table[@id="departureMonitor"]/tbody/tr`)[1 .. $]
        .getRowContents
        .filter!(row => !row.empty)
        .map!(a => ["departure" : a[0].parseTime[0].to!string[0 .. $ - 3],
                    "delay" : a[0].parseTime[1].total!"minutes".to!string,
                    "line" : a[1],
                    "direction" : a[2].substitute]);
    // dfmt on
}

private:

class BadTimeInputException : Exception
{
    this(string msg) @safe pure nothrow @nogc
    {
        super(msg);
    }

    this() @safe pure nothrow @nogc
    {
        this("");
    }
}

auto parseTime(in string input) @safe
{
    auto matches = matchAll(input, ctRegex!(`(?P<hours>\d{1,2}):(?P<minutes>\d{2})`));
    if (matches.empty)
        throw new BadTimeInputException();
    auto actualTime = TimeOfDay(matches.front["hours"].to!int, matches.front["minutes"].to!int);
    matches.popFront;
    if (!matches.empty)
    {
        auto expectedTime = TimeOfDay(matches.front["hours"].to!int,
                matches.front["minutes"].to!int);
        auto timeDiff = actualTime - expectedTime;

        if (timeDiff < dur!"minutes"(0))
            timeDiff = dur!"hours"(24) + timeDiff;

        return tuple(expectedTime, timeDiff);
    }
    return tuple(actualTime, dur!"minutes"(0));
}

@safe unittest
{
    import std.exception : assertThrown;

    assertThrown(parseTime(""));
    assertThrown(parseTime("lkeqf"));
    assertThrown(parseTime(":"));
    assertThrown(parseTime("00:0"));

    assert("00:00".parseTime == tuple(TimeOfDay(0, 0), dur!"minutes"(0)));
    assert("0:00".parseTime == tuple(TimeOfDay(0, 0), dur!"minutes"(0)));

    assert("00:00 00:00".parseTime == tuple(TimeOfDay(0, 0), dur!"minutes"(0)));

    assert("00:00 00:00 12:00".parseTime == tuple(TimeOfDay(0, 0), dur!"minutes"(0)));

    assert("12:3412:34".parseTime == tuple(TimeOfDay(12, 34), dur!"minutes"(0)));

    assert("ölqjfo12:34oieqf12:31ölqjf".parseTime == tuple(TimeOfDay(12, 31), dur!"minutes"(3)));

    assert("17:53 (planmäßig 17:51 Uhr)".parseTime == tuple(TimeOfDay(17, 51), dur!"minutes"(2)));

    assert("00:00 23:59".parseTime == tuple(TimeOfDay(23, 59), dur!"minutes"(1)));
}

auto getRowContents(XmlNode[] rows)
{
    return rows.map!(x => getRowContent(x));
}

auto getRowContent(XmlNode row)
{
    return row.parseXPath("//td")[ScheduleHeadings.departure .. ScheduleHeadings.direction + 1].map!(
            cell => stripLinks(cell));
}

auto stripLinks(XmlNode cell)
{
    auto links = cell.parseXPath("//a");
    if (links.empty)
    {
        return cell.getCData;
    }
    else
    {
        return links.front.getCData.replace("...", "");
    }
}

@system unittest
{
    auto foo = new XmlNode("foo");
    assert(foo.stripLinks == "");

    auto link = new XmlNode("a");
    link.setCData("test");
    foo.addChild(link);
    assert(foo.stripLinks == "test");

    link.setCData("test2...");
    assert(foo.stripLinks == "test2");

    auto bar = new XmlNode("bar");
    bar.setCData("test3");
    assert(bar.stripLinks == "test3");

    bar.addChild(link);
    assert(bar.stripLinks == "test2");

    auto baz = new XmlNode("baz");
    auto subNode = new XmlNode("subNode");
    baz.addChild(subNode);
    assert(baz.stripLinks == "");

    baz.addChild(link);
    assert(baz.stripLinks == "test2");

    baz.addCData("test4");
    assert(baz.stripLinks == "test2");

    baz.removeChild(link);
    assert(baz.stripLinks == "test4");
}
