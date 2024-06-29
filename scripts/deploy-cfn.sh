#!/bin/bash

# This script automates the deployment of AWS CloudFormation templates.
# It performs the following steps:
# 1. Validate the CloudFormation template
# 2. Show the user what parameters are used
# 3. Gain approval from the user to proceed
# 4. Deploy the CloudFormation template

# Usage:
# ./deploy-cfn.sh -p|--profile AWS_PROFILE -r|--region REGION -t|--template TEMPLATE_NAME [-y|--assume-yes] [-d|--dry-run]

# Parameters:
#   Required
#       -p|--profile   : The AWS profile to use
#       -r|--region    : The AWS region to deploy the stack in
#       -t|--template  : The name of the CloudFormation template (without extension) located in ./cfn/templates/
#   Optional
#       -y|--assume-yes: (Optional) Automatically proceed without prompting for approval
#       -d|--dry-run   : (Optional) Perform a dry run without actual deployment

# Function to show script usage
show_usage() {
    echo "Usage: $0 -p|--profile AWS_PROFILE -r|--region REGION -t|--template TEMPLATE_NAME [-y|--assume-yes] [-d|--dry-run]"
    exit 1
}

# Default values
ASSUME_YES=0
DRY_RUN=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
    # Required
    -p | --profile)
        AWS_PROFILE="$2"
        shift
        ;;
    -r | --region)
        REGION="$2"
        shift
        ;;
    -t | --template)
        TEMPLATE_NAME="$2"
        shift
        ;;
    # Optional
    -d | --dry-run)
        DRY_RUN=1
        ;;
    -y | --assume-yes)
        ASSUME_YES=1
        ;;
    *)
        show_usage
        ;;
    esac
    shift
done

# Check for mandatory arguments
if [[ -z "$AWS_PROFILE" || -z "$REGION" || -z "$TEMPLATE_NAME" ]]; then
    show_usage
fi

