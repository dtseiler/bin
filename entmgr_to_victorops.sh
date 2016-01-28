#!/bin/ksh

# Place this script on your Enterprise Manager (EM) server and add it as a new Notification Method
# under Setup -> Notifications -> Notification Methods as an OS Command. 
#
# Environment variables are passed in from EM12c
# See http://docs.oracle.com/cd/E24628_01/doc.121/e24473/notification.htm#CACFAEAF
#
# VictorOps REST API: http://victorops.force.com/knowledgebase/articles/Integration/Alert-Ingestion-API-Documentation/

# Look this up in your VictorOps account Settings->Integrations->REST Endpoint screen
VOPS_API_KEY="xxx"
VOPS_ROUTING_KEY="zzz"

VOPS_URL="https://alert.victorops.com/integrations/generic/20131114/alert/$VOPS_API_KEY/$VOPS_ROUTING_KEY"
VOPS_DATE=`date +%s`

# Possible EM severity codes: FATAL, CRITICAL, WARNING, MINOR_WARNING, INFORMATIONAL, and CLEAR
# Valid VOPS message types: INFO, WARNING, ACKNOWLEDGEMENT, CRITICAL, RECOVERY
# The severity codes you send to this script depend on your EM notification rules.
VOPS_MESSAGE_TYPE=$SEVERITY_CODE
if [ "$VOPS_MESSAGE_TYPE" = "CLEAR" ]; then
        VOPS_MESSAGE_TYPE="RECOVERY"
elif [ "$VOPS_MESSAGE_TYPE" = "INFORMATIONAL" ]; then
        VOPS_MESSAGE_TYPE="INFO"
elif [ "$VOPS_MESSAGE_TYPE" = "MINOR_WARNING" ]; then
        VOPS_MESSAGE_TYPE="WARNING"
elif [ "$VOPS_MESSAGE_TYPE" = "FATAL" ]; then
        VOPS_MESSAGE_TYPE="CRITICAL"
fi

VOPS_MESSAGE="$TARGET_TYPE $TARGET_NAME on $HOST_NAME: $MESSAGE"

# Build JSON message to send to VictorOps
VOPS_JSON=$(cat <<EOF
{
        "message_type":"$VOPS_MESSAGE_TYPE",
        "entity_id":"$ASSOC_INCIDENT_ID",
        "entity_display_name":"$TARGET_NAME: $MESSAGE",
        "state_start_time":"$VOPS_DATE",
        "state_message":"$VOPS_MESSAGE",
        "monitoring_tool":"Oracle Enterprise Manager"
}
EOF
)

# Send the message
curl --data-binary "$VOPS_JSON" $VOPS_URL
