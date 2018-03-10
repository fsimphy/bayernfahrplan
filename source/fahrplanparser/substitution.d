module fahrplanparser.substitution;

import fluent.asserts;

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
@system unittest
{
    import std.typecons : Tuple, tuple;

    static Tuple!(string, string)[] mockSlurpEmpty(Type1, Type2)(string, in char[])
    {
        return [];
    }

    loadSubstitutionFile!mockSlurpEmpty("");
    map.length.should.equal(0);
}

///
@system unittest
{
    import std.typecons : Tuple, tuple;

    static Tuple!(string, string)[] mockSlurpEmptyEntry(Type1, Type2)(string, in char[])
    {
        return [tuple("", "")];
    }

    loadSubstitutionFile!mockSlurpEmptyEntry("");
    map.keys.should.containOnly([""]);
    map[""].should.equal("");
}

///
@system unittest
{
    import std.typecons : Tuple, tuple;

    static Tuple!(string, string)[] mockSlurpSingleEntry(Type1, Type2)(string, in char[])
    {
        return [tuple("foo", "bar")];
    }

    loadSubstitutionFile!mockSlurpSingleEntry("");
    map.keys.should.containOnly(["foo"]);
    map["foo"].should.equal("bar");
}

///
@system unittest
{
    import std.typecons : Tuple, tuple;

    static Tuple!(string, string)[] mockSlurpMultipleEntries(Type1, Type2)(string, in char[])
    {
        return [tuple("", ""), tuple("0", "1"), tuple("Text in", "wird durch diesen ersetzt")];
    }

    loadSubstitutionFile!mockSlurpMultipleEntries("");
    map.keys.should.containOnly(["", "0", "Text in"]);
    map[""].should.equal("");
    map["0"].should.equal("1");
    map["Text in"].should.equal("wird durch diesen ersetzt");
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
@system unittest
{
    map = (string[string]).init;
    map[""] = "";
    substitute("").should.equal("");
}

///
@system unittest
{
    map = (string[string]).init;
    map["a"] = "b";
    substitute("a").should.equal("b");
}

///
@system unittest
{
    map = (string[string]).init;
    map["Regensburg Danziger Freiheit"] = "Danziger Freiheit";
    substitute("Regensburg Danziger Freiheit").should.equal("Danziger Freiheit");
}

///
@system unittest
{
    map = (string[string]).init;
    map["Regensburg Danziger Freiheit"] = "Anderer Test";
    substitute("Regensburg Danziger Freiheit").should.equal("Anderer Test");
}

///
@system unittest
{
    map = (string[string]).init;
    substitute("z").should.equal("z");
}

///
@system unittest
{
    map = (string[string]).init;
    substitute("Regensburg Hauptbahnhof").should.equal("Regensburg Hauptbahnhof");
}

private:

string[string] map;
