#!/usr/bin/env bash

# Install required packages
export DEBIAN_FRONTEND="noninteractive"
apt-get update
apt install python3.9 python3-pip -y

# If defined in the previous "Shell Script" step as Output Variable then call it here with `<+execution.steps.STEP_NAME.output.outputVariables.VARIABLE_NAME>`
# (OR) Directly paste the values
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=

# Install awscli python module
pip3 install awscli

# Replace ami-id, key-pair-name, sg-id, and subnet-id values accordingly
aws ec2 run-instances \
  --image-id ami-id \
  --count 1 \
  --instance-type t2.medium \
  --key-name key-pair-name \
  --security-group-ids sg-id \
  --subnet-id subnet-id \
  --region ap-southeast-1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Harness-Automated}]'

