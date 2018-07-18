module bayernfahrplan.fahrplanparser.data.fieldnames;

/**
 * Contains mappings from easy to understand field names to the actual keys used in the JSON data.
 */
enum Fields : string
{
    departures = "departures",
    lineInformation = "mode",
    destination = "destination",
    realtime = "realtime",
    delay = "delay",
    lineNumber = "number",
    dateTimes = "stamp",
    date = "date",
    time = "time",
    realtimeDate = "rtDate",
    realtimeTime = "rtTime",
    currentDateTime = "now"
}
