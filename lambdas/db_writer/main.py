import os
import json
import boto3
import uuid
import logging
from decimal import Decimal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    logger.info(f"Received payload from OCR Lambda: {json.dumps(event)}")

    table_name = os.environ.get('DYNAMODB_TABLE_NAME')
    if not table_name:
        raise ValueError("DYNAMODB_TABLE_NAME environment variable is missing.")

    table = dynamodb.Table(table_name)

    try:
        # THE TRICK: Convert the entire payload, replacing all nested floats with Decimals natively
        payload_str = json.dumps(event)
        event_decimal = json.loads(payload_str, parse_float=Decimal)

        payment_method = event_decimal.get('PaymentMethod', 'Unknown')
        needs_review = (payment_method == 'Unknown')

        item = {
            'ReceiptID': str(uuid.uuid4()),
            'Vendor': event_decimal.get('Vendor', 'Unknown'),
            'Date': event_decimal.get('Date', 'Unknown'),
            'TotalAmount': event_decimal.get('TotalAmount', Decimal('0.0')),
            'Taxes': event_decimal.get('Taxes', {}),
            'TaxNumber': event_decimal.get('TaxNumber', 'Not Provided'),
            'PaymentMethod': payment_method,
            'LineItems': event_decimal.get('LineItems', []),
            'Category': event_decimal.get('Category', 'Uncategorized'),
            'S3_Pointer': event_decimal.get('S3_Pointer', 'Unknown'),
            'NeedsReview': needs_review
        }

        table.put_item(Item=item)
        logger.info(f"Successfully wrote comprehensive item to DynamoDB: {item['ReceiptID']}")

        return {"status": "success", "ReceiptID": item['ReceiptID']}

    except Exception as e:
        logger.error(f"Error writing to DynamoDB: {str(e)}")
        raise e