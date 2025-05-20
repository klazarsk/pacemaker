# Pacemaker Syslog Alert Agent 

## Derived from alert_smtp.sh in the pacemaker package

 Adapted from alert_smtp.sh from the pacemaker package 
 by klazarsk@redhat.com for one of our users, May 2025

 Compare to alert_smtp to see how trivial this was to adapt. 
 The complication arises in filtering and steering the alerts for
 users who want to the filtering done at the origin service rather
 than on the syslog aggregator.

 You can improve upon the granularity of the alerting by matching 
 substrings in variables such as CRM_alert_desc and testing other
 variables and creating more complex cases to drive filtering and turning 
 individual alerts off and on. In this user's case, they only wanted 
 fencing notices and wanted it filtered at the the alert generation stage.

## Sample configuration (cib fragment in xml notation)

```
  <alert id="alert_webcluster1" path="/var/lib/pacemaker/alert_syslog.sh">
     <instance_attributes id="alert_webcluster1-instance_attributes">
       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_facility" name="RHA_syslog_facility" value="local2"/>
       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_port" name="RHA_syslog_port" value="2514"/>
       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_priority" name="RHA_syslog_priority" value="err"/>
       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_proto" name="RHA_syslog_proto" value="tcp"/>
       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_server" name="RHA_syslog_server" value="nodea.private.example.com"/>
       <nvpair id="alert_webcluster1-instance_attributes-RHA_syslog_tag" name="RHA_syslog_tag" value="FIRSTWEB"/>
     </instance_attributes>
  </alert>
```

## Supported options: 
      
   RHA_syslog_facility

    This is the syslog alert facility (`man 3 syslog`)

      Examples:

         LOG_AUTH, AUTHPRIV, LOG_LOCAL0, local5, etc.

         LOCAL0 - LOCAL7 are for custom use, for alerting mechanisms such as this script

         Note it is typical for sysadmins to specify these in lower case and not include the LOG_ prefix

         LOG_AUTH =/= auth, and local0 =/= LOG_LOCAL0

   RHA_syslog_priority

     This is the syslog alert log level (`man 3 syslog`)

       Examples:

         LOG_EMERG, LOG_ALERT, LOG_CRIT, ERR, WARNING, NOTICE, INFO, DEBUG

         Note it is typical for sysadmins to specify these in lower case and not include the LOG_ prefix

   RHA_syslog_tag

     This is the syslog "tag" attribute which is supported by many aggreggators, useful for additional filtering

   RHA_syslog_port

     This is the port the syslog aggregator is listening on 

   RHA_syslog_proto
   
     This is the protocol syslog is listening for; valid values are tcp or udp 

### See `man 3 syslog` for detailed info on syslog facility and priority

   
   If you've worked with syslog.conf files before you'll recall it's normal for 
   the facility to be specified in all lower case, and the LOG_ prefix to be 
   dropped. So these examples would be typical:

   local2.*    /var/log/pacemaker/syslog # Capture ALL notices sent to LOG_LOCAL2 to /var/log/pacemaker/syslog

   local2.err  /var/log/pacemaker/errorlog # capture all notices of ERR or greater priority to /var/log/paceemaker/errorlog
 
## Installation:

### Place alert_syslog.sh in pacemaker lib dirctory (typically /var/lib/pacemaker)
    
```
scp alert_syslog.sh host:/var/lib/pacemaker/alert_syslog.sh
```

### chown it the pacemaker user and group (typically hacluster:haclient on a default install)

```
chmod 0750 /var/lib/pacemaker/alert_syslog.sh
```

 create the alert. Example:

```
 pcs alert create id=alert_webcluster1 path=/var/lib/pacemaker/alert_syslog.sh options \
  RHA_syslog_facility=local2 RHA_syslog_priority=err RHA_syslog_tag=webcluster1 \
  RHA_alert_server=fqdn.syslog.example.com
```


## Take alert types out of optAlertKinds in alert_syslog.sh to disable unwanted alerts

In this client's case, they only wanted fencing notices logged

```
# optAlertKinds="fencing,node,resource,attribute"
optAlertKinds="fencing"
```
