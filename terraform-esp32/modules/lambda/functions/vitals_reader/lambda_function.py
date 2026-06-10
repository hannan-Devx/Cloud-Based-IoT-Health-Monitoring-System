import json
import boto3
import time


def lambda_handler(event, context):
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('esp32-vitals')

        # Simple scan to get all items, then sort by timestamp
        response = table.scan()

        if response['Items']:
            # Sort items by timestamp (latest first)
            items = sorted(response['Items'], key=lambda x: int(x['timestamp']), reverse=True)
            latest_item = items[0]

            # Check if data is nested under 'payload' key or direct
            if 'payload' in latest_item:
                payload_data = latest_item['payload']
                vitals_data = {
                    'heart_rate': int(payload_data.get('heart_rate', 0)),
                    'spo2': int(payload_data.get('spo2', 0)),
                    'timestamp': int(payload_data.get('timestamp', time.time())),
                    'device_id': payload_data.get('device_id', 'esp32-health-monitor'),
                    'status': 'connected'
                }
            else:
                vitals_data = {
                    'heart_rate': int(latest_item.get('heart_rate', 0)),
                    'spo2': int(latest_item.get('spo2', 0)),
                    'timestamp': int(latest_item.get('timestamp', time.time())),
                    'device_id': latest_item.get('device_id', 'esp32-health-monitor'),
                    'status': 'connected'
                }
        else:
            vitals_data = {
                'heart_rate': 0,
                'spo2': 0,
                'timestamp': int(time.time()),
                'device_id': 'esp32-health-monitor',
                'status': 'no_data'
            }

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
            },
            'body': json.dumps(vitals_data)
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'error': 'Failed to fetch ESP32 vitals data',
                'message': str(e)
            })
        }
