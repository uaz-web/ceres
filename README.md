# Ceres - Realtime Website Uptime Monitoring and Reporting
Developed by the Campus Web Services Team at the University of Arizona.

### Description 
Ceres performs realtime uptime monitoring for a specificed list of URLs using serverless technologies. 

Ceres will notify a specified Slack Channel when an outage occurs. It will then send another notification when the outage is over, including an approximate duration of the outage. It will also keep a record of all incidents in a DynamoDB table which can be used for further analysis. 

### General Notes
* Ceres currently attempts to downgrade all URLs to use HTTP instead of HTTPS in an attempt to play better with non-HTTPS sites. This can be changed in the ping.py script. 

### Pre-requisites 
The following need to be installed and configured in order to deploy Ceres. 
* [Amazon Web Services Account](http://aws.amazon.com/)
* [AWS CLI](https://aws.amazon.com/cli/)
* [Local Terraform Installation](https://www.terraform.io/downloads.html) 
* [Local Python 3 Installation](https://www.python.org/)
* [Slack Channel Web Hook](https://api.slack.com/messaging/webhooks)

### How to Use
1. Replace the sites in the sites-list.json file with the URLs that you want to monitor

2. Copy the ceres.tfvars.example file to ceres.tfvars
```bash
cp ceres.tfvars.example ceres.tfvars
```

3. Edit the variables in ceres.tfvars, including updating the Slack Channel Web Hook

4. Initialize Terraform Project
```bash
terraform init
```

5. Create Deployment Zip Files
```bash
./lambda-prep.sh
```

6. Deploy to AWS
```bash
terraform apply -var-file ceres.tfvars
```

7. Pick Region and Confirm Deployment

8. That's it! You're up and monitoring your sites!

### Description of Resources

##### Terraform Files
The ceres.tf file is the Terraform Template to deploy Ceres to AWS. 

##### Python Files
There are two folders, fill_queue and ping. The fill_queue folder contains the code and dependency list for the fill_queue Lambda Function. The ping folder contains the code and dependency list for the ping Lamabda Function.

##### Config Files
The .gitignore file contains common Terraform Artifacts. The sits-list.json file contains the list of sites to be monitored. 

##### Databases
Ceres utilizes two DynamoDB tables. The first keeps a running log of all site outages. The second is used to monitor the length of outages and post in Slack only when the outage initially occurs and when it ends (to reduce Slack spam).

##### S3 Bucket
The S3 Bucket that gets deployed stores the sites-list.json file. 

##### Lambda Functions
Ceres deploys two Lambda functions. The first (fill_queue) processes the sites-list.json file and creates a seperate SQS message for each. The second Lambda function (ping) is triggered based on these messages on a one-to-one basis and performs the actual anaylsis of the sites. It also sends notification messages to Slack and logs outages in the database. 

##### Included Scripts
The lambda-prep.sh script bundles up the Python dependencies and code for each Lambda function. 

The cleanup.sh script will remove the zip and build files in case you make changes to the Python Lambda code before redeploying. 
