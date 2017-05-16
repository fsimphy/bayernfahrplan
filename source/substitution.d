module substitution;

import std.file : slurp;
import std.meta : AliasSeq;
import std.traits : Parameters;

public:

/***********************************
* Loads a substitution dictonary from a file.
*/

void loadSubstitutionFile(alias slurpFun = slurp)(string fileName)
        if (is(Parameters!(slurpFun!(string, string)) == AliasSeq!(string, const char[])))
{
    import std.algorithm.iteration : each;

    map = (string[string]).init;
    slurpFun!(string, string)(fileName, `"%s" = "%s"`).each!(pair => map[pair[0]] = pair[1]);
}

///
@safe unittest
{
    import std.typecons : Tuple, tuple;

    static Tuple!(string, string)[] mockSlurpEmpty(Type1, Type2)(string filename, in char[] format)
    {
        return [];
    }

    loadSubstitutionFile!mockSlurpEmpty("");
    assert(map.length == 0);

    static Tuple!(string, string)[] mockSlurpEmptyEntry(Type1, Type2)(string filename,
            in char[] format)
    {
        return [tuple("", "")];
    }

    loadSubstitutionFile!mockSlurpEmptyEntry("");
    assert("" in map);
    assert(map.length == 1);
    assert(map[""] == "");

    static Tuple!(string, string)[] mockSlurpSingleEntry(Type1, Type2)(string filename,
            in char[] format)
    {
        return [tuple("foo", "bar")];
    }

    loadSubstitutionFile!mockSlurpSingleEntry("");
    assert("foo" in map);
    assert(map.length == 1);
    assert(map["foo"] == "bar");

    static Tuple!(string, string)[] mockSlurpMultipleEntries(Type1, Type2)(
            string filename, in char[] format)
    {
        return [tuple("", ""), tuple("0", "1"), tuple("Text in", "wird durch diesen ersetzt")];
    }

    loadSubstitutionFile!mockSlurpMultipleEntries("");
    assert("" in map);
    assert("0" in map);
    assert("Text in" in map);
    assert(map.length == 3);
    assert(map[""] == "");
    assert(map["0"] == "1");
    assert(map["Text in"] == "wird durch diesen ersetzt");
}

/***********************************
* Substitutes a string with its corresponding replacement, if one is available.
* Otherwise just returns the original string.
*/

auto substitute(string s) @safe nothrow
{
    return s in map ? map[s] : s;
}

///
@safe unittest
{
    map[""] = "";
    assert(substitute("") == "");

    map["a"] = "b";
    assert(substitute("a") == "b");

    map["Regensburg Danziger Freiheit"] = "Danziger Freiheit";
    assert(substitute("Regensburg Danziger Freiheit") == "Danziger Freiheit");

    map["Regensburg Danziger Freiheit"] = "Anderer Test";
    assert(substitute("Regensburg Danziger Freiheit") == "Anderer Test");

    assert(substitute("z") == "z");

    assert(substitute("Regensburg Hauptbahnhof") == "Regensburg Hauptbahnhof");
}

private:

string[string] map;
