module substitution;

public:

void loadSubstitutionFile(string fileName)
{
    import std.file : slurp, exists, isFile;
    import std.array : assocArray;
    import std.algorithm.iteration : each;

    if (fileName.exists && fileName.isFile)
    {
        auto data = slurp!(string, string)(fileName, `"%s" = "%s"`);
        map = (string[string]).init;
        data.each!(pair => map[pair[0]] = pair[1]);
        foreach (pair; data)
        {
            map[pair[0]] = pair[1];
        }
        map.rehash;
    }
    else
    {
        map = (string[string]).init;
    }
}

auto substitute(string s)
{
    return s in map ? map[s] : s;
}

private:

string[string] map;
