#!/usr/bin/env python

import sys
import json
import urllib
import urllib2
import base64


# Class with calls to CloudPassage API
class CPAPI:
    def __init__(self):
        self.auth_url = 'oauth/access_token'
        self.auth_args = {'grant_type': 'client_credentials'}
        self.base_url = 'https://api.cloudpassage.com'
        self.api_ver = 'v1'
        self.port = 443
        self.key_id = None
        self.secret = None
        self.authToken = None

    # Dump debug info
    def dumpToken(self, token, expires):
        if (token):
            print "AuthToken=%s" % token
        if (expires):
            print "Expires in %s minutes" % (expires / 60)

    def getHttpStatus(self, code):
        if (code == 200):
            return "OK" 	# should never be passed in, only errors
        elif (code == 401):
            return "Unauthorized"
        elif (code == 403):
            return "Forbidden"
        elif (code == 404):
            return "Not found"
        elif (code == 422):
            return "Validation failed"
        elif (code == 500):
            return "Internal server error"
        elif (code == 502):
            return "Gateway error"
        else:
            return "Unknown code [%d]" % code

    def addAuth(self, req, kid, sec):
        combined = kid + ":" + sec
        encoded = base64.b64encode(combined)
        req.add_header("Authorization", "Basic " + encoded)

    def getAuthToken(self, url, args, kid, sec):
        req = urllib2.Request(url)
        self.addAuth(req, kid, sec)
        # print >> sys.stderr, "getAuthToken: key=%s secret=%s" % (kid, sec)
        # createPasswordMgr(url, kid, sec)
        if (args):
            args = urllib.urlencode(args)
        try:
            fh = urllib2.urlopen(req, args)
            return fh.read()
        except IOError, e:
            if hasattr(e, 'reason'):
                print >> sys.stderr, "Failed to connect [%s] to '%s'" % (e.reason, url)
            elif hasattr(e, 'code'):
                msg = self.getHttpStatus(e.code)
                print >> sys.stderr, "Failed to authorize [%s] at '%s'" % (msg, url)
                data = e.read()
                if data:
                    print >> sys.stderr, "Extra data: %s" % data
                print >> sys.stderr, "Likely cause: incorrect API keys, id=%s" % kid
            else:
                print >> sys.stderr, "Unknown error fetching '%s'" % url
            return None

    def getInitialLink(self, fromDate, events_per_page):
        url = "%s:%d/%s/events?per_page=%d" % (self.base_url, self.port, self.api_ver, events_per_page)
        if (fromDate):
            url += "&since=" + fromDate
        return url

    def getEventBatch(self, url):
        return self.doGetRequest(url, self.authToken)

    def doGetRequest(self, url, token):
        req = urllib2.Request(url)
        req.add_header("Authorization", "Bearer " + token)
        try:
            fh = urllib2.urlopen(req)
            return (fh.read(), False)
        except IOError, e:
            authError = False
            if hasattr(e, 'reason'):
                print >> sys.stderr, "Failed to connect [%s] to '%s'" % (e.reason, url)
            elif hasattr(e, 'code'):
                msg = self.getHttpStatus(e.code)
                print >> sys.stderr, "Failed to fetch events [%s] from '%s'" % (msg, url)
                if (e.code == 401):
                    authError = True
            else:
                print >> sys.stderr, "Unknown error fetching '%s'" % url
            return (None, authError)

    def doPutRequest(self, url, token, putData):
        opener = urllib2.build_opener(urllib2.HTTPHandler)
        req = urllib2.Request(url, data=putData)
        req.add_header("Authorization", "Bearer " + token)
        req.add_header("Content-Type", "application/json")
        req.get_method = lambda: 'PUT'
        try:
            fh = opener.open(req)
            return (fh.read(), False)
        except IOError, e:
            authError = False
            if hasattr(e, 'reason'):
                print >> sys.stderr, "Failed to connect [%s] to '%s'" % (e.reason, url)
            if hasattr(e, 'code'):
                msg = self.getHttpStatus(e.code)
                print >> sys.stderr, "Failed to make request: [%s] from '%s'" % (msg, url)
                if (e.code == 401):
                    authError = True
            if (not hasattr(e, 'reason')) and (not hasattr(e, 'code')):
                print >> sys.stderr, "Unknown error fetching '%s'" % url
            return (None, authError)

    def doPostRequest(self, url, token, putData):
        opener = urllib2.build_opener(urllib2.HTTPHandler)
        req = urllib2.Request(url, data=putData)
        req.add_header("Authorization", "Bearer " + token)
        req.add_header("Content-Type", "application/json")
        try:
            fh = opener.open(req)
            return (fh.read(), False)
        except IOError, e:
            authError = False
            if hasattr(e, 'reason'):
                print >> sys.stderr, "Failed to connect [%s] to '%s'" % (e.reason, url)
            if hasattr(e, 'code'):
                msg = self.getHttpStatus(e.code)
                print >> sys.stderr, "Failed to make request: [%s] from '%s'" % (msg, url)
                if (e.code == 401):
                    authError = True
            if (not hasattr(e, 'reason')) and (not hasattr(e, 'code')):
                print >> sys.stderr, "Unknown error fetching '%s'" % url
            return (None, authError)

    def authenticateClient(self):
        url = "%s:%d/%s" % (self.base_url, self.port, self.auth_url)
        self.token = None
        response = self.getAuthToken(url, self.auth_args, self.key_id, self.secret)
        if (response):
            authRespObj = json.loads(response)
            if ('access_token' in authRespObj):
                self.authToken = authRespObj['access_token']
            if ('expires_in' in authRespObj):
                self.expires = authRespObj['expires_in']
        # dumpToken(token,expires)
        return self.authToken

    def getServerList(self):
        url = "%s:%d/%s/servers" % (self.base_url, self.port, self.api_ver)
        (data, authError) = self.doGetRequest(url, self.authToken)
        if (data):
            return (json.loads(data), authError)
        else:
            return (None, authError)

    def getServerGroupList(self):
        url = "%s:%d/%s/groups" % (self.base_url, self.port, self.api_ver)
        (data, authError) = self.doGetRequest(url, self.authToken)
        if (data):
            return (json.loads(data), authError)
        else:
            return (None, authError)

    def getFirewallPolicyList(self):
        url = "%s:%d/%s/firewall_policies/" % (self.base_url, self.port, self.api_ver)
        (data, authError) = self.doGetRequest(url, self.authToken)
        if (data):
            return (json.loads(data), authError)
        else:
            return (None, authError)

    def getFirewallPolicyDetails(self, policyID):
        url = "%s:%d/%s/firewall_policies/%s" % (self.base_url, self.port, self.api_ver, policyID)
        (data, authError) = self.doGetRequest(url, self.authToken)
        if (data):
            return (json.loads(data), authError)
        else:
            return (None, authError)

    def moveServerToGroup(self, serverID, groupID):
        url = "%s:%d/%s/servers/%s" % (self.base_url, self.port, self.api_ver, serverID)
        reqData = {"server": {"group_id": groupID}}
        jsonData = json.dumps(reqData)
        # print "move: %s" % jsonData
        (data, authError) = self.doPutRequest(url, self.authToken, jsonData)
        if (data):
            return (json.loads(data), authError)
        else:
            return (None, authError)

    def createServerGroup(self, groupName, linuxFirewallPolicy, windowsFirewallPolicy):
        url = "%s:%d/%s/groups" % (self.base_url, self.port, self.api_ver)
        groupData = {"name": groupName, "policy_ids": [], "tag": None}
        groupData["linux_firewall_policy_id"] = linuxFirewallPolicy
        groupData["windows_firewall_policy_id"] = windowsFirewallPolicy
        reqData = {"group": groupData}
        jsonData = json.dumps(reqData)
        (data, authError) = self.doPostRequest(url, self.authToken, jsonData)
        if (data):
            return (json.loads(data), authError)
        else:
            return (None, authError)

    def createFirewallPolicy(self, policyData):
        url = "%s:%d/%s/firewall_policies" % (self.base_url, self.port, self.api_ver)
        jsonData = json.dumps(policyData)
        # print jsonData # for debugging
        (data, authError) = self.doPostRequest(url, self.authToken, jsonData)
        if (data):
            return (json.loads(data), authError)
        else:
            return (None, authError)
