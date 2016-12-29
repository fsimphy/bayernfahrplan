module substitution;

public:

void loadSubstitutionFile(string fileName)
{
    import std.file : slurp, exists, isFile;
    import std.algorithm.iteration : each;

    if (fileName.exists && fileName.isFile)
    {
        auto data = slurp!(string, string)(fileName, `"%s" = "%s"`);
        map = (string[string]).init;
        data.each!(pair => map[pair[0]] = pair[1]);
    }
    else
    {
        map = (string[string]).init;
    }
}

auto substitute(string s) @safe nothrow
{
    return s in map ? map[s] : s;
}

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
