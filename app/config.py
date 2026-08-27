"""
Config — reads database credentials from AWS Secrets Manager or environment variables.
DB_SECRET_ARN is injected via EC2 user_data at boot time.
DB_HOST / DB_PORT are also injected via user_data.
"""
import os
import json
import logging
from functools import lru_cache

logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_db_url() -> str:
    # Direct DATABASE_URL takes precedence (local dev)
    db_url = os.environ.get("DATABASE_URL")
    if db_url:
        logger.info("Using DATABASE_URL from environment")
        return db_url

    # Fetch credentials from Secrets Manager
    secret_arn = os.environ.get("DB_SECRET_ARN")
    db_host = os.environ.get("DB_HOST", "localhost")
    db_port = os.environ.get("DB_PORT", "5432")

    if not secret_arn:
        logger.warning("DB_SECRET_ARN not set — falling back to local defaults")
        return f"postgresql://postgres:postgres@{db_host}:{db_port}/shopnaija"

    try:
        import boto3
        client = boto3.client(
            "secretsmanager",
            region_name=os.environ.get("AWS_DEFAULT_REGION", "eu-west-1"),
        )
        response = client.get_secret_value(SecretId=secret_arn)
        secret = json.loads(response["SecretString"])
        username = secret["username"]
        password = secret["password"]
        dbname = secret.get("dbname", "shopnaija")
        url = f"postgresql://{username}:{password}@{db_host}:{db_port}/{dbname}"
        logger.info("DB credentials loaded from Secrets Manager")
        return url
    except Exception as exc:
        logger.error("Failed to fetch secret from Secrets Manager: %s", exc)
        return f"postgresql://postgres:postgres@{db_host}:{db_port}/shopnaija"


class Settings:
    SECRET_KEY: str = os.environ.get(
        "SECRET_KEY", "shopnaija-super-secret-key-change-in-prod-!!!!"
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    S3_BUCKET: str = os.environ.get("S3_BUCKET", "")
    AWS_REGION: str = os.environ.get("AWS_DEFAULT_REGION", "eu-west-1")
    CLOUDFRONT_URL: str = os.environ.get("CLOUDFRONT_URL", "https://d2phrl92j85lt6.cloudfront.net").rstrip("/")

    def image_url(self, key: str) -> str:
        """Return full URL for an S3 image key or external URL."""
        if not key:
            return ""
        if key.startswith("http://") or key.startswith("https://"):
            return key
        if self.CLOUDFRONT_URL:
            return f"{self.CLOUDFRONT_URL}/{key}"
        if self.S3_BUCKET:
            return (
                f"https://{self.S3_BUCKET}.s3.{self.AWS_REGION}"
                f".amazonaws.com/{key}"
            )
        return ""


settings = Settings()
