module bayernfahrplan.fahrplanparser.data.exceptions;

import std.json : JSONValue, JSON_TYPE;
import std.format : format;

class NoSuchKeyException : Throwable
{
    this(JSONValue payload, string key, string file = __FILE__,
            size_t line = __LINE__, Throwable nextInChain = null) @trusted
    {
        string msg = format!("No key %s in data.\nData was:\n%s")(key, payload);
        super(msg, file, line, nextInChain);
    }
}

class UnexpectedDataException : Throwable
{
    this(JSONValue payload, string key, JSON_TYPE[] expectedTypes, JSON_TYPE actualType,
            string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) @trusted
    {
        import std.array : array, front, popFront, join;
        import std.algorithm.iteration : map;
        import std.conv : to;

        string actualTypeName = actualType.to!string;
        string expectedTypeNames = expectedTypes.map!(to!string).join(", ");

        string msg = format!(
                "Data with key %1$s has been %2$s, but should have been one of %3$s.\nData was %4$s")(key,
                actualTypeName, expectedTypeNames, payload);
        super(msg, file, line, nextInChain);
    }
}
