
# This is an AWS VM spinning option.
# Best practice, verify version of awscli
aws --version

# Best practice, verify user configuration
aws configure
# EC2

# List your running EC2 istances
aws ec2 describe-instances

# Stops an instance
aws ec2 stop-instances --instance-ids i-004f15f18e76bb7eb

# Starts a stopped instance
aws ec2 start-instances --instance-ids i-004f15f18e76bb7eb

# Reboots an instance
aws ec2 reboot-instances --instance-ids i-004f15f18e76bb7eb 

# List image information
aws ec2 describe-images --image-ids ami-340aae4e

#Creates an image from an instance
aws ec2 create-image --instance-id i-004f15f18e76bb7eb --name "WebServer AMI" --description "WebServer for dev team"