/*
Ceres - Realtime Website Uptime Monitoring and Reporting
Developed by the Campus Web Services Team at the University of Arizona
Powered via AWS and Terraform
*/

#===============================================================================
# Define Environment for Deploy
#===============================================================================
resource "random_id" "id" {
    byte_length = 8
}

locals {
    PREFIX = "ceres"
}

#===============================================================================
# Define Environment Variables
#===============================================================================

variable "slack_hook_url" {
    type    = string
}

variable "frequency_expression" {
    type    = string
    default = "rate(2 minutes)"
}

#===============================================================================
# Create IAM Policies
#===============================================================================
# Lambda Basic Execution
resource "aws_iam_policy" "lambda_basic_execution_iam_policy" {
    name        = "${local.PREFIX}_lambda_basic_execution_iam_policy_${random_id.id.hex}"
    path        = "/"
    description = "Lambda Basic Execution Policy"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
            }
        ]
    }
EOF
}

# SQS Policy
resource "aws_iam_policy" "sqs_iam_policy" {
    name        = "${local.PREFIX}_sqs_iam_policy_${random_id.id.hex}"
    path        = "/"
    description = "Access to Queue"

    # Need to rewrite
    policy = <<EOF
{
   "Version": "2012-10-17",
   "Id": "Queue1_Policy_UUID",
   "Statement": [{
      "Sid":"QueueAllActions",
      "Effect": "Allow",
      "Action": "sqs:*",
      "Resource": "${aws_sqs_queue.queue.arn}"
   }]
}
EOF
}

# DynamoDB Policy for site status table
resource "aws_iam_policy" "site_status_table_iam_policy" {
    name        = "${local.PREFIX}_site_status_table_iam_policy_${random_id.id.hex}"
    path        = "/"
    description = "Access to site_status_table"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListAndDescribe",
            "Effect": "Allow",
            "Action": [
                "dynamodb:List*",
                "dynamodb:DescribeReservedCapacity*",
                "dynamodb:DescribeLimits",
                "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SpecificTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/${aws_dynamodb_table.site_status.name}"
        }
    ]
}
EOF
}

# Create DynamoDB Policy for outage logs table
resource "aws_iam_policy" "outage_logs_table_iam_policy" {
    name        = "${local.PREFIX}_outage_logs_table_iam_policy_${random_id.id.hex}"
    path        = "/"
    description = "Access to outage_logs_table"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListAndDescribe",
            "Effect": "Allow",
            "Action": [
                "dynamodb:List*",
                "dynamodb:DescribeReservedCapacity*",
                "dynamodb:DescribeLimits",
                "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SpecificTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/${aws_dynamodb_table.outage_logs.name}"
        }
    ]
}
EOF
}

#===============================================================================
# Create IAM Role for fill_queue
#===============================================================================
# Create IAM Role for fill_queue
resource "aws_iam_role" "fill_queue_iam_role" {
    name    = "${local.PREFIX}_fill_queue_iam_role_${random_id.id.hex}"

    assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}

# Attach Policies to Role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_attach" {
    role        = aws_iam_role.fill_queue_iam_role.name
    policy_arn  = aws_iam_policy.lambda_basic_execution_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "sqs_attach" {
    role        = aws_iam_role.fill_queue_iam_role.name
    policy_arn  = aws_iam_policy.sqs_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "janus_info_storage_rw_attach" {
    role        = aws_iam_role.fill_queue_iam_role.name
    policy_arn  = aws_iam_policy.sites_bucket_policy.arn
}

#===============================================================================
# Create IAM Role for ping
#===============================================================================
# Create IAM Role for ping
resource "aws_iam_role" "ping_iam_role" {
    name    = "${local.PREFIX}_ping_iam_role_${random_id.id.hex}"

    assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}

# Attach Policies to Role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_attach3" {
    role        = aws_iam_role.ping_iam_role.name
    policy_arn  = aws_iam_policy.lambda_basic_execution_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "site_status_table_attach" {
    role        = aws_iam_role.ping_iam_role.name
    policy_arn  = aws_iam_policy.site_status_table_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "outage_logs_table_attach" {
    role        = aws_iam_role.ping_iam_role.name
    policy_arn  = aws_iam_policy.outage_logs_table_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "sqs_attach3" {
    role        = aws_iam_role.ping_iam_role.name
    policy_arn  = aws_iam_policy.sqs_iam_policy.arn
}

#===============================================================================
# Create Sites S3 Bucket
#===============================================================================
# Create S3 Bucket
resource "aws_s3_bucket" "sites_bucket" {
    bucket  = "${local.PREFIX}-site-list-${random_id.id.hex}"
    acl     = "private"

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}

# Block All Public Access to Bucket
resource "aws_s3_account_public_access_block" "block" {
    block_public_acls   = true
    block_public_policy = true
}

#===============================================================================
# Upload Sites List to S3 Bucket
#===============================================================================
resource "aws_s3_bucket_object" "sites_list" {
    bucket  = aws_s3_bucket.sites_bucket.bucket
    key     = "sites-list.json"
    source  = "sites-list.json"

    content_type = "application/json"
}

#===============================================================================
# Create Sites S3 Bucket Access Policy
#===============================================================================
# Create S3 Bucket Access Policy
resource "aws_iam_policy" "sites_bucket_policy" {
    name        = "${local.PREFIX}_sites_bucket_policy_${random_id.id.hex}"
    path        = "/"
    description = "Access to sites bucket"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "${aws_s3_bucket.sites_bucket.arn}"
            ]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "${aws_s3_bucket.sites_bucket.arn}/*"
            ]
        }
    ]
}
EOF
}

