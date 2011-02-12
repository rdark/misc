#!/usr/bin/python
#
# wsResumeFileFiles.py
# Purpose:          Script to resume file deletion task within the Connections Files application
# Notes:            Depends on a hacked version of the fileAdmin.py library
# Invocation:       ./wsadmin.sh -lang jython -javaoption -Dscript.encoding=IBM-1047 -f $filename
# Author:           Richard Clark <richard.clark@portalpartnership.com>

import sys

wsLineSeparator = java.lang.System.getProperty('line.separator')

# Get list of services
wsSvcs = AdminControl.queryNames("*:name=FilesSchedulerMBean,type=LotusConnections,*").split(wsLineSeparator)
if len(wsSvcs[0]) == 0:
    raise RuntimeError('ERROR: Files services could not be retrieved.')
else:
    for a in wsSvcs:
        # serviceNum is a variable relating to the service node number
        serviceNum = wsSvcs.index(a)
        serviceNum = serviceNum+1
        execfile("/opt/IBM/WebSphere/AppServer/profiles/Dmgr01/config/bin_lc_admin/filesAdmin_unattend.py")
        FilesScheduler.resumeSchedulingTask("FileActuallyDelete")
