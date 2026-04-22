import json
import logging
import os
import boto3
from boto3.dynamodb.types import TypeDeserializer
from google.oauth2 import service_account
from googleapiclient.discovery import build

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client("ssm")
deserializer = TypeDeserializer()

# Match the exact env vars from your dev/main.tf
SPREADSHEET_ID = os.environ["SPREADSHEET_ID"]
SSM_PARAM_NAME = os.environ["GCP_CREDENTIALS_SSM_NAME"]
SHEET_NAME     = os.environ.get("SHEET_NAME", "Sheet1") # Change to match your Google Sheet tab name!

# Cache the Sheets service outside the handler
_sheets_service = None

def deserialize_dynamo_image(image):
    """Converts DynamoDB JSON {'S': 'Value'} into standard Python {'Key': 'Value'}"""
    return {k: deserializer.deserialize(v) for k, v in image.items()}

def get_sheets_service():
    global _sheets_service
    if _sheets_service is not None:
        return _sheets_service

    # Fetch the SecureString from SSM
    response = ssm.get_parameter(
        Name=SSM_PARAM_NAME,
        WithDecryption=True,
    )

    creds_dict = json.loads(response["Parameter"]["Value"])
    credentials = service_account.Credentials.from_service_account_info(
        creds_dict,
        scopes=["https://www.googleapis.com/auth/spreadsheets"],
    )

    _sheets_service = build("sheets", "v4", credentials=credentials, cache_discovery=False)
    return _sheets_service


def sync_to_sheets(item: dict):
    """Appends a row to Google Sheets for this receipt."""
    service = get_sheets_service()

    # Extract the nested taxes safely
    taxes = item.get("Taxes", {})
    hst = float(taxes.get("HST", 0))
    gst = float(taxes.get("GST", 0))
    
    # Format the LineItems array into a readable string for a single spreadsheet cell
    line_items_raw = item.get("LineItems", [])
    line_items_str = "\n".join([f"{li.get('Description', 'Item')}: ${li.get('Amount', 0)}" for li in line_items_raw])

    # Map EVERY field from DynamoDB to a column
    row = [
        item.get("Date", ""),                        # Column A
        item.get("ReceiptID", ""),                   # Column B
        item.get("Vendor", ""),                      # Column C
        item.get("Category", ""),                    # Column D
        float(item.get("TotalAmount", 0)),           # Column E
        hst + gst,                                   # Column F
        item.get("TaxNumber", "Not Provided"),       # Column G
        item.get("PaymentMethod", "Unknown"),        # Column H
        item.get("NeedsReview", False),              # Column I
        item.get("S3_Pointer", ""),                  # Column J
        line_items_str                               # Column K
    ]

    service.spreadsheets().values().append(
        spreadsheetId=SPREADSHEET_ID,
        # Update the range to cover all 11 columns (A through K)
        range=f"{SHEET_NAME}!A:K", 
        valueInputOption="USER_ENTERED",
        insertDataOption="INSERT_ROWS",
        body={"values": [row]},
    ).execute()

    logger.info(f"Synced to Sheets: {item.get('Vendor')} ${item.get('TotalAmount')}")

def handler(event, context):
    # EventBridge Pipes sends the array directly
    logger.info(f"Received {len(event)} records from EventBridge Pipe")

    for record in event:
        event_name = record.get("eventName")

        # We set stream_view_type to NEW_IMAGE, so we only get INSERTs
        if event_name == "INSERT":
            # Clean up the raw DynamoDB payload
            raw_image = record["dynamodb"]["NewImage"]
            clean_item = deserialize_dynamo_image(raw_image)
            
            logger.info(f"New receipt to sync: {clean_item.get('Vendor')} on {clean_item.get('Date')}")
            sync_to_sheets(clean_item)

    return {"status": "success"}