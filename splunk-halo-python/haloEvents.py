#!/usr/bin/python
import sys
import platform
import os
import atexit

import cpapi
import cputils

# checks for version 2.6 or 2.7, earlier or later versions may not work
cputils.checkPythonVersion()

import os.path
import json

# Here, we simultaneously check for which OS (all non-Windows OSs are treated equally) we have.
isWindows = True
if (platform.system() != "Windows"):
    isWindows = False

# Now we check for whether the extra modules needed for syslog functionality are present.
syslogAvailable = True
try:
    if (isWindows):
        import remote_syslog
    else:
        import syslog
except ImportError:
    syslogAvailable = False

# global vars
events_per_page = 100
oneEventPerLine = True
lastTimestamp = None
verbose = False
configFilename = "haloEvents.config"
authFilenameDefault = "haloEvents.auth"
authFilenameList = []
timestampPerAccount = {}  # indexed by .auth file prefix, returns ISO-8601 timestamp
# path to the lock file depends on OS
if (platform.system() != "Windows"):
    pidFilename = "/tmp/haloEvents.lock"
else:
    pidFilename = "/haloEvents.lock"
outputFormat = "json-file"
outputDestination = None
syslogOpen = False
outfp = None
fileAppend = True
configDir = None


def processCmdLineArgs(argv):
    """ Process the script-specific command line arguments.

        A description of these arguments can be found in the printUsage() function.
    """
    global oneEventPerLine, verbose, outputFormat, outputDestination, lastTimestamp, configDir
    argsOK = True
    for arg in argv:
        if ((arg == '-?') or (arg == "-h")):
            printUsage(os.path.basename(argv[0]))
            return True
        elif ((arg == '-b') or (arg == '--one-batch-per-line')):
            oneEventPerLine = False
        elif (arg == '-v'):
            verbose = True
        elif (arg.startswith('--starting=')):
            lastTimestamp = arg[11:]
            (ok, error) = cputils.verifyISO8601(lastTimestamp)
            if not ok:
                print >> sys.stderr, error
                return True
        elif (arg.startswith('--auth=')):
            filename = arg[7:]
            if len(authFilenameList) > 0:
                print >> sys.stderr, "Error: Only one auth filename allowed"
                return True
            else:
                authFilenameList.append(filename)
        elif (arg.startswith('--cfgdir=') or arg.startswith('--configdir=')):
            i = arg.index('=') + 1
            configDir = arg[i:]
        elif (arg.startswith('--jsonfile=')):
            outputFormat = 'json-file'
            outputDestination = arg[11:]
        elif (arg.startswith('--kvfile=')):
            outputFormat = 'kv-file'
            outputDestination = arg[9:]
        elif (arg.startswith('--kv')):
            outputFormat = 'kv-file'
            outputDestination = None
        elif (arg.startswith('--txtsyslog')):
            if (syslogAvailable):
                if (arg.startswith('--txtsyslog=')):
                    outputFormat = 'txt-file'
                    outputDestination = arg[12:]
                else:
                    outputFormat = 'txt-syslog'
                    outputDestination = 'localhost'
            else:
                syslogNotAvailable()
        elif (arg.startswith('--kvsyslog')) and (not isWindows):
            if (syslogAvailable):
                outputFormat = 'kv-syslog'
                outputDestination = 'localhost'
            else:
                syslogNotAvailable()
        elif (arg != argv[0]):
            print >> sys.stderr, "Unrecognized argument: %s" % arg
            argsOK = False
    if not argsOK:
        print >> sys.stderr, "Run \"%s -h\" to see usage info." % os.path.basename(argv[0])
        return True
    if (outputFormat == None):
        print >> sys.stderr, "No output type selected, must choose one"
        printUsage(argv[0])
        return True
    else:
        return False


def syslogNotAvailable():
    """ Print error message listing missing modules for syslog functionality.
    """
    print >> sys.stderr, "Syslog functions not available. To enable them, obtain the following module:"
    if (isWindows):
        print >> sys.stderr, "  remote_syslog.py"
    else:
        print >> sys.stderr, "  cpsyslog.py (syslog should be available as part of Python)"
    sys.exit(1)


def openOutput():
    """ Open the socket/file/syslog-connection/whatever to which output is sent.
    """
    global outputFormat, outputDestination, syslogOpen, outfp, fileAppend
    if (outputFormat.endswith('-syslog')):
        if (not syslogOpen):
            if not isWindows:
                syslog.openlog('cpapi', 0, syslog.LOG_USER)
            else:
                remote_syslog.openlog()
            syslogOpen = True
    elif (outputFormat.endswith('-file')):
        if ((outfp == None) and (outputDestination != None)):
            if (fileAppend):
                mode = 'a'
            else:
                mode = 'w+'
            outfp = open(outputDestination, mode)


def processExit():
    """ Handles any tasks which must be done no matter how we exit.

        This code is called no matter how we exit, whether by sys.exit() or
        returning from main body of code. So any code that needs to be executed,
        regardless of why we exit, should be added here.
    """
    global pidFilename, syslogOpen
    try:
        if (syslogOpen):
            if not isWindows:
                syslog.closelog()
            else:
                remote_syslog.closelog()
        os.remove(pidFilename)
    except:
        if (os.path.exists(pidFilename)):
            print >> sys.stderr, "Unable to clean up lock file %s, clean up manually" % pidFilename


