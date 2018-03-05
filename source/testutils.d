module testutils;

import std.array : front;
import kxml.xml : readDocument;
import fahrplanparser : ScheduleXmlNode;

public auto toScheduleXmlNode(string input) {
    auto xml = input.readDocument.parseXPath("/dp").front;
    return ScheduleXmlNode(xml);
}
