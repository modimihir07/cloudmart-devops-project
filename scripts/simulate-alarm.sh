#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# CloudMart DevOps Project - Simulate CloudWatch Alarm → PagerDuty
# Tests the alerting pipeline end-to-end
# ─────────────────────────────────────────────────────────────
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
SNS_TOPIC_ARN="${SNS_TOPIC_ARN:-arn:aws:sns:${AWS_REGION}:YOUR_ACCOUNT_ID:cloudmart-alerts}"
LAMBDA_FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-cloudmart-pagerduty-forwarder}"
PAGERDUTY_INTEGRATION_KEY="${PAGERDUTY_INTEGRATION_KEY:-}"

echo "━━━ CloudMart DevOps Project - Alarm Simulation ━━━━━━━━━━━━━━━━"
echo "Region:   ${AWS_REGION}"
echo "SNS Topic: ${SNS_TOPIC_ARN}"
echo "Lambda:   ${LAMBDA_FUNCTION_NAME}"
echo ""

simulate_cloudwatch_alarm() {
    local alarm_name="$1"
    local state="$2"
    local reason="$3"

    cat <<EOF
{
    "AlarmName": "${alarm_name}",
    "AlarmDescription": "Simulated alarm for testing",
    "AWSAccountId": "YOUR_ACCOUNT_ID",
    "NewStateValue": "${state}",
    "NewStateReason": "${reason}",
    "StateChangeTime": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "Region": "${AWS_REGION}",
    "OldStateValue": "OK",
    "Trigger": {
        "MetricName": "SimulatedMetric",
        "Namespace": "CloudMart/Simulated",
        "StatisticType": "Sum",
        "Statistic": "SUM",
        "Period": 300,
        "EvaluationPeriods": 1,
        "ComparisonOperator": "GreaterThanThreshold",
        "Threshold": 1.0
    }
}
EOF
}

# Test 1: High Error Rate alarm
echo "[1/3] Simulating HighErrorRate alarm (ALARM state)..."
simulate_cloudwatch_alarm \
    "cloudmart-dev-HighErrorRate" \
    "ALARM" \
    "Threshold Crossed: 1 out of 1 datapoints > threshold (5.0%)" \
> /tmp/cloudmart-alarm.json

aws sns publish \
    --region "${AWS_REGION}" \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --message file:///tmp/cloudmart-alarm.json \
    --subject "ALARM: CloudMart High Error Rate" \
    --message-attributes "AlarmName={DataType=String,StringValue=cloudmart-dev-HighErrorRate}"

echo "[OK] Published HighErrorRate alarm to SNS"

# Test 2: Service Down alarm
echo "[2/3] Simulating ServiceDown alarm (ALARM state)..."
simulate_cloudwatch_alarm \
    "cloudmart-dev-ServiceDown" \
    "ALARM" \
    "Service product-catalog has been unreachable for 5 minutes" \
> /tmp/cloudmart-alarm2.json

aws sns publish \
    --region "${AWS_REGION}" \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --message file:///tmp/cloudmart-alarm2.json \
    --subject "ALARM: CloudMart Service Down" \
    --message-attributes "AlarmName={DataType=String,StringValue=cloudmart-dev-ServiceDown}"

echo "[OK] Published ServiceDown alarm"

# Test 3: OK recovery
echo "[3/3] Simulating recovery (OK state)..."
simulate_cloudwatch_alarm \
    "cloudmart-dev-HighErrorRate" \
    "OK" \
    "Threshold Crossed: 1 out of 1 datapoints < threshold (5.0%)" \
> /tmp/cloudmart-ok.json

aws sns publish \
    --region "${AWS_REGION}" \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --message file:///tmp/cloudmart-ok.json \
    --subject "OK: CloudMart High Error Rate recovered" \
    --message-attributes "AlarmName={DataType=String,StringValue=cloudmart-dev-HighErrorRate}"

echo "[OK] Published recovery"

# Check Lambda logs
echo ""
echo "━━━ Lambda Execution Logs (last 3) ─━━━━━━━━━━━━━━━━━━"
aws logs describe-log-streams \
    --region "${AWS_REGION}" \
    --log-group-name "/aws/lambda/${LAMBDA_FUNCTION_NAME}" \
    --order-by LastEventTime \
    --descending \
    --max-items 3 \
    --query 'logStreams[].logStreamName' \
    --output text 2>/dev/null | tr '\t' '\n' | while IFS= read -r stream; do
    if [[ -n "${stream}" ]]; then
        echo "Log stream: ${stream}"
        aws logs get-log-events \
            --region "${AWS_REGION}" \
            --log-group-name "/aws/lambda/${LAMBDA_FUNCTION_NAME}" \
            --log-stream-name "${stream}" \
            --limit 5 \
            --query 'events[].message' \
            --output text 2>/dev/null || echo "  (no recent events)"
    fi
done

echo ""
echo "━━━ Simulation Complete ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Check PagerDuty for triggered incidents."
echo "To test PagerDuty direct integration (without Lambda):"
echo "  curl -X POST https://events.pagerduty.com/v2/enqueue \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"routing_key\":\"YOUR_KEY\",\"event_action\":\"trigger\",\"payload\":{\"summary\":\"CloudMart test alarm\",\"source\":\"simulate-alarm.sh\",\"severity\":\"critical\"}}'"
