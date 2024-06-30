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
#       -p|--profile    : The AWS profile to use
#       -t|--template   : The name of the CloudFormation template (without extension) located in ./cfn/templates/
#   Optional
#       -d|--dry-run    : (Optional) Perform a dry run without actual deployment
#       -h|--help       : (Optional) Show usage
#       -r|--region     : (Optional) The AWS region to deploy the stack in
#       -y|--assume-yes : (Optional) Automatically proceed without prompting for approval

# Ensure the required tools are installed and configured:
# - AWS CLI: https://aws.amazon.com/cli/

# Function to show script usage
show_usage() {
    echo "Usage:"
    echo "$0 -p|--profile AWS_PROFILE -t|--template TEMPLATE_NAME [-r|--region REGION] [-y|--assume-yes] [-d|--dry-run] [-h|--help]"
}

show_full_usage() {
    cat <<HEREDOC_FULL_USAGE
This script automates the deployment of AWS CloudFormation templates.
It performs the following steps:
1. Validate the CloudFormation template
2. Show the user what parameters are used
3. Gain approval from the user to proceed
4. Deploy the CloudFormation template

Usage:
./deploy-cfn.sh -p|--profile AWS_PROFILE -t|--template TEMPLATE_NAME [-r|--region REGION] [-y|--assume-yes] [-d|--dry-run]

Parameters:
    Required:
        -p|--profile    : The AWS profile to use
        -t|--template   : The name of the CloudFormation template (without extension) located in ./cfn/templates/
    Optional:
        -d|--dry-run    : Perform a dry run without actual deployment
        -h|--help       : Show usage
        -r|--region     : The AWS region to deploy the stack in (default: us-east-1)
        -y|--assume-yes : Automatically proceed without prompting for approval

Ensure the required tools are installed and configured:
- AWS CLI: https://aws.amazon.com/cli/

HEREDOC_FULL_USAGE
}

# Default values
ASSUME_YES=0
DRY_RUN=0
REGION="us-east-1"

while [[ "$#" -gt 0 ]]; do
    case $1 in
    # Required
    -p | --profile)
        AWS_PROFILE="$2"
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
    -h | --help)
        show_full_usage
        exit 0
        ;;
    -r | --region)
        REGION="$2"
        shift
        ;;
    -y | --assume-yes)
        ASSUME_YES=1
        ;;
    *)
        echo "Unknown parameter '$1'"
        show_usage
        exit 1
        ;;
    esac
    shift
done

# Check for mandatory arguments
if [[ -z "$AWS_PROFILE" ]]; then
    echo "Missing AWS Profile!"
    show_usage
    exit 1
elif [[ -z "$TEMPLATE_NAME" ]]; then
    echo "Missing CloudFormation Template file!"
    show_usage
    exit 1
fi

TEMPLATE_FILE="./cfn/templates/${TEMPLATE_NAME}.yml"
PARAMETER_FILE="./cfn/parameters/${TEMPLATE_NAME}.json"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Template file does not exist: $TEMPLATE_FILE"
    exit 1
fi

if [[ ! -f "$PARAMETER_FILE" ]]; then
    echo "Parameter file does not exist: $PARAMETER_FILE"
    exit 1
fi

check_for_required_packages() {
    if ! which aws &>/dev/null; then
        echo "Current environment missing 'awscli'"
        echo "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi
}

validate_aws_profile() {
    echo "Checking AWS profile..."
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
        echo "AWS profile '$AWS_PROFILE' failed, check profile"
        exit 1
    fi
    echo "AWS profile is valid."
}

validate_template() {
    echo "Validating CloudFormation template..."
    aws cloudformation validate-template --template-body file://"$TEMPLATE_FILE" --profile "$AWS_PROFILE" --region "$REGION"
    if [[ $? -ne 0 ]]; then
        echo "Template validation failed."
        exit 1
    fi
    echo "Template is valid."
}

show_parameters() {
    echo "The following template and parameters have been selected for deployment"
    PARAMS=$(
        aws cloudformation get-template-summary \
            --template-body file://"$TEMPLATE_FILE" \
            --profile "$AWS_PROFILE" \
            --region "$REGION"
    )
    echo "$PARAMS"
}

gain_approval() {
    if [[ $ASSUME_YES -eq 1 ]]; then
        return
    fi
    read -rp "Do you want to proceed with deployment? (y/Y): " APPROVAL
    if [[ "$APPROVAL" != [yY] ]]; then
        echo "Deployment aborted."
        exit 0
    fi
}

deploy_template() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "Dry run mode enabled. Skipping deployment."
        exit 0
    fi
    echo "Deploying CloudFormation template..."
    aws cloudformation deploy --template-file "$TEMPLATE_FILE" --stack-name "$TEMPLATE_NAME" --profile "$AWS_PROFILE" --region "$REGION" --parameter-overrides file://"$PARAMETER_FILE" --capabilities CAPABILITY_NAMED_IAM
    if [[ $? -ne 0 ]]; then
        echo "Deployment failed."
        exit 1
    fi
    echo "Deployment successful."
}

# Main script execution
check_for_required_packages
validate_aws_profile
validate_template
show_parameters
gain_approval
deploy_template
