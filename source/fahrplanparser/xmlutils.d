module fahrplanparser.xmlutils;

private:
import dxml.dom : DOMEntity, parseDOM;
import fluent.asserts : should;
import std.algorithm.iteration : filter;

import std.array : empty, front, popFront;

import fahrplanparser.exceptions : CouldNotFindNodeWithContentException;

package:

auto getSubnodesWithName(T)(DOMEntity!T dom, string subnodeName)
in
{
    assert(subnodeName != "");
}
do {
    return dom.children
        .filter!(node => node.name == subnodeName);
}

@system
{
    unittest
    {
        auto nodes =
        (
        // dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>node1</n1>"
        // dfmt.on
        ).parseDOM.getSubnodesWithName("n1");

        nodes.empty.should.equal(false);
        nodes.front.name.should.equal("n1");
        nodes.popFront;
        nodes.empty.should.equal(true);
    }

    unittest
    {
        auto nodes =
        (
        // dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>text1</n2>\n" ~
        "   <n2>text2</n2>\n" ~
        "</n1>"
        // dfmt.on
        ).parseDOM.getSubnodesWithName("n1")
        .front
        .getSubnodesWithName("n2");

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
auto getFirstSubnodeWithName(T)(DOMEntity!T dom, string subnodeName)
in
{
    assert(subnodeName != "");
}
do
{
    auto childs = dom.getSubnodesWithName(subnodeName);
    if (childs.empty) {
        throw new CouldNotFindNodeWithContentException(subnodeName);
    }
    return childs.front;
}

@system
{
    unittest
    {
        (
        // dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>node1</n1>"
        // dfmt.on
        ).parseDOM.getFirstSubnodeWithName("n1")
        .name
        .should.equal("n1");
    }

    unittest
    {
        (
        // dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>node2</n2>\n" ~
        "</n1>"
        // dfmt.on
        ).parseDOM
        .getFirstSubnodeWithName("n1")
        .getFirstSubnodeWithName("n2")
        .name
        .should.equal("n2");
    }

    unittest
    {
        auto node =
        (
        // dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>node2-1</n2>\n" ~
        "   <n2>node2-2</n2>\n" ~
        "</n1>"
        // dfmt.on
        ).parseDOM
            .getFirstSubnodeWithName("n1")
            .getFirstSubnodeWithName("n2");
        node.name
            .should.equal("n2");
        node.children
            .front
            .text
            .should.equal("node2-1");
    }


    unittest
    {
        (
        // dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>\n" ~
        "   <n2>node2-1</n2>\n" ~
        "   <n2>node2-2</n2>\n" ~
        "</n1>"
        // dfmt.on
        ).parseDOM
            .getFirstSubnodeWithName("n3")
            .should.throwException!CouldNotFindNodeWithContentException;
    }
}

string extractText(T)(DOMEntity!T dom)
{
    auto childNodes = dom.children;
    if (childNodes.empty) {
        throw new CouldNotFindNodeWithContentException("text");
    }
    return childNodes.front.text;
}

@system
{
    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1>testText</n1>"
        //dfmt on
        ).parseDOM
        .getFirstSubnodeWithName("n1")
        .extractText
        .should.equal("testText");
    }

    unittest
    {
        (//dfmt off
        "<?xml version='1.0' encoding='UTF-8'?>\n" ~
        "<n1></n1>"
        //dfmt on
        ).parseDOM
        .getFirstSubnodeWithName("n1")
        .extractText
        .should.throwException!CouldNotFindNodeWithContentException;
    }
}
