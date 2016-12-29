import std.getopt : defaultGetoptPrinter, getopt;
import std.stdio : File, stdout, writeln;

import requests : postContent;

import fahrplanparser;

import substitution;

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

    loadSubstitutionFile(substitutionFileName);

    auto output = (cast(string) content.data).parseFahrplan;
    if (fileName !is null)
    {
        auto outfile = File(fileName, "w");
        scope(exit) outfile.close;
        outfile.writeln(output);
    }
    else
    {
        output.writeln;
    }

}
