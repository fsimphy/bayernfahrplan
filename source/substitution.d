module substitution;

public:

void loadSubstitutionFile(string fileName)
{
    import std.file : slurp;
    import std.algorithm.iteration : each;
    auto data = slurp!(string, string)(fileName, `"%s" = "%s"`);
    map = (string[string]).init;
    data.each!(pair => map[pair[0]] = pair[1]);
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
