import os
import json
import boto3
import requests

s3_client = boto3.client("s3")

def handler(event, context):
    try:
        # 1. Secret Validation
        expected_secret = os.environ.get("TELEGRAM_SECRET")
        headers = event.get("headers", {}) or {}
        provided_secret = headers.get("X-Telegram-Bot-Api-Secret-Token") or headers.get("x-telegram-bot-api-secret-token")

        if not expected_secret or provided_secret != expected_secret:
            print("Unauthorized: Secret token mismatch or missing environment variable.")
            return {"statusCode": 403, "body": "Forbidden"}
        
        # 2. Parse Payload
        body = json.loads(event.get("body", "{}"))
        token = os.environ["TELEGRAM_TOKEN"]
        
        print(f"INCOMING PAYLOAD: {json.dumps(body)}")
        
        if "message" in body:
            chat_id = body["message"]["chat"]["id"]
            
            # 3. Process Photo
            if "photo" in body["message"]:
                photo_data = body["message"]["photo"][-1]
                file_id = photo_data["file_id"]
                
                file_info = requests.get(f"https://api.telegram.org/bot{token}/getFile?file_id={file_id}").json()
                file_path = file_info["result"]["file_path"]
                
                download_url = f"https://api.telegram.org/file/bot{token}/{file_path}"
                image_bytes = requests.get(download_url).content
                
                # 4. Direct S3 Upload
                bucket_name = os.environ["S3_BUCKET_NAME"]
                file_key = f"raw_receipts/{file_id}.jpg"
                
                s3_client.put_object(
                    Bucket=bucket_name,
                    Key=file_key,
                    Body=image_bytes,
                    ContentType="image/jpeg",
                    Metadata={
                        "telegram_user_id": str(body["message"]["from"]["id"]),
                        "telegram_username": body["message"]["from"].get("username", "unknown"),
                        "chat_id": str(chat_id)
                    }
                )
                
                # 5. Success UX Reply
                requests.post(f"https://api.telegram.org/bot{token}/sendMessage", json={
                    "chat_id": chat_id,
                    "text": "✅ Receipt captured! Processing now..."
                })
                
            # 6. Fallback UX Reply
            else:
                requests.post(f"https://api.telegram.org/bot{token}/sendMessage", json={
                    "chat_id": chat_id,
                    "text": "Send me a photo of a receipt! (Make sure to send it as a Photo, not a File)."
                })

        return {
            "statusCode": 200,
            "body": json.dumps({"status": "ok"})
        }

    except Exception as e:
        print(f"Error processing webhook: {str(e)}")
        # Always return 200 to Telegram so it stops retrying the failed message
        return {
            "statusCode": 200,
            "body": json.dumps({"status": "error", "message": "Internal server error"})
        }