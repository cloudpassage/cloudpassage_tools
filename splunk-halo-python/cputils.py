#!/usr/bin/env python

# Module with calls to CloudPassage API

import sys
import platform
import os
import datetime
import os.path
import socket
import re


def checkPythonVersion():
    # This script depends on libraries like json and urllib2 which require 2.6 or 2.7
    #   so test for one of those, and exit if not found.
    pyver = platform.python_version()
    if ((not pyver.startswith('2.6')) and (not pyver.startswith('2.7'))):
        print >> sys.stderr, "Python version %s is not supported, need 2.6.x or 2.7.x" % pyver
        sys.exit(1)


def checkPidRunning(pid):
    if (platform.system() != "Windows"):
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        else:
            return True
    else:
        return True


def checkLockFile(filename):
    pid = str(os.getpid())
    if (os.path.isfile(filename)):
        errMsg = "Lock file (%s) exists" % filename
        pid = file(filename, 'r').readlines()[0].strip()
        if (checkPidRunning(int(pid))):
            print >> sys.stderr, "%s... Exiting" % errMsg
        else:
            print >> sys.stderr, "%s, but PID (%s) not running." % (errMsg, pid)
            print >> sys.stderr, "Deleting stale lock file. Try running script again."
            os.remove(filename)
        sys.exit(1)
    else:
        file(filename, 'w').write(pid)


def convertAuthFilenameToConfig(filename):
    basename = os.path.basename(filename)
    return basename.replace(".auth", ".config")


def processAuthFile(filename, progDir):
    if (not os.path.exists(filename)):
        filename = os.path.join(progDir, filename)
        if (not os.path.exists(filename)):
            return (None, "Auth file %s does not exist" % filename)
    fp = open(filename)
    lines = fp.readlines()
    fp.close()
    credentials = []
    for line in lines:
        str = line.strip()
        if not str.startswith("#"):
            fields = str.split("|")
            if (len(fields) == 2):
                if (len(credentials) < 5):
                    credential = {'id': fields[0], 'secret': fields[1]}
                    credentials.append(credential)
                else:
                    print >> sys.stderr, "Ignoring id=%s, only 5 accounts allowed" % fields[0]
    if (len(credentials) == 0):
        return (None, "Empty auth file, no credentials found in %s" % filename)
    else:
        return (credentials, None)


def verifyISO8601(tstr):
    if (tstr == None) or (len(tstr) == 0):
        return (False, "Empty timestamp, ISO8601 format required")
    iso_regex = "\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{4})?)?$"
    m = re.match(iso_regex, tstr)
    if (m == None):
        return (False, "Timestamp (%s) does not match ISO8601 format" % tstr)
    return (True, "")


def formatTimeAsISO8601(dt):
    tuple = (dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.microsecond)
    return "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ" % tuple


def getNowAsISO8601():
    return formatTimeAsISO8601(datetime.datetime.utcnow())


def getHostname():
    return socket.gethostname()


monthNames = ["???", "Jan", "Feb", "Mar", "Apr",
              "May", "Jun", "Jul", "Aug", "Sep",
              "Oct", "Nov", "Dec"]


def getSyslogTime():
    now = datetime.datetime.now()
    tuple = (monthNames[now.month], now.day, now.hour, now.minute, now.second)
    return "%s %2d %02d:%02d:%02d" % tuple


# Jan  6 19:05:30 percheron cpapi:
def getSyslogPrefix():
    return "%s %s cpapi: " % (getSyslogTime(), getHostname())