#===============================================================================
# Create SQS for Queue
#===============================================================================
# Creates queue SQS
resource "aws_sqs_queue" "queue" {
    name                        = "${local.PREFIX}_queue_${random_id.id.hex}"
    delay_seconds               = 0
    max_message_size            = 2048
    message_retention_seconds   = 3600
    receive_wait_time_seconds   = 5
    visibility_timeout_seconds  = 900

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}

#===============================================================================
# Create Lambda for fill_queue
#===============================================================================
# Creates fill_queue Lambda Function
resource "aws_lambda_function" "fill_queue" {
    filename = "fill_queue_build.zip"
    function_name = "${local.PREFIX}_fill_queue_${random_id.id.hex}"
    role = aws_iam_role.fill_queue_iam_role.arn
    handler = "fill_queue.lambda_handler"

    #source_code_hash = data.archive_file.fill_queue_lambda_zip.output_base64sha256
    source_code_hash = filebase64sha256("fill_queue_build.zip")

    runtime = "python3.7"

    environment {
        variables ={
            QUEUE_NAME  = aws_sqs_queue.queue.name,
            BUCKET_NAME = aws_s3_bucket.sites_bucket.bucket
        }
    }

    timeout = 16

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}

# Create CloudWatch to Trigger Lambda
resource "aws_cloudwatch_event_rule" "priority_cloudwatch" {
    name                = "${local.PREFIX}_priority_trigger_${random_id.id.hex}"
    description         = "trigger every 2 minutes"
    schedule_expression = var.frequency_expression
}

# Attach CloudWatch to fill_queue
resource "aws_cloudwatch_event_target" "priority_cloudwatch_attach" {
    rule        = aws_cloudwatch_event_rule.priority_cloudwatch.name
    arn         = aws_lambda_function.fill_queue.arn

}

# Give CloudWatch Permission to Trigger Lambda
resource "aws_lambda_permission" "allow_cloud_watch_to_trigger_fill_queue" {
    statement_id    = "AllowExecutionFromCloudWatch"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.fill_queue.function_name
    principal       = "events.amazonaws.com"
    source_arn      = aws_cloudwatch_event_rule.priority_cloudwatch.arn
}

#===============================================================================
# Create Lambda for ping
#===============================================================================
# Create Lambda Function
resource "aws_lambda_function" "ping" {
    filename = "ping_build.zip"
    function_name = "${local.PREFIX}_ping_${random_id.id.hex}"
    role = aws_iam_role.ping_iam_role.arn
    handler = "ping.lambda_handler"

    #source_code_hash = data.archive_file.ping_lambda_zip.output_base64sha256
    source_code_hash = filebase64sha256("ping_build.zip")

    runtime = "python3.7"

    environment {
        variables = {
            LOG_TABLE_NAME = aws_dynamodb_table.outage_logs.name,
            TABLE_NAME = aws_dynamodb_table.site_status.name,
            SLACK_HOOK_URL = var.slack_hook_url,
            QUEUE_NAME = aws_sqs_queue.queue.name
        }
    }

    timeout = 120

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}

# Create SQS Lambda Trigger
resource "aws_lambda_event_source_mapping" "queue_trigger" {
    event_source_arn    = aws_sqs_queue.queue.arn
    function_name       = aws_lambda_function.ping.arn
}

#===============================================================================
# Create DynamoDB Table for site_status
#===============================================================================
resource "aws_dynamodb_table" "site_status" {
    name                = "${local.PREFIX}_site_status_${random_id.id.hex}"
    billing_mode        = "PROVISIONED"
    read_capacity       = 5
    write_capacity      = 5
    hash_key            = "site_name"

    attribute {
        name = "site_name"
        type = "S"
    }

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}

#===============================================================================
# Create DynamoDB Table for outage_logs
#===============================================================================
resource "aws_dynamodb_table" "outage_logs" {
    name                = "${local.PREFIX}_outage_logs_${random_id.id.hex}"
    billing_mode        = "PROVISIONED"
    read_capacity       = 5
    write_capacity      = 5
    hash_key            = "site_key"

    attribute {
        name = "site_key"
        type = "S"
    }

    tags = {
        Name = "${local.PREFIX}${random_id.id.hex}"
    }
}
