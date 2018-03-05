module xmlparserexceptions;

private import std.format : format;

class UnexpectedValueException(T) : Exception
{
    this(T t, string node) @safe pure
    {
        super(`Unexpected value "%s" for node "%s"`.format(t, node));
    }
}

class CouldNotFindNodeException : Exception
{
    this(string node) @safe pure
    {
        super(`Could not find node "%s"`.format(node));
    }
}
