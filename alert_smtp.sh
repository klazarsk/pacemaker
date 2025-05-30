#!/bin/sh
#
# Adapted from alert_smtp.sh from the pacemaker package by 
# klazarsk@redhat.com for scopable alert generation
#
# You can improve upon the granularity of the alerting by matching 
# substrings in variables such as CRM_alert_desc and testing other
# variables and creating more complex cases to drive filtering and turning 
# individual alerts off and on. In this user's case, they only wanted 
# fencing notices and wanted it filtered at the the alert generation stage.
# 
#
##############################################################################
#
# Copyright 2016-2021 the Pacemaker project contributors
#
# The version control history for this file may have further details.
#
# This source code is licensed under the GNU General Public License version 2
# or later (GPLv2+) WITHOUT ANY WARRANTY.
#
##############################################################################
#
# Sample configuration (cib fragment in xml notation)
# ================================
# <configuration>
#   <alerts>
#     <alert id="smtp_alert" path="/path/to/alert_smtp">
#       <instance_attributes id="config_for_alert_smtp">
#         <nvpair id="cluster_name" name="cluster_name" value=""/>
#         <nvpair id="email_client" name="email_client" value=""/>
#         <nvpair id="email_sender" name="email_sender" value=""/>
#       </instance_attributes>
#       <recipient id="smtp_destination" value="admin@example.com"/>
#     </alert>
#   </alerts>
# </configuration>

# Explicitly list all environment variables used, to make static analysis happy
: ${CRM_alert_version:=""}
: ${CRM_alert_recipient:=""}
: ${CRM_alert_timestamp:=""}
: ${CRM_alert_kind:=""}
: ${CRM_alert_node:=""}
: ${CRM_alert_desc:=""}
: ${CRM_alert_task:=""}
: ${CRM_alert_rsc:=""}
: ${CRM_alert_attribute_name:=""}
: ${CRM_alert_attribute_value:=""}


#############################################################
# Pass "RHA_alert_kinds" as an option at the pcs alert create
# stage, otherwise if the variable is null/not set by alert 
# options assignment, take the value in this stanza
# Take alert types out of optAlertKinds to disable alerts
  if [ -z ${RHA_alert_kinds} ]; then
  
    # ALL alerts (unfiltered)
    optAlertKinds="fencing,node,resource,attribute"
    # ONLY fencing alerts:
    # optAlertKinds="fencing"
  
  else
   
    optAlertKinds="${RHA_alert_kinds}"
  
  fi 
#
#############################################################


email_client_default="sendmail"
email_sender_default="hacluster"
email_recipient_default="root"

: ${email_client=${email_client_default}}
: ${email_sender=${email_sender_default}}
email_recipient="${CRM_alert_recipient-${email_recipient_default}}"

node_name=$(uname -n)
cluster_name=$(crm_attribute --query -n cluster-name -q)
email_body=$(env | grep CRM_alert_ ; env | grep RHA_[as]; echo -e "\n note: Email notifications limited to alert types: ${optAlertKinds}\n")

if [ ! -z "${email_sender##*@*}" ]; then
    email_sender="${email_sender}@${node_name}"
fi

if [ ! -z "${email_recipient##*@*}" ]; then
    email_recipient="${email_recipient}@${node_name}"
fi

if [ -z ${CRM_alert_version} ]; then
    email_subject="Pacemaker version 1.1.15 or later is required for alerts"
else
  case ${CRM_alert_kind} in
    node)
      if [[ $optAlertKinds == *"node"* ]]; then
        email_subject="${CRM_alert_timestamp} ${cluster_name}: Node '${CRM_alert_node}' is now '${CRM_alert_desc}'"
      fi
      ;;
    fencing)
      if [[ $optAlertKinds == *"fencing"* ]]; then
        email_subject="${CRM_alert_timestamp} ${cluster_name}: Fencing ${CRM_alert_desc}"
      fi
      ;;
    resource)
      if [[ $optAlertKinds == *"resource"* ]]; then
        if [ ${CRM_alert_interval} = "0" ]; then
            CRM_alert_interval=""
        else
            CRM_alert_interval=" (${CRM_alert_interval})"
        fi

        if [ ${CRM_alert_target_rc} = "0" ]; then
            CRM_alert_target_rc=""
        else
            CRM_alert_target_rc=" (target: ${CRM_alert_target_rc})"
        fi

        case ${CRM_alert_desc} in
          Cancelled) ;;
          *)
              email_subject="${CRM_alert_timestamp} ${cluster_name}: Resource operation '${CRM_alert_task}${CRM_alert_interval}' for '${CRM_alert_rsc}' on '${CRM_alert_node}': ${CRM_alert_desc}${CRM_alert_target_rc}"
          ;;
        esac
      fi
      ;;
    attribute)
        if [[ $optAlertKinds == *"attribute"* ]]; then 
          email_subject="${CRM_alert_timestamp} ${cluster_name}: The '${CRM_alert_attribute_name}' attribute of the '${CRM_alert_node}' node was updated in '${CRM_alert_attribute_value}'"
        fi
        ;;
    *)
        email_subject="${CRM_alert_timestamp} ${cluster_name}: Unhandled $CRM_alert_kind alert"
        ;;

  esac
fi

if [ ! -z "${email_subject}" ]; then
    case $email_client in
        # This sample script supports only sendmail for sending the email.
	# Support for additional senders can easily be added by adding
	# new cases here.
        sendmail)
            sendmail -t -r "${email_sender}" <<__EOF__
From: ${email_sender}
To: ${email_recipient}
Return-Path: ${email_sender}
Subject: ${email_subject}

${email_body}
__EOF__
            ;;
        *)
            ;;
    esac
fi
