module bayernfahrplan.fahrplanparser.xml.xmlexceptions;

private:
import std.conv : to;

package:
class UnexpectedValueException(T) : Exception
{
    this(T t, string node, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @safe pure nothrow
    {
        super(`Unexpected value "` ~ t.to!string ~ `" for node "` ~ node ~ `"`, file, line, next);
    }
}

class CouldNotFindNodeWithContentException : Exception
{
    this(string node, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @safe pure nothrow
    {
        super(`Could not find node "` ~ node ~ `"`, file, line, next);
    }
}
