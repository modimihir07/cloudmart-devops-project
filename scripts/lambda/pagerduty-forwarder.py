"""
CloudMart DevOps Project - PagerDuty Forwarder Lambda

Triggered by SNS notifications from CloudWatch Alarms.
Forwards ALARM and OK notifications to PagerDuty Events API v2.

Environment Variables:
  PAGERDUTY_ROUTING_KEY: PagerDuty Events API v2 integration key
  PAGERDUTY_FROM_EMAIL:  Email address for PagerDuty deduplication
  LOG_LEVEL:             DEBUG, INFO (default), WARNING, ERROR
"""

import json
import os
import logging
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

PAGERDUTY_URL = "https://events.pagerduty.com/v2/enqueue"
ROUTING_KEY = os.environ.get("PAGERDUTY_ROUTING_KEY", "")
FROM_EMAIL = os.environ.get("PAGERDUTY_FROM_EMAIL", "cloudmart@example.com")

SEVERITY_MAP = {
    "ALARM": "critical",
    "OK": "info",
    "INSUFFICIENT_DATA": "warning",
}


def lambda_handler(event, context):
    logger.debug("Received event: %s", json.dumps(event))

    if ROUTING_KEY == "REPLACE_WITH_PAGERDUTY_KEY":
        logger.error("PAGERDUTY_ROUTING_KEY not configured")
        return {"statusCode": 500, "body": "PagerDuty key not configured"}

    try:
        sns_message = parse_sns_event(event)
        if sns_message is None:
            return {"statusCode": 200, "body": "No SNS message found"}

        pd_event = build_pagerduty_event(sns_message)
        response = send_to_pagerduty(pd_event)

        logger.info("PagerDuty response: %s", response)
        return {"statusCode": 200, "body": "Forwarded to PagerDuty"}

    except Exception as e:
        logger.exception("Failed to forward alarm: %s", str(e))
        return {"statusCode": 500, "body": str(e)}


def parse_sns_event(event):
    """Extract and parse the CloudWatch Alarm payload from SNS."""
    records = event.get("Records", [])
    for record in records:
        sns = record.get("Sns", {})
        message_str = sns.get("Message", "")
        if message_str:
            try:
                return json.loads(message_str)
            except json.JSONDecodeError:
                logger.warning("Failed to parse SNS message as JSON")
                return None
    return None


def build_pagerduty_event(alarm):
    """Convert a CloudWatch Alarm payload to PagerDuty Events API v2 format."""
    alarm_name = alarm.get("AlarmName", "Unknown Alarm")
    new_state = alarm.get("NewStateValue", "ALARM")
    reason = alarm.get("NewStateReason", "No reason provided")
    region = alarm.get("Region", "us-east-1")
    account = alarm.get("AWSAccountId", "unknown")
    description = alarm.get("AlarmDescription", "")

    severity = SEVERITY_MAP.get(new_state, "info")
    event_action = "trigger" if new_state == "ALARM" else "resolve"

    if new_state == "OK":
        dedup_key = f"cloudmart:{alarm_name}"
    else:
        dedup_key = None

    payload = {
        "routing_key": ROUTING_KEY,
        "event_action": event_action,
        "dedup_key": dedup_key,
        "payload": {
            "summary": f"[{new_state}] {alarm_name}",
            "source": f"aws:cloudwatch:{region}",
            "severity": severity,
            "timestamp": alarm.get("StateChangeTime", ""),
            "component": alarm_name,
            "group": "CloudMart-DevOps-Project",
            "class": "Infrastructure",
            "custom_details": {
                "AWS Account": account,
                "Region": region,
                "Reason": reason,
                "Description": description,
                "Old State": alarm.get("OldStateValue", "UNKNOWN"),
            },
        },
    }

    if FROM_EMAIL:
        payload["payload"]["custom_details"]["From"] = FROM_EMAIL

    return payload


def send_to_pagerduty(event):
    """Send the event to PagerDuty Events API v2."""
    data = json.dumps(event).encode("utf-8")
    req = Request(
        PAGERDUTY_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urlopen(req, timeout=10) as response:
            return response.read().decode("utf-8")
    except HTTPError as e:
        logger.error("HTTP error %s: %s", e.code, e.read().decode())
        raise
    except URLError as e:
        logger.error("URL error: %s", str(e))
        raise
