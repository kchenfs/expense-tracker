import os
import json
import boto3
import requests

# Pre-initialize the S3 client
s3_client = boto3.client("s3")

def handler(event, context):
    # Telegram sends the webhook payload in the body
    body = json.loads(event.get("body", "{}"))
    
    # 1. Validate this is a photo message
    if "message" in body and "photo" in body["message"]:
        # Get the highest resolution version (last in the list)
        photo_data = body["message"]["photo"][-1]
        file_id = photo_data["file_id"]
        
        # 2. Get file path from Telegram API
        token = os.environ["TELEGRAM_TOKEN"]
        file_info = requests.get(f"https://api.telegram.org/bot{token}/getFile?file_id={file_id}").json()
        file_path = file_info["result"]["file_path"]
        
        # 3. Download the image bytes
        download_url = f"https://api.telegram.org/file/bot{token}/{file_path}"
        image_bytes = requests.get(download_url).content
        
        # 4. Upload directly to S3
        bucket_name = os.environ["S3_BUCKET_NAME"]
        file_key = f"raw_receipts/{file_id}.jpg"
        
        s3_client.put_object(
            Bucket=bucket_name,
            Key=file_key,
            Body=image_bytes,
            ContentType="image/jpeg"
        )
        
        # 5. Notify the user
        chat_id = body["message"]["chat"]["id"]
        requests.post(f"https://api.telegram.org/bot{token}/sendMessage", json={
            "chat_id": chat_id,
            "text": "✅ Receipt captured! Processing now..."
        })

    return {
        "statusCode": 200,
        "body": json.dumps({"status": "ok"})
    }