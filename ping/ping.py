import boto3
import requests
import os
import json
import random
import datetime
#import traceback
import re
import urllib3
from requests import RequestException
from datetime import datetime

# Disable InsecureRequestWarning
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Environment Variables
SLACK_HOOK_URL = os.environ['SLACK_HOOK_URL']
TABLE_NAME = os.environ['TABLE_NAME']
LOG_TABLE_NAME = os.environ['LOG_TABLE_NAME']
QUEUE_NAME = os.environ['QUEUE_NAME']

# Run Domain for Status Code
def lambda_handler(event, context):
    for record in event['Records']:
        data = json.loads(record['body'])
        handle_data(data)
    return ""

def handle_data(data):
    site_name = data["site_name"]
    attempt_num = data['attempt_num']
    site_url = site_name
    # Determine Website Status
    http_status_code = ping(site_url)
    print(site_name + " status: " + http_status_code)

    if attempt_num > 2:
        if site_is_down(http_status_code):
            actual_status = "down"
            db_results = check_db(site_name, actual_status, http_status_code, site_url)
    else:
        if site_is_down(http_status_code):
            # Send A Retry Message to SQS
            attempt_num = attempt_num + 1
            add_to_queue(site_name, attempt_num)
        else: 
            actual_status = "up"
            db_results = check_db(site_name, actual_status, http_status_code, site_url)
    return ""

def site_is_down(http_status_code):
    return http_status_code[0] not in ['2','3','4']

# Function to Get HTTP Status Code
def ping(site_url):
    # Generate URL with Semi-Random Paramater to Bypass Cache
    url = site_url.strip() + "?" + str(random.randint(100000, 999999))
    url = re.sub(r'^https?://','', url)
    url = "http://" + url
    try:
        r = requests.get(url, headers={"User-Agent": "demeter"}, timeout=20, verify=False)
        http_status_code = str(r.status_code)
    except RequestException as e:
        #traceback.print_exc()
        exception_type = type(e).__name__
        http_status_code = exception_type + ": " + str(e)
    return http_status_code

def send_slack_message(message):
    print("sending message to slack:")
    # Send Notification to Slack
    try:
        r = requests.post(url=SLACK_HOOK_URL, data=json.dumps(message), headers={'Content-Type' : 'application/json'}, timeout=10)
        result = r.text
    except RequestException as e:
        #traceback.print_exc()
        exception_type = type(e).__name__
        result = exception_type + ": " + str(e)
    return result

# Function to add another Message to Queue
def add_to_queue(site_name, attempt_num):
    variables = {'site_name': site_name, 'attempt_num': attempt_num}
    sqs = boto3.resource('sqs')
    queue = sqs.get_queue_by_name(QueueName=QUEUE_NAME)
    response = queue.send_message(MessageBody=json.dumps(variables), DelaySeconds=10)

# Function to check the current recorded status of the site and determine if
# a slack message needs to be sent and then to update the database accordingly
def check_db(site_name, actual_status, http_status_code, site_url):
    dynamodb1 = boto3.resource('dynamodb').Table(TABLE_NAME)
    dynamodb2 = boto3.resource('dynamodb').Table(LOG_TABLE_NAME) 
    response = dynamodb1.get_item(TableName=TABLE_NAME, Key={'site_name': site_name})
    print(response)
    try:
        db_site_status = response.get('Item').get('site_status')
    except: 
        creation_response = dynamodb1.update_item(TableName=TABLE_NAME,Key={'site_name':site_name},UpdateExpression='SET site_status = :values',ExpressionAttributeValues={':values': 'up'})
        attempt_num = 0
        add_to_queue(site_name, attempt_num)
    else: 
        print("Database Status: " + db_site_status)
        print("Actual Status: " + actual_status)
        if db_site_status != actual_status:
            timestamp = datetime.now().timestamp()
            if actual_status == "up":
                up_timestamp = int(timestamp)
                down_timestamp = response.get('Item').get('down_timestamp')
                site_key = response.get('Item').get('site_key')
                time_diff = up_timestamp - down_timestamp
                
                outage_time = convert_time(time_diff)

                text = "<!here> " + site_name + " - STATUS: UP - OUTAGE TIME: " + outage_time + " - URL: " + site_url

                # Send Slack Message
                message = {"attachments": [{"text": text,"color": "#22bb33"}]}
                result = send_slack_message(message)
                # Log to Demeter Site Status Table
                db_response = dynamodb1.update_item(TableName=TABLE_NAME,Key={'site_name':site_name},UpdateExpression='SET site_status = :value1, up_timestamp = :value2',ExpressionAttributeValues={':value1': 'up', ':value2': up_timestamp})
                # Log to Demeter Downtime Log Table
                db_log_response = dynamodb2.update_item(TableName=LOG_TABLE_NAME,Key={'site_key':site_key},UpdateExpression='SET up_timestamp = :value1, outage_time = :value2',ExpressionAttributeValues={':value1': up_timestamp, ':value2': outage_time})
                print(db_response)
                print(db_log_response)
            elif actual_status == "down":
                text = "<!here> " + site_name + " - STATUS: DOWN - STATUS CODE: " + http_status_code + " - URL: " + site_url
                message = {"attachments": [{"text": text,"color": "bb2124"}]}
                result = send_slack_message(message)
                down_timestamp = int(timestamp)
                site_key = site_name + '-' + str(down_timestamp)
                # Log to Demeter Site Status Table
                db_response = dynamodb1.update_item(TableName=TABLE_NAME,Key={'site_name':site_name},UpdateExpression='SET site_status = :value1, site_key = :value2, down_timestamp = :value3',ExpressionAttributeValues={':value1': 'down', ':value2': site_key, ':value3': down_timestamp})
                # Log to Demeter Downtime Log Table
                db_log_response = dynamodb2.update_item(TableName=LOG_TABLE_NAME,Key={'site_key':site_key},UpdateExpression='SET status_code = :value1, down_timestamp = :value2',ExpressionAttributeValues={':value1': http_status_code, ':value2': down_timestamp})
                print("LOG ERRORS: " + site_name + " IS DOWN - SITE_KEY IS " + site_key)
                print(db_response)
                print(db_log_response)

def convert_time(seconds):
    min, sec = divmod(seconds, 60)
    hour, min = divmod(min, 60)
    return "%d Hours %02d Minutes %02d Seconds " % (hour, min, sec)