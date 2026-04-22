import json
import boto3
import os
import base64
import logging
from openai import OpenAI

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

# Initialize OpenRouter client
openrouter_client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.environ.get('OPENROUTER_API_KEY'),
)

def handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # NEW: Parse the deeply nested EventBridge payload
        bucket_name = event['detail']['bucket']['name']
        object_key = event['detail']['object']['key']
    except KeyError:
        # Fallback just in case you trigger it manually from the console during testing
        bucket_name = event.get('bucket')
        object_key = event.get('key')
        
        if not bucket_name or not object_key:
            # NEW: RAISE the error so Step Functions knows it failed and routes to the DLQ!
            raise ValueError("Missing bucket or key in event payload")

    try:
        # 1. Fetch and encode the image
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        image_bytes = response['Body'].read()
        base64_image = base64.b64encode(image_bytes).decode('utf-8')

        # 2. Call OpenRouter Nemotron VL
        # 2. Call OpenRouter Nemotron VL
        completion = openrouter_client.chat.completions.create(
            model="nvidia/nemotron-nano-12b-v2-vl:free",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text", 
                            "text": """You are an expert accountant. Extract receipt data into a strict JSON object with exactly these keys:
                            - Vendor (string)
                            - Date (YYYY-MM-DD)
                            - TotalAmount (float)
                            - Taxes (object containing floats for GST, HST, PST, QST. Default to 0.0 if not present)
                            - TaxNumber (string, look for GST/HST registration number. Return "Not Provided" if missing)
                            - PaymentMethod (string, e.g., 'Visa-1234', 'Cash'. Return 'Unknown' if not visible)
                            - LineItems (list of objects, each with 'Description' (string) and 'Amount' (float))
                            - Category (string)
                            Return ONLY valid JSON. No markdown."""
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            extra_body={"reasoning": {"enabled": False}} 
        )

        # 3. Parse the JSON response
        raw_output = completion.choices[0].message.content
        parsed_data = json.loads(raw_output)
        
        # Add the S3 pointer
        parsed_data['S3_Pointer'] = f"s3://{bucket_name}/{object_key}"
        
        return parsed_data

    except Exception as e:
        logger.error(f"Failed to process receipt: {str(e)}")
        raise e