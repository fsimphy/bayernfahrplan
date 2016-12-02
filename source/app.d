import std.algorithm : filter, map, startsWith;
import std.array : array, empty, front, replace;
import std.conv : to;
import std.datetime : dur, TimeOfDay, Clock;
import std.getopt : defaultGetoptPrinter, getopt;
import std.json : JSONValue;
import std.regex : ctRegex, matchAll;
import std.stdio : File, stdout, writeln;
import std.string : strip;
import std.typecons : tuple;
import std.format : format;

import kxml.xml : readDocument, XmlNode;

import requests : postContent;

import substitution;

auto parseTime(in string input)
{
    auto matches = matchAll(input, ctRegex!(`(?P<hours>\d+):(?P<minutes>\d+)`));
    auto actualTime = TimeOfDay(matches.front["hours"].to!int, matches.front["minutes"].to!int);
    matches.popFront;
    if (!matches.empty)
    {
        auto expectedTime = TimeOfDay(matches.front["hours"].to!int,
                matches.front["minutes"].to!int);
        return tuple(expectedTime, actualTime - expectedTime);

    }
    return tuple(actualTime, dur!"minutes"(0));
}

auto getRowContents(XmlNode[] rows)
{
    return rows.map!(row => row.parseXPath("//td")[1 .. $ - 1].map!((column) {
            auto link = column.parseXPath("//a");
            if (!link.empty)
                return link.front.getCData.replace("...", "");
            return column.getCData;}));
}

void main(string[] args)
{
    string fileName;
    string busStop = "Universität Regensburg";
    string substitutionFileName = "replacement.txt";
    auto helpInformation = getopt(args,
            "file|f", "The file that the data is written to.", &fileName,
            "stop|s", "The bus stop for which to fetch data.", &busStop,
            "replacement-file|r", "The file that contais the direction name replacement info.", &substitutionFileName);
    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("Some information about the program.", helpInformation.options);
        return;
    }

    auto content = postContent("http://txt.bayern-fahrplan.de/textversion/bcl_abfahrtstafel",
            ["limit" : "20",
             "useRealtime" : "1",
             "name_dm" : busStop,
             "mode" : "direct",
             "type_dm" : "any",
             "itdLPxx_bcl" : "true"]);

    auto currentTime = Clock.currTime;
    loadSubstitutionFile(substitutionFileName);
    JSONValue j = ["time" : "%02s:%02s".format(currentTime.hour, currentTime.minute)];
    j.object["departures"] = readDocument(cast(string) content.data)
            .parseXPath(`//table[@id="departureMonitor"]/tbody/tr`)[1 .. $]
            .getRowContents
            .filter!(row => !row.empty)
            .map!(a => ["departure" : a[0].parseTime[0].to!string[0 .. $ - 3],
                        "delay" : a[0].parseTime[1].total!"minutes".to!string,
                        "line" : a[1],
                        "direction" : a[2].substitute])
            .array.JSONValue;

    if (fileName !is null)
    {
        auto output = File(fileName, "w");
        scope(exit) output.close;
        output.writeln(j.toPrettyString.replace("\\/", "/"));
    }
    else
    {
        j.toPrettyString.replace("\\/", "/").writeln;
    }

}
