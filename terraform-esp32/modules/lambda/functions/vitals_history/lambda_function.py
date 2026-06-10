import json
import boto3
import time
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('esp32-vitals')


def lambda_handler(event, context):
    """Get patient vitals history for last 30 days."""
    try:
        query_params = event.get('queryStringParameters') or {}
        patient_id = query_params.get('patient_id', 'esp32-health-monitor')
        limit = int(query_params.get('limit', 100))

        print(f"Fetching history for patient: {patient_id}, limit: {limit}")

        current_time = int(time.time())
        thirty_days_ago = current_time - (30 * 24 * 60 * 60)

        response = table.scan(
            FilterExpression='device_id = :did AND #ts >= :start_time',
            ExpressionAttributeNames={'#ts': 'timestamp'},
            ExpressionAttributeValues={
                ':did': patient_id,
                ':start_time': Decimal(str(thirty_days_ago))
            }
        )

        items = response.get('Items', [])
        print(f"Found {len(items)} items")

        sorted_items = sorted(
            items,
            key=lambda x: int(x.get('timestamp', 0)),
            reverse=True
        )[:limit]

        history_data = []
        for item in sorted_items:
            if 'payload' in item:
                payload = item.get('payload', {})
                heart_rate = int(payload.get('heart_rate', 0))
                spo2 = int(payload.get('spo2', 0))
            else:
                heart_rate = int(item.get('heart_rate', 0))
                spo2 = int(item.get('spo2', 0))

            timestamp = int(item.get('timestamp', 0))

            history_data.append({
                'heart_rate': heart_rate,
                'spo2': spo2,
                'timestamp': timestamp,
                'device_id': item.get('device_id', 'esp32-health-monitor')
            })

        print(f"Returning {len(history_data)} formatted records")

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({
                'patient_id': patient_id,
                'count': len(history_data),
                'history': history_data
            })
        }

    except Exception as e:
        print(f"ERROR: {str(e)}")
        import traceback
        traceback.print_exc()

        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'error': 'Failed to fetch history',
                'message': str(e)
            })
        }
