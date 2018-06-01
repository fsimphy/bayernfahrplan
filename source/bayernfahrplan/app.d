module bayernfahrplan.app;

import bayernfahrplan.fahrplanparser.substitution : loadSubstitutionFile;

import requests : getContent;

import std.array : array, replace;
import std.conv : to;
import std.datetime : DateTime;

import std.file : exists, isFile;
import std.format : format;
import std.getopt : defaultGetoptPrinter, getopt;
import std.json : JSONValue, parseJSON;
import std.stdio : File, writeln;

private:
enum ver = "v0.1.1";
enum programName = "bayernfahrplan";

enum baseURL = "http://mobile.defas-fgi.de/beg/json/";
enum departureMonitorRequest = "XML_DM_REQUEST";

public:
void main(string[] args)
{
    string fileName;
    string busStop = "Regensburg Universität";
    string substitutionFileName = "replacement.txt";
    int reachabilityThreshold;
    bool versionWanted;
    // dfmt off
    auto helpInformation = getopt(args,
        "file|f", "The file that the data is written to.", &fileName,
        "stop|s", "The bus stop for which to fetch data.", &busStop,
        "replacement-file|r", "The file that contais the direction name replacement info.", &substitutionFileName,
        "version|v", "Display the version of this program.", &versionWanted,
        "walking-time|w", "Time (in minutes) to reach the station. Departures within this duration won't get printed.",
            &reachabilityThreshold);
    // dfmt on

    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("Usage: bayernfahrplan [options]\n\n Options:",
                helpInformation.options);
        return;
    }

    if (versionWanted)
    {
        import std.stdio : writeln;

        writeln(programName, " ", ver);
        return;
    }

    // dfmt off
    auto content = getContent(baseURL ~ departureMonitorRequest,
        ["outputFormat" : "XML",
         "language" : "de",
         "stateless" : "1",
         "type_dm" : "stop",
         "name_dm" : busStop,
         "useRealtime" : "1",
         "mode" : "direct",
         "ptOptionActive" : "1",
         "mergeDep" : "1",
         "limit" : "20",
         "deleteAssignedStops_dm" : "1"]).to!string.parseJSON;
    // dfmt on

    if (substitutionFileName.exists && substitutionFileName.isFile)
    {
        loadSubstitutionFile(substitutionFileName);
    }

    auto currentTime = DateTime.fromISOExtString(content["now"].str);
    JSONValue j = ["time" : "%02s:%02s".format(currentTime.hour, currentTime.minute)];

    import bayernfahrplan.fahrplanparser.json.jsonparser : parseJsonFahrplan;

    import std.json : JSONValue, toJSON;
    import std.algorithm : map, each;
    import bayernfahrplan.fahrplanparser.data.departuredata : DepartureData, toJson;

    auto fahrplanData = content.parseJsonFahrplan;

    auto departures = fahrplanData.map!(dp => dp.toJson).array.JSONValue;
    j.object["departures"] = departures;

    auto output = j.toPrettyString.replace("\\/", "/");
    if (fileName !is null)
    {
        auto outfile = File(fileName, "w");
        scope (exit)
            outfile.close;
        outfile.writeln(output);
    }
    else
    {
        output.writeln;
    }
}
