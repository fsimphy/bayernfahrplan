module fahrplanparser.xmlutils;

private:
import dxml.dom : DOMEntity, parseDOM;
import fluent.asserts : should;
import std.algorithm.iteration : filter;

import std.array : empty, front, popFront;

import fahrplanparser.exceptions : CouldNotFindNodeWithContentException;

import std.range.primitives : isInputRange, ElementType;

package:

auto getAllSubnodes(T = string, U)(U domRange)
        if (isInputRange!U && is(ElementType!U == DOMEntity!T))
{
    import std.algorithm.iteration : map, joiner;

    return domRange.map!(node => node.children).joiner;
}

@system
{
    unittest
    {
        auto subnodes = (//dfmt off
        "<?xml version='1.0' charset='UTF-8'?>" ~
        "<n1>\n" ~
        "   <n2>text1</n2>\n" ~
        "   <n3>text2</n3>\n" ~
        "</n1>"
        //dfmt on
        ).parseDOM.children.getAllSubnodes;

        subnodes.empty.should.equal(false);
        auto node1 = subnodes.front;
        node1.name.should.equal("n2");
        subnodes.popFront;
        subnodes.empty.should.equal(false);
        auto node2 = subnodes.front;
        node2.name.should.equal("n3");
        subnodes.popFront;
        subnodes.empty.should.equal(true);
    }
}

auto getSubnodesWithName(string subnodeName, T = string, U)(U domRange)
        if (isInputRange!U && is(ElementType!U == DOMEntity!T))
{
    import std.algorithm.iteration : map, joiner;

    return domRange.map!(domNode => domNode.getSubnodesWithName!subnodeName).joiner;
}

@system
{
    unittest
    {
        auto subnodes = (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>\n" ~
        "       <sub>text1</sub>\n" ~
        "   </n2>\n" ~
        "   <n2>\n" ~
        "       <sub>text2</sub>\n" ~
        "   </n2>\n" ~
        "</n1>"
        //dfmt on
        ).parseDOM.children.front.getSubnodesWithName!"n2".getSubnodesWithName!"sub";

        subnodes.empty.should.equal(false);
        auto node1 = subnodes.front;
        node1.name.should.equal("sub");
        node1.extractText.should.equal("text1");
        subnodes.popFront;

        subnodes.empty.should.equal(false);
        auto node2 = subnodes.front;
        node2.name.should.equal("sub");
        node2.extractText.should.equal("text2");

        subnodes.popFront;
        subnodes.empty.should.equal(true);
    }
}

auto getSubnodesWithName(string subnodeName, T)(DOMEntity!T dom)
        if (subnodeName != "")
{
    return dom.children.filter!(node => node.name == subnodeName);
}

@system
{
    unittest
    {
        auto nodes = (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>node1</n1>"
        // dfmt on
        ).parseDOM.getSubnodesWithName!"n1";

        nodes.empty.should.equal(false);
        nodes.front.name.should.equal("n1");
        nodes.popFront;
        nodes.empty.should.equal(true);
    }

    unittest
    {
        auto nodes = (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>text1</n2>\n" ~
        "   <n2>text2</n2>\n" ~
        "</n1>"
        // dfmt on
        ).parseDOM.getSubnodesWithName!"n1".front.getSubnodesWithName!"n2";

        nodes.empty.should.equal(false);
        auto node2_1 = nodes.front;
        node2_1.name.should.equal("n2");
        node2_1.children.front.text.should.equal("text1");

        nodes.popFront;
        auto node2_2 = nodes.front;
        node2_2.name.should.equal("n2");
        node2_2.children.front.text.should.equal("text2");

        nodes.popFront;
        nodes.empty.should.equal(true);
    }
}

/**
 * Fetches the first (direct) subnode with a given name.
 * If none is found, throws a CouldNotFindNodeWithContentException.
 */
auto getFirstSubnodeWithName(string subnodeName, T)(DOMEntity!T dom)
        if (subnodeName != "")
{
    auto childs = dom.getSubnodesWithName!subnodeName;
    if (childs.empty)
    {
        throw new CouldNotFindNodeWithContentException(subnodeName);
    }
    return childs.front;
}

@system
{
    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>node1</n1>"
        // dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n1".name.should.equal("n1");
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>node2</n2>\n" ~
        "</n1>"
        // dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n1".getFirstSubnodeWithName!"n2".name.should.equal(
                "n2");
    }

    unittest
    {
        auto node = (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>node2-1</n2>\n" ~
        "   <n2>node2-2</n2>\n" ~
        "</n1>"
        // dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n1".getFirstSubnodeWithName!"n2";
        node.name.should.equal("n2");
        node.children.front.text.should.equal("node2-1");
    }

    unittest
    {
        (// dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>node2-1</n2>\n" ~
        "   <n2>node2-2</n2>\n" ~
        "</n1>"
        // dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n3".should
            .throwException!CouldNotFindNodeWithContentException;
    }
}

string extractText(T)(DOMEntity!T dom)
{
    import dxml.util : normalize, stripIndent;

    auto childNodes = dom.children;
    if (childNodes.empty)
    {
        throw new CouldNotFindNodeWithContentException("text");
    }
    return childNodes.front.text.normalize.stripIndent;
}

@system
{
    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>testText</n1>"
        //dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n1".extractText.should.equal("testText");
    }

    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "    testText\n" ~
        "</n1>"
        //dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n1".extractText.should.equal("testText");
    }

    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "    testText1\n" ~
        "    testText2\n" ~
        "</n1>\n"
        //dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n1".extractText.should.equal("testText1\ntestText2");
    }

    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1></n1>"
        //dfmt on
        ).parseDOM.getFirstSubnodeWithName!"n1".extractText.should
            .throwException!CouldNotFindNodeWithContentException;
    }
}
