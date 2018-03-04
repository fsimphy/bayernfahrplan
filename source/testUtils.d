module testutils;

import std.array : front;
import kxml.xml : readDocument;

public auto toScheduleXmlNode(string input) {
    auto xml = input.readDocument.parseXPath("/dp").front;
}
