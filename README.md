# TempusCodeChallenge

Requirements
-	AWS account
-	IAM User with full permissions to EC2 and VPC
-	Terraform installed and on the path
-	AWS credentials set in “C:\Users\USERNAME \.aws\credentials”
- Execute "terraform init" in the project directory before the first run to ensure the necessary plugins are installed

To run
-	In the project directory, enter ```terraform apply -var "instance_count=n"``` where n is the number of instances to create