def printUsage(progName):
    """ Prints the program usage.

        Lists all accepted command line arguments, and a short description of each one.
    """
    print >> sys.stderr, "Usage: %s [<flag>]... " % progName
    print >> sys.stderr, "Where <flag> is one of:"
    print >> sys.stderr, "-h\t\t\tThis message"
    print >> sys.stderr, "--auth=<file>\t\tSpecify a file containing ID/secret pairs (up to 5)"
    print >> sys.stderr, "--starting=<time>\tSpecify start of event time range in ISO-8601 format"
    print >> sys.stderr, "--configdir=<dir>\tSpecify directory for config files (saved timestamps)"
    print >> sys.stderr, "--jsonfile=<filename>\tWrite raw JSON to file with given filename"
    print >> sys.stderr, "--kv\t\t\tWrite key/value pairs to standard output (terminal)"
    print >> sys.stderr, "--kvfile=<filename>\tWrite key/value pairs to file with given filename"
    if not isWindows:
        if (syslogAvailable):
            print >> sys.stderr, "--txtsyslog\t\tWrite general text to local syslog daemon"
    else:
        if (syslogAvailable):
            print >> sys.stderr, "--txtsyslog[=<file>]\tWrite general text to local syslog daemon or file"
    if (syslogAvailable):
        if not isWindows:
            print >> sys.stderr, "--kvsyslog\t\tWrite key/value pairs to local syslog daemon"
    print >> sys.stderr, "The default event output format is JSON to standard output (terminal)"


def processConfigFile(filename):
    """ Process the config file.

        Currently, the only configuration item is the timestamp when the program
        was last run, and thus the earliest possible timestamp of events we should process.
    """
    timestampMap = {}
    if (not os.path.exists(filename)):
        # print >> sys.stderr, "Config file %s not found" % filename
        return timestampMap
    fp = open(filename)
    lines = fp.readlines()
    fp.close()
    for line in lines:
        str = line.strip()
        if not str.startswith("#"):
            fields = str.split("|")
            if (len(fields) == 2):
                timestampMap[fields[0]] = fields[1]
    return timestampMap


def writeEventString(s):
    """ Write the pre-formatted event to the destination.

        The currently accepted destinations are a file, or a syslog daemon.
    """
    if (s != None):
        if (outputFormat.endswith("-file")):
            if (outfp):
                print >> outfp, s
            else:
                print s
        elif (outputFormat.endswith("-syslog")):
            if not isWindows:
                syslog.syslog(syslog.LOG_INFO, s)
            else:
                syslogLevel = 'info'
                syslogFacility = 'user'
                remote_syslog.syslog(s, remote_syslog.LEVEL[syslogLevel], remote_syslog.FACILITY[syslogFacility])


def convertToKV(ev):
    """ Convert an event to list of key=value pairs.

        The value will be surrounded by double-quotes, but the key will be bare.
    """
    str = None
    for key in ev:
        if (str):
            str += " "
        else:
            str = ""
        str += "%s=\"%s\"" % (key, ev[key])
    return str


def convertToTxt(ev):
    """ Convert an event to a reasonably readable English text.

        The main part of the text will be the 'message' field.
        If the 'actor_ip_address' field is present, it will be prepended as "From <ip> - ".
        If the 'created_at' field is present, it will be prepended as "At <time> - ".
    """
    str = ""
    if (outputFormat == "txt-file"):
        str += cputils.getSyslogPrefix()
    if ('created_at' in ev):
        str += "At %s - " % ev['created_at']
    if ('actor_ip_address' in ev):
        str += "From %s - " % ev['actor_ip_address']
    if ('message' in ev):
        str += ev['message']
    else:
        #error, don't want to output a broken event
        return None
    return str


def formatEvents(eventList):
    """ Formats a list of events according to the user's settings.

        We can format in JSON, text, or key-value pairs. Once the
        event is formatted, it's passed to writeEventString() to be
        written to the destination.
    """
    global outputFormat, oneEventPerLine
    if (outputFormat.startswith("json-")):
        if (oneEventPerLine):
            for ev in eventList:
                writeEventString(json.dumps(ev))
        else:
            if (len(eventList) > 0):
                writeEventString(json.dumps(eventList))
    elif (outputFormat.startswith("kv-")):
        for ev in eventList:
            writeEventString(convertToKV(ev))
    elif (outputFormat.startswith("txt-")):
        for ev in eventList:
            writeEventString(convertToTxt(ev))


