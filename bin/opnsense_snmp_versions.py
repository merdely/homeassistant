#!/usr/bin/env python3

from pysnmp.hlapi import *
import json
import os
import re
import sys

def get(host, oid, version, commstring='public', user=None, authpw=None, privpw=None):
    if version == "3":
        authobject = UsmUserData(user, authpw, privpw, authProtocol=usmHMACSHAAuthProtocol, privProtocol=usmAesCfb128Protocol)
    else:
        authobject = CommunityData(commstring)
    for (errorIndication,errorStatus,errorIndex,varBinds) in getCmd(SnmpEngine(),
        authobject, UdpTransportTarget((host, 161)), ContextData(),
        ObjectType(ObjectIdentity(oid)), lexicographicMode=False):
        if errorIndication:
            print(errorIndication, file=sys.stderr)
            break
        elif errorStatus:
            print('%s at %s' % (errorStatus.prettyPrint(),
                                errorIndex and varBinds[int(errorIndex) - 1][0] or '?'),
                                file=sys.stderr)
            break
        else:
            for _, val in varBinds:
                sysDescr = val.prettyPrint().split(' ')
                os = sysDescr[3]
                ver = sysDescr[4].split('.')
                arch = sysDescr[-1]
                sw="{}:{}:{}".format(os,ver[0],arch)
                abi=re.split('[/-]', sysDescr[5])[1]
    return [ sw, abi ]

def walk(host, oid, version, commstring='public', user=None, authpw=None, privpw=None):
    swlist = {}
    plugins = {}
    #print("user=" + user)
    #print("authpw=" + authpw)
    #print("privpw=" + privpw)
    if version == "3":
        authobject = UsmUserData(user, authpw, privpw, authProtocol=usmHMACSHAAuthProtocol, privProtocol=usmAesCfb128Protocol)
    else:
        authobject = CommunityData(commstring)
    for (errorIndication,errorStatus,errorIndex,varBinds) in nextCmd(SnmpEngine(),
        authobject, UdpTransportTarget((host, 161)), ContextData(),
        ObjectType(ObjectIdentity(oid)), lexicographicMode=False):
        if errorIndication:
            print(errorIndication, file=sys.stderr)
            break
        elif errorStatus:
            print('%s at %s' % (errorStatus.prettyPrint(),
                                errorIndex and varBinds[int(errorIndex) - 1][0] or '?'),
                                file=sys.stderr)
            break
        else:
            for _, val in varBinds:
                sw = val.prettyPrint()
                m1 = re.match('^os-(.*)-([0-9._r,]+)$', sw)
                m2 = re.match('^opnsense-([0-9._r,]+)$', sw)
                m3 = re.match('^opnsense-installer-([0-9._r,]+)$', sw)
                m4 = re.match('^opnsense-update-([0-9._r,]+)$', sw)
                if m1:
                    plugins[m1.group(1)] = m1.group(2)
                if m2:
                    swlist['opnsense'] = m2.group(1)
                if m3:
                    swlist['core-abi'] = m3.group(1)
                if m4:
                    swlist['opnsense-update'] = m4.group(1)
    swlist['plugins'] = plugins
    return swlist

ipaddress = ''
oid = ''
version = ''
commstring = None
authpw = None
authprot = None
privpw = None
privprot = None
secrets = os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0]))) + '/secrets.yaml'
with open(secrets, 'r') as file:
    for line in file.readlines():
        m = re.search(r"^opnsense_(ipaddress|oid|version|commstring|user|authpw|authprot|privpw|privprot): '?([^']+)'?$", line)
        if m and m.group(1) == 'ipaddress':
            ipaddress = m.group(2)
        elif m and m.group(1) == 'oid':
            oid = m.group(2)
        elif m and m.group(1) == 'version':
            version = m.group(2)
        elif m and m.group(1) == 'commstring':
            commstring = m.group(2)
        elif m and m.group(1) == 'user':
            user = m.group(2)
        elif m and m.group(1) == 'authpw':
            authpw = m.group(2)
        elif m and m.group(1) == 'privpw':
            privpw = m.group(2)
file.close()
versions = walk(ipaddress, oid, version, commstring, user, authpw, privpw)
[ sys_abi, versions['core-abi'] ] = get(ipaddress, '.1.3.6.1.2.1.1.1.0', version, commstring, user, authpw, privpw)
versions['sys-abi'] = sys_abi
print(json.dumps(versions))

