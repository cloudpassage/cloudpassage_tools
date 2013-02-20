#!/usr/bin/python

import syslog

# allows us to use the same names as in remote_syslog.py, but translated to values used by standard syslog module

FACILITY = {
    'kern': syslog.LOG_KERN, 'user': syslog.LOG_USER, 'mail': syslog.LOG_MAIL, 'daemon': syslog.LOG_DAEMON,
    'auth': syslog.LOG_AUTH, 'syslog': syslog.LOG_SYSLOG, 'lpr': syslog.LOG_LPR, 'news': syslog.LOG_NEWS,
    'uucp': syslog.LOG_UUCP, 'cron': syslog.LOG_CRON, 'authpriv': syslog.LOG_AUTH,
    'local0': syslog.LOG_LOCAL0, 'local1': syslog.LOG_LOCAL1, 'local2': syslog.LOG_LOCAL2, 'local3': syslog.LOG_LOCAL3,
    'local4': syslog.LOG_LOCAL4, 'local5': syslog.LOG_LOCAL5, 'local6': syslog.LOG_LOCAL6, 'local7': syslog.LOG_LOCAL7,
}

LEVEL = {
    'emerg': syslog.LOG_EMERG, 'alert': syslog.LOG_ALERT, 'crit': syslog.LOG_CRIT, 'err': syslog.LOG_ERR,
    'warning': syslog.LOG_WARNING, 'notice': syslog.LOG_NOTICE, 'info': syslog.LOG_INFO, 'debug': syslog.LOG_DEBUG
}

# From http://docs.python.org/2.6/library/syslog.html
# Priority levels (high to low):
#     LOG_EMERG, LOG_ALERT, LOG_CRIT, LOG_ERR, LOG_WARNING, LOG_NOTICE, LOG_INFO, LOG_DEBUG.
# Facilities:
#     LOG_KERN, LOG_USER, LOG_MAIL, LOG_DAEMON, LOG_AUTH, LOG_LPR, LOG_NEWS, LOG_UUCP, LOG_CRON and LOG_LOCAL0 to LOG_LOCAL7.
# Log options:
#     LOG_PID, LOG_CONS, LOG_NDELAY, LOG_NOWAIT and LOG_PERROR if defined in <syslog.h>.
