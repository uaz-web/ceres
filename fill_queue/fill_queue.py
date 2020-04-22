import boto3, json, os, re

QUEUE_NAME = os.environ["QUEUE_NAME"]
BUCKET_NAME = os.environ["BUCKET_NAME"]

def lambda_handler(event, context):
    # Load Sites List from S3 Bucket
    s3 = boto3.client('s3')
    data = s3.get_object(Bucket=BUCKET_NAME, Key="sites-list.json")
    sites_list = json.loads(data['Body'].read())

    # Process Sites List into Array
    all_sites_names = []
    for x in sites_list['sites']:
        all_sites_names.append(x)

    # Get Queue Information
    sqs = boto3.resource('sqs')
    queue = sqs.get_queue_by_name(QueueName=QUEUE_NAME)

    # Define Batch Jobs for Queue
    maxBatchSize = 10
    chunks = [all_sites_names[x:x+maxBatchSize] 
                for x in range(0, len(all_sites_names), maxBatchSize)]
    num_chunks = 1

    # Batch Jobs for Queue and Send
    for chunk in chunks:
        entries = []
        for site_name in chunk:
            variables = {'site_name': site_name, 'attempt_num': 2}
            entry = {'Id': re.sub(r'\W+', '', site_name),
                    'MessageBody': json.dumps(variables)}
            entries.append(entry)
        # Send Batch to Queue
        response = queue.send_messages(Entries=entries)
        print(response)
