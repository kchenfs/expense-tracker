import json
import boto3
import os
import logging
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize outside the handler for warm starts
sfn_client = boto3.client('stepfunctions')

def handler(event, context):
    logger.info(f"Received S3 event: {json.dumps(event)}")
    state_machine_arn = os.environ.get('STATE_MACHINE_ARN')
    
    if not state_machine_arn:
        raise ValueError("STATE_MACHINE_ARN environment variable is missing.")

    # S3 events can contain multiple records (e.g., if multiple files upload at the exact same millisecond)
    for record in event['Records']:
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']
        
        # This is the exact payload our OCR Parser Lambda is expecting!
        payload = {
            "bucket": bucket_name,
            "key": object_key
        }
        
        try:
            # Start the Step Function execution
            response = sfn_client.start_execution(
                stateMachineArn=state_machine_arn,
                name=f"receipt-job-{uuid.uuid4()}", # Unique execution name
                input=json.dumps(payload)
            )
            logger.info(f"Successfully started Step Function execution: {response['executionArn']}")
            
        except Exception as e:
            logger.error(f"Failed to start Step Function: {str(e)}")
            raise e

    return {"statusCode": 200, "body": "Executions started successfully"}