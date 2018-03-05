module xmlconstants;

enum departuresXPath = "/efa/dps/" ~ departureNodeName;

enum departureNodeName = "dp";
enum timeNodeName = "t";
enum dateNodeName = "da";
enum realTimeNodeName = "rt";

template timeXPath(string _timeNodeName = timeNodeName)
{
    enum timeXPath = "/st/" ~ _timeNodeName;
}

enum useRealTimeXPath = "/realtime";
enum lineXPath = "/m/nu";
enum directionXPath = "/m/des";
