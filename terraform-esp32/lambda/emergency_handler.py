"""
Lambda Function: emergency-handler
Handles two routes:
  POST /contacts          → Save emergency contacts to DynamoDB
  POST /trigger-emergency → Fetch contacts, publish SNS alert
"""

import json
import boto3
import os
import time
from decimal import Decimal

# ── AWS clients ───────────────────────────────────────────────
dynamodb = boto3.resource('dynamodb')
sns_client = boto3.client('sns', region_name=os.environ.get('AWS_REGION', 'me-central-1'))

# ── Environment variables (set in Lambda console) ──────────────
CONTACTS_TABLE = os.environ.get('CONTACTS_TABLE', 'emergency-contacts')
SNS_TOPIC_ARN  = os.environ.get('SNS_TOPIC_ARN', '')   # Set after creating SNS topic


# ─────────────────────────────────────────────────────────────
# MAIN HANDLER
# ─────────────────────────────────────────────────────────────

def lambda_handler(event, context):
    print(f"Event: {json.dumps(event)}")

    # HTTP API Gateway sends routeKey
    route = event.get('routeKey', '')
    path  = event.get('rawPath', '')

    # Route dispatcher
    if 'contacts' in path and event.get('requestContext', {}).get('http', {}).get('method') == 'POST':
        return save_contacts(event)
    elif 'trigger-emergency' in path:
        return trigger_emergency(event)
    else:
        return _response(404, {'error': 'Route not found'})


# ─────────────────────────────────────────────────────────────
# ROUTE 1: POST /contacts  →  Save contacts to DynamoDB
# ─────────────────────────────────────────────────────────────

def save_contacts(event):
    try:
        body = json.loads(event.get('body', '{}'))
        device_id = body.get('device_id', 'esp32-health-monitor')
        contacts  = body.get('contacts', [])

        if not contacts:
            return _response(400, {'error': 'No contacts provided'})

        table = dynamodb.Table(CONTACTS_TABLE)

        # Extract emails and phones lists
        emails = [c['email'] for c in contacts if c.get('email')]
        phones = [c['phone'] for c in contacts if c.get('phone')]
        names  = [c['name']  for c in contacts if c.get('name')]

        # Upsert into DynamoDB
        table.put_item(Item={
            'device_id':  device_id,
            'contacts':   json.dumps(contacts),
            'emails':     emails,
            'phones':     phones,
            'names':      names,
            'updated_at': int(time.time()),
        })

        print(f"✅ Saved {len(contacts)} contacts for {device_id}")

        # Subscribe new emails/phones to SNS topic
        _subscribe_to_sns(emails, phones)

        return _response(200, {
            'message': f'Saved {len(contacts)} contacts successfully',
            'device_id': device_id,
        })

    except Exception as e:
        print(f"❌ save_contacts error: {e}")
        return _response(500, {'error': str(e)})


def _subscribe_to_sns(emails, phones):
    """Subscribe email and phone contacts to SNS topic."""
    if not SNS_TOPIC_ARN:
        print("⚠️  SNS_TOPIC_ARN not set – skipping subscriptions")
        return

    for email in emails:
        try:
            sns_client.subscribe(
                TopicArn=SNS_TOPIC_ARN,
                Protocol='email',
                Endpoint=email,
                ReturnSubscriptionArn=True,
            )
            print(f"📧 Subscribed email: {email}")
        except Exception as e:
            print(f"Email subscription failed for {email}: {e}")

    for phone in phones:
        # Ensure E.164 format (+923001234567)
        normalized = phone if phone.startswith('+') else f'+{phone}'
        try:
            sns_client.subscribe(
                TopicArn=SNS_TOPIC_ARN,
                Protocol='sms',
                Endpoint=normalized,
                ReturnSubscriptionArn=True,
            )
            print(f"📱 Subscribed phone: {normalized}")
        except Exception as e:
            print(f"SMS subscription failed for {normalized}: {e}")


# ─────────────────────────────────────────────────────────────
# ROUTE 2: POST /trigger-emergency  →  Send SNS alert
# ─────────────────────────────────────────────────────────────

def trigger_emergency(event):
    try:
        body = json.loads(event.get('body', '{}'))

        device_id  = body.get('device_id', 'esp32-health-monitor')
        heart_rate = body.get('heart_rate', 0)
        spo2       = body.get('spo2', 0)
        latitude   = body.get('latitude', 0.0)
        longitude  = body.get('longitude', 0.0)
        is_test    = body.get('is_test', False)

        # Fetch contacts from DynamoDB
        table = dynamodb.Table(CONTACTS_TABLE)
        result = table.get_item(Key={'device_id': device_id})
        item   = result.get('Item')

        if not item:
            return _response(404, {
                'error': f'No contacts found for device: {device_id}'
            })

        contacts = json.loads(item.get('contacts', '[]'))
        emails   = item.get('emails', [])
        phones   = item.get('phones', [])

        print(f"📋 Found {len(contacts)} contacts, {len(emails)} emails, {len(phones)} phones")

        # Build alert message
        maps_link  = f"https://maps.google.com/?q={latitude},{longitude}"
        timestamp  = time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())
        test_label = '[TEST] ' if is_test else ''

        subject = f"{test_label}🚨 EMERGENCY ALERT - Patient: {device_id}"

        message = f"""
{'='*50}
🚨 {test_label}EMERGENCY ALERT
{'='*50}

Patient ID  : {device_id}
Heart Rate  : {heart_rate} bpm
SpO2 Level  : {spo2}%
Location    : {maps_link}
Time        : {timestamp}

{'⚠️  CRITICAL: Heart rate or SpO2 is at dangerous levels!' if not is_test else '✅ This is a TEST alert only - no real emergency.'}

Please check on the patient immediately.

--
ESP32 Health Monitor System
{'='*50}
"""

        # Publish to SNS
        if not SNS_TOPIC_ARN:
            return _response(500, {'error': 'SNS_TOPIC_ARN not configured'})

        sns_response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message,
            MessageAttributes={
                'AWS.SNS.SMS.SenderID': {
                    'DataType': 'String',
                    'StringValue': 'EMERGENCY',
                },
                'AWS.SNS.SMS.SMSType': {
                    'DataType': 'String',
                    'StringValue': 'Transactional',   # Higher delivery priority
                },
            },
        )

        message_id = sns_response.get('MessageId', 'unknown')
        print(f"✅ Alert published! MessageId: {message_id}")

        return _response(200, {
            'message': f'Alert sent to {len(emails)} emails and {len(phones)} phones',
            'message_id': message_id,
            'is_test': is_test,
        })

    except Exception as e:
        print(f"❌ trigger_emergency error: {e}")
        return _response(500, {'error': str(e)})


# ─────────────────────────────────────────────────────────────
# HELPER
# ─────────────────────────────────────────────────────────────

def _response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
        },
        'body': json.dumps(body),
    }
