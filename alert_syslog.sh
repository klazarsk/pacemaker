#!/bin/sh
#
# Adapted from alert_smtp.sh from the pacemaker package by 
# klazarsk@redhat.com for one of our users, May 2025
#
# Compare to alert_smtp to see how trivial this was to adapt. 
# The complication arises in filtering and steering the alerts for
# users who want to the filtering done at the origin service rather
# than on the syslog aggregator.
#
# You can improve upon the granularity of the alerting by matching 
# substrings in variables such as CRM_alert_desc and testing other
# variables and creating more complex cases to drive filtering and turning 
# individual alerts off and on. In this user's case, they only wanted 
# fencing notices and wanted it filtered at the the alert generation stage.
#
##############################################################################
# Copyright 2016-2017 the Pacemaker project contributors
#
# The version control history for this file may have further details.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
##############################################################################
#
# Sample configuration (cib fragment in xml notation)
# ================================
#
#  <alert id="alert_webcluster1" path="/var/lib/pacemaker/alert_syslog.sh">
#     <instance_attributes id="alert_webcluster1-instance_attributes">
#       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_facility" name="RHA_syslog_facility" value="local2"/>
#       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_port" name="RHA_syslog_port" value="2514"/>
#       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_priority" name="RHA_syslog_priority" value="err"/>
#       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_proto" name="RHA_syslog_proto" value="tcp"/>
#       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_server" name="RHA_syslog_server" value="fqdn.syslog.example.com"/>
#       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_tag" name="RHA_syslog_tag" value="webcluster1"/>
#     </instance_attributes>
#
# Supported options: 
#      
#   RHA_syslog_facility
#     This is the syslog alert facility (man 3 syslog)
#       Examples:
#         LOG_AUTH, AUTHPRIV, LOG_LOCAL0, local5, etc.
#         LOCAL0 - LOCAL7 are for custom use, for alerting mechanisms such as this script
#
#   RHA_syslog_priority
#     This is the syslog log level (man 3 syslog)
#       Examples:
#         LOG_EMERG, LOG_ALERT, LOG_CRIT, ERR, WARNING, NOTICE, INFO, DEBUG
#
#   RHA_syslog_tag
#     This is the syslog "tag" attribute which is supported by many aggreggators, useful for additional filtering
#
#   RHA_syslog_port
#     This is the port the syslog aggregator is listening on 
#
#   RHA_syslog_proto
#     This is the protocol syslog is listening for; valid values are tcp or udp 
#
#
#   (there are more facilities and levels than included above)
#   
#   If you've worked with syslog.conf files before you'll recall it's normal for 
#   the facility to be specified in all lower case, and the LOG_ prefix to be 
#   dropped. So these examples would be typical:
#
#   local2.*    /var/log/pacemaker/syslog # Capture ALL notices sent to LOG_LOCAL2 to /var/log/pacemaker/syslog
#   local2.err  /var/log/pacemaker/errorlog # capture all notices of ERR or greater priority to /var/log/paceemaker/errorlog
#   
# Installation:
#
# Place alert_syslog.sh in pacemaker lib dirctory (typically /var/lib/pacemaker)
# chown it the pacemaker user and group (typically hacluster:haclient on a default install)
# chmod it 0750
#
# create the alert. Example:
#
# pcs alert create id=alert_webcluster1 path=/var/lib/pacemaker/alert_syslog.sh options \
#  RHA_syslog_facility=local2 RHA_syslog_priority=err RHA_syslog_tag=webcluster1 \
#  RHA_alert_server=fqdn.syslog.example.com

#


if [ -z $RHA_alert_kinds ]; then
  optAlertKinds="${RHA_alert_kinds}"
else
  
  #_#########################################################
  # Pass "RHA_alert_kinds" as an option at the pcs alert create
  # stage, otherwise if the variable is null/not set by alert 
  # options assignment, take the value in this stanza
  #_# Take alert types out of optAlertKinds to disable alerts
  # optAlertKinds="fencing,node,resource,attribute"
  optAlertKinds="fencing,node,resource,attribute"

fi

strNodeName=$(hostname)
strClusterName="$(crm_attribute --query -n cluster-name)"
dtStamp=$(date --date @$CRM_alert_timestamp_epoch +"%F_%T %z")
strNotice="$(echo -e '\nEnvironment variables:' ; env | grep 'CRM_alert_' ; env | grep 'RHA_syslog_')"
if [ ! -z "${RHA_syslog_server}" ]; then
  if [ -z "${RHA_syslog_protocol}" ]; then
    optSyslogServer="--server ${RHA_syslog_server} --tcp"
  else
    optSyslogServer="--server ${RHA_syslog_server} --${RHA_syslog_protocol}"
  fi
fi
if [ ! -z ${RHA_syslog_port} ]; then
  optSyslogPort="--port ${RHA_syslog_port}"
fi
if [ ! -z ${RHA_syslog_tag} ]; then
  optTag="--tag ${RHA_syslog_tag}"
fi



if [ -z ${CRM_alert_version} ]; then
  strSummary="Pacemaker version 1.1.15 or later is required for alerts"
else
  case ${CRM_alert_kind} in
    node)
      if [[ $optAlertKinds == *"node"* ]]; then
        strSummary="${CRM_alert_timestamp} ${cluster_name}: Node '${CRM_alert_node}' is now '${CRM_alert_desc}'"
      fi
    ;;
    fencing)
  		if [[ $optAlertKinds == *"fencing"* ]]; then
        strSummary="${strClusterName} ${dtStamp} (node ${strNodeName} alert time: ${CRM_alert_timestamp}): Fencing ${CRM_alert_desc}"
      fi
      ;;
    resource)
      if [[ $optAlertKinds == *"resource"* ]]; then 
        if [ ${CRM_alert_interval} = "0" ]; then
          CRM_alert_interval=""
          strSummary="${strClusterName} resource alert on ${strNodeName} at ${CRM_alert_timestamp}."
        else
          CRM_alert_interval=" (${CRM_alert_interval})"
          strSummary="${strClusterName} resource alert on ${strNodeName} at ${CRM_alert_timestamp}."
        fi
  
        if [ ${CRM_alert_target_rc} = "0" ]; then
          CRM_alert_target_rc=""
          strSummary="${strClusterName} resource alert on ${strNodeName} at ${CRM_alert_timestamp}."
        else
          CRM_alert_target_rc=" (target: ${CRM_alert_target_rc})"
          strSummary="${strClusterName} resource alert on ${strNodeName} at ${CRM_alert_timestamp}."
        fi
        case ${CRM_alert_desc} in
          Cancelled) 
            unset strSummary
          ;;
        esac
      fi
      ;;
    attribute)
      if [[ $optAlertKinds == *"attribute"* ]]; then
        strSummary="${CRM_alert_timestamp} ${cluster_name}: The '${CRM_alert_attribute_name}' attribute of the '${CRM_alert_node}' node was updated in '${CRM_alert_attribute_value}'"
      fi
      ;;
    *)
      strSummary="${CRM_alert_timestamp} ${cluster_name}: Unhandled $CRM_alert_kind alert"
      ;;
  esac
fi


if [ ! -z "${strSummary}" ]; then
  strNotice="${strSummary}::${strNotice}"
  logger  ${optSyslogServer} ${optSyslogPort} -p ${RHA_syslog_facility}.${RHA_syslog_priority} ${optTag} "${RHA_syslog_tag}:(${RHA_syslog_facility}.${RHA_syslog_priority}) :: $( echo \"${strNotice}\" | tr '\n' ' ')"
  echo -e "strNotice value: \n {\n${strNotice}\n}" 1>&2
fi
