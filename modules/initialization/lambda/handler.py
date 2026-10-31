"""Initialize one schema-scoped database account without exposing credentials."""

import json
import os
import secrets
import ssl
from pathlib import Path


def application_credentials(secret_client, secret_arn):
    try:
        application = json.loads(secret_client.get_secret_value(SecretId=secret_arn)["SecretString"])
    except secret_client.exceptions.ResourceNotFoundException:
        application = {
            "username": "wordpress",
            "password": secrets.token_urlsafe(40),
            "admin_username": "schooladmin",
            "admin_password": secrets.token_urlsafe(40),
            "salts": {key: secrets.token_urlsafe(48) for key in (
                "AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
                "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT",
            )},
        }
        # Persist before SQL so a retry reuses the same password after interruption.
        secret_client.put_secret_value(
            SecretId=secret_arn, SecretString=json.dumps(application)
        )
    if application["username"] != "wordpress":
        raise ValueError("Unexpected application username")
    return application


def initialize(secret_client, connect, settings):
    master = json.loads(secret_client.get_secret_value(SecretId=settings["MASTER_SECRET_ARN"])["SecretString"])
    tls = ssl.create_default_context(cafile=str(Path(__file__).with_name("global-bundle.pem")))
    connection = connect(
        host=settings["DB_ADDRESS"], port=3306, user=master["username"], password=master["password"],
        database="wordpress", ssl=tls, connect_timeout=10, read_timeout=20,
        write_timeout=20, autocommit=True,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT GET_LOCK('xtremax_database_init', 30)")
            if cursor.fetchone()[0] != 1:
                raise RuntimeError("Database initialization lock unavailable")
            try:
                # Serialize both secret generation and SQL to prevent concurrent
                # invocations from publishing a different password than the DB uses.
                application = application_credentials(secret_client, settings["APPLICATION_SECRET_ARN"])
                cursor.execute("CREATE USER IF NOT EXISTS 'wordpress'@'%%' IDENTIFIED BY %s REQUIRE SSL", (application["password"],))
                cursor.execute("ALTER USER 'wordpress'@'%%' IDENTIFIED BY %s REQUIRE SSL", (application["password"],))
                cursor.execute("GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wordpress'@'%'")
            finally:
                cursor.execute("SELECT RELEASE_LOCK('xtremax_database_init')")
    finally:
        connection.close()
    return {"ready": True}


def handler(event, context):
    # boto3 is supplied by the managed Lambda runtime; no static credentials.
    import boto3
    import pymysql
    from botocore.config import Config

    config = Config(retries={"total_max_attempts": 3, "mode": "standard"}, connect_timeout=5, read_timeout=10)
    client = boto3.client("secretsmanager", config=config)
    try:
        return initialize(client, pymysql.connect, os.environ)
    except Exception:
        # SQL exceptions can include SQL/password text. Never propagate their details.
        raise RuntimeError("Database initialization failed; check database, network and IAM configuration") from None
