# Ceres - Realtime Website Uptime Monitoring and Reporting
Developed by the Campus Web Services Team at the University of Arizona

### Description 
Ceres performs realtime uptime monitoring for a specificed list of URLs using serverless technologies. 

### Pre-requisites 
* [Amazon Web Services Account](http://aws.amazon.com/)
* [AWS CLI](https://aws.amazon.com/cli/)
* [Local Terraform Installation](https://www.terraform.io/downloads.html) 
* [Local Python 3 Installation](https://www.python.org/)

### How to Use
1. Copy the ceres.tfvars.example file to ceres.tfvars
```bash
cp ceres.tfvars.example ceres.tfvars
```

2. Edit the variables in ceres.tfvars

3. Initialize Terraform Project
```bash
terraform init
```

4. Create Deployment Zip Files
```bash
./lambda-prep.sh
```

5. Deploy to AWS
```bash
terraform apply -var-file ceres.tfvars
```

6. Pick Region and Confirm Deployment

7. That's it! You're up and monitoring your sites!

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
Ceres deploys two Lambda functions. The first processes the sites-list.json file and creates a seperate SQS message for each. The second Lambda function is trigger based on these messages on a one-to-one basis and performs the actual anaylsis of the sites.
