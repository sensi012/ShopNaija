import json
import logging
import os
from io import BytesIO

import boto3
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
sns = boto3.client("sns")

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")
SIZES = {"thumbnail": (150, 150), "medium": (600, 600)}


def handler(event, context):
    if not HAS_PIL:
        logger.error("PIL (Pillow) dependency is missing. Attach Pillow via a Lambda layer to process images.")
        return {"statusCode": 500, "body": json.dumps({"error": "PIL dependency missing"})}
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        logger.info("Processing upload: bucket=%s key=%s", bucket, key)

        try:
            original = s3.get_object(Bucket=bucket, Key=key)
            image_bytes = original["Body"].read()
            image = Image.open(BytesIO(image_bytes))
            image = image.convert("RGB")

            filename = os.path.basename(key)
            name, _ext = os.path.splitext(filename)

            for size_name, dimensions in SIZES.items():
                resized = image.copy()
                resized.thumbnail(dimensions)

                buffer = BytesIO()
                resized.save(buffer, format="JPEG", quality=85)
                buffer.seek(0)

                processed_key = f"processed/{size_name}/{name}.jpg"
                s3.put_object(
                    Bucket=bucket,
                    Key=processed_key,
                    Body=buffer,
                    ContentType="image/jpeg",
                )
                logger.info("Uploaded resized image: %s", processed_key)

            if SNS_TOPIC_ARN:
                sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="New product image processed - ShopNaija",
                    Message=json.dumps(
                        {
                            "bucket": bucket,
                            "original_key": key,
                            "processed_sizes": list(SIZES.keys()),
                        }
                    ),
                )

        except Exception as exc:  # noqa: BLE001
            logger.error("Failed processing %s/%s: %s", bucket, key, exc)
            raise

    return {"statusCode": 200, "body": json.dumps({"processed": len(event["Records"])})}
