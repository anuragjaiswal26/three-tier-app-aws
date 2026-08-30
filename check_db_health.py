# This file has one job: check that the database is alive and reachable,
# using credentials fetched from Secrets Manager - never hardcoded here.

import boto3
import json
import psycopg2
from datetime import datetime

# --- Configuration: these match what Terraform created ---
AWS_REGION = "ap-southeast-2"
SECRET_NAME = "three-tier-app/db-password"
DB_HOST = "three-tier-db.cf682ewkibsv.ap-southeast-2.rds.amazonaws.com"
DB_NAME = "appdb"
DB_PORT = 5432


def get_db_credentials():
    """Ask Secrets Manager for the username and password. This is the IAM
    badge from iam.tf actually being used - EC2 is allowed to make this
    call because of the permission we wrote in that file."""
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    response = client.get_secret_value(SecretId=SECRET_NAME)
    secret = json.loads(response["SecretString"])
    return secret["username"], secret["password"]


def check_database():
    """Connect to RDS using those credentials, run a trivial check, and
    report a clear healthy/unhealthy result."""
    username, password = get_db_credentials()

    try:
        connection = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=username,
            password=password,
            connect_timeout=5,
        )
        cursor = connection.cursor()
        cursor.execute("SELECT 1;")
        cursor.fetchone()
        cursor.close()
        connection.close()

        print(
            f"[{datetime.now()}] Database check: HEALTHY - connected and responded successfully")
        return True

    except Exception as error:
        print(f"[{datetime.now()}] Database check: UNHEALTHY - {error}")
        return False


if __name__ == "__main__":
    check_database()