def dumpEvents(json_str):
    """ Parses a JSON response to the request for an event batch.

        The requests contains an outer wrapper object, with pagination info
        and a list of events. We extract the pagination info (contains a link to
        the next batch of events) and the event list. The event list is passed
        to formatEvents() to be formatted and sent to the desired output.
    """
    timestampKey = 'created_at'
    paginationKey = 'pagination'
    nextKey = 'next'
    eventsKey = 'events'
    obj = json.loads(json_str)
    nextLink = None
    lastTimestamp = None
    if (paginationKey in obj):
        pagination = obj[paginationKey]
        if ((pagination) and (nextKey in pagination)):
            nextLink = pagination[nextKey]
    if (eventsKey in obj):
        eventList = obj[eventsKey]
        formatEvents(eventList)
        numEvents = len(eventList)
        if (numEvents > 0):
            lastEvent = eventList[numEvents - 1]
            if (timestampKey in lastEvent):
                lastTimestamp = lastEvent[timestampKey]
    return (nextLink, lastTimestamp)


def writeConfigFile(filename, timestampList):
    """ Writes the configuration file.

        See processConfigFile() for more info.
    """
    try:
        fp = open(filename, "w")
        for entry in timestampList:
            if ('id' in entry) and ('timestamp' in entry):
                fp.write("%s|%s\n" % (entry['id'], entry['timestamp']))
        fp.close()
    except IOError as e:
        print >> sys.stderr, "Failed to save config info to %s" % filename
        print "I/O error({0}): {1}".format(e.errno, e.strerror)
    except:
        print >> sys.stderr, "Failed to save config info to %s" % filename
        print >> sys.stderr, "error: ", sys.exc_info()[0]

# end of function definitions, begin inline code

atexit.register(processExit)
progDir = os.path.dirname(sys.argv[0])

# Process command-line arguments
if (processCmdLineArgs(sys.argv)):
    sys.exit(0)

if configDir == None:
    configDir = progDir

# Check for other instances of this script running on same host.
cputils.checkLockFile(pidFilename)

if (len(authFilenameList) == 0):
    authFilenameList = [authFilenameDefault]

apiConnections = []
for authFilename in authFilenameList:
    configFilename = cputils.convertAuthFilenameToConfig(authFilename)
    configFilename = os.path.join(configDir, configFilename)
    timestampMap = processConfigFile(configFilename)

    # Process the auth file (if any) which contains key and secret
    (credentialList, errMsg) = cputils.processAuthFile(authFilename, progDir)
    if errMsg != None:
        print >> sys.stderr, errMsg
        sys.exit(1)
    # pre-fill timestamps so interim config file writes will at least have saved timestamp
    for credential in credentialList:
        if credential['id'] in timestampMap:
            credential['timestamp'] = timestampMap[credential['id']]

    for credential in credentialList:
        apiCon = cpapi.CPAPI()
        apiConnections.append(apiCon)
        (apiCon.key_id, apiCon.secret) = (credential['id'], credential['secret'])

        # Check that we have a key and secret. Must be obtained either in an auth file,
        #   or on the command-line (not as secure). If we did not find either place, exit.
        if ((not apiCon.key_id) or (not apiCon.secret)):
            print >> sys.stderr, "Unable to read auth file %s. Exiting..." % authFilename
            print >> sys.stderr, "Requires lines of the form \"<API-id>|<secret>\""
            sys.exit(1)

        # Now get beginning timestamp... if not from cmd-line, then from .config file
        if credential['id'] in timestampMap:
            connLastTimestamp = timestampMap[credential['id']]
        else:
            connLastTimestamp = lastTimestamp  # handle timestamp per-connection

        # Now, turn key and secret into an authentication token (usually only good
        #   for 15 minutes or so) by logging in to the REST API server.
        resp = apiCon.authenticateClient()
        if (not resp):
            # no error message here, rely on cpapi.authenticate client for error message
            sys.exit(1)

        # Now, prep the destination for events (open file, or connect to syslog server).
        openOutput()
        # Decide on the initial URL used for fetching events.
        nextLink = apiCon.getInitialLink(connLastTimestamp, events_per_page)

        # Now, enter a "while more events available" loop.
        while (nextLink):
            (batch, authError) = apiCon.getEventBatch(nextLink)
            if (authError):
                # An auth error is likely to happen if our token expires (after 15 minutes or so).
                # If so, we try to renew our session by logging in again (gets a new token).
                resp = apiCon.authenticateClient()
                if (not resp):
                    print >> sys.stderr, "Failed to retrieve authentication token. Exiting..."
                    sys.exit(1)
            else:
                # If we received a batch of events, send them to the destination.
                (nextLink, connLastTimestamp) = dumpEvents(batch)
                # After each batch, write out config file with latest timestamp (from events),
                #   so that if we get interrupted during the next batch, we can resume from this point.
                credential['timestamp'] = connLastTimestamp
                writeConfigFile(configFilename, credentialList)
                # print "NextLink: %s\t\t%s" % (nextLink, connLastTimestamp)
                # time.sleep(1000) # for testing only

        # After we've finished all events, write out current system time
        #   so we don't always re-output the last event (REST API timestamp
        #   comparison is inclusive, so it returns events whose timestamp is
        #   later-than-or-equal-to the provided timestamp).
        connLastTimestamp = cputils.getNowAsISO8601()
        credential['timestamp'] = connLastTimestamp
        writeConfigFile(configFilename, credentialList)
