#!/bin/bash

# The below functions capture the necessary overview of what this script does in functionsl help comments

show_help_docs() {
    cat <<HEREDOC_FULL_USAGE
This script automates the deployment of AWS CloudFormation templates by performing the following steps:
    1. Validate the CloudFormation template
    2. Show the user what parameters are used
    3. Gain approval from the user to proceed
    4. Deploy the CloudFormation template

Usage:
    $0 --template TEMPLATE [-p|--profile AWS_PROFILE] [-r|--region REGION]
        [-d|--dry-run] [-h|--help] [-y|--assume-yes]

Parameters:
    Required:
        -t, --template TEMPLATE     : The name of the CloudFormation template (without extension) located in ./cfn/templates/

    Optional:
        -d, --dry-run               : Perform a dry run without making any changes.
        -h, --help                  : Display this help message and exit.
        -p, --profile AWS_PROFILE   : Specify the AWS profile to use.
        -r, --region REGION         : The AWS region to deploy the stack in
        -y, --assume-yes            : Automatically proceed without prompting for approval

Ensure the required tools are installed and configured:
    - AWS CLI: https://aws.amazon.com/cli/
    - jq: https://stedolan.github.io/jq/

HEREDOC_FULL_USAGE
}

# ==============================================================================
#   Parse arguments
# ==============================================================================

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
    -t | --template)
        TEMPLATE_NAME="$2"
        shift
        ;;
    # Optional
    -d | --dry-run)
        DRY_RUN=1
        ;;
    -h | --help)
        show_help_docs
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
        echo "$0: invalid option -- '$1'"
        echo "Try '$0 --help' for more information."
        exit 1
        ;;
    esac
    shift
done

# ==============================================================================
#   Validate input
# ==============================================================================

if [[ -z "$TEMPLATE_NAME" ]]; then
    echo "Missing CloudFormation Template file!"
    show_usage
    exit 1
fi

STACK_NAME="$TEMPLATE_NAME"
TEMPLATE_FILE="./cfn/templates/${TEMPLATE_NAME}.yml"
PARAMETER_FILE="./cfn/parameters/${TEMPLATE_NAME}.json"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Template file does not exist: $TEMPLATE_FILE"
    exit 1
fi

# ==============================================================================
#   Variables
# ==============================================================================

ARGUMENT_REGION=()
ARGUMENT_PROFILE=()
ARGUMENT_PARAMETER_OVERRIDES=()

if [[ -n "$REGION" ]]; then
    ARGUMENT_REGION=("--region" "$REGION")
fi

if [[ -n "$AWS_PROFILE" ]]; then
    ARGUMENT_PROFILE=("--profile" "$AWS_PROFILE")
fi

if [[ -f "$PARAMETER_FILE" ]]; then
    ARGUMENT_PARAMETER_OVERRIDES=("--parameter-overrides" "file://$PARAMETER_FILE")
fi

# ==============================================================================
#   Functions
# ==============================================================================

check_for_required_packages() {
    if ! which aws &>/dev/null; then
        echo "Current environment missing 'awscli'"
        echo "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi

    if ! which jq &>/dev/null; then
        echo "Current environment missing 'jq'"
        echo "Install from: https://stedolan.github.io/jq/"
        exit 1
    fi
}

validate_aws_profile() {
    echo "Checking AWS profile..."

    cmd_get_caller_identity=(
        "aws" "sts" "get-caller-identity"
        "${ARGUMENT_PROFILE[@]}"
    )

    if ! "${cmd_get_caller_identity[@]}" &>/dev/null; then
        echo "Failured to authenticate to AWS."
        echo "CMD: ${cmd_get_caller_identity[*]}"
        echo ""

        if [[ -n "$AWS_PROFILE" ]]; then
            echo "AWS profile '$AWS_PROFILE' failed, check profile credentials."
        else
            echo "Check your default AWS credentials, or use the --profile flag to specify a profile."
        fi
        exit 1
    fi
    echo "AWS profile is valid."
}

validate_template() {
    echo "Validating CloudFormation template..."

    cmd_validate_template=(
        "aws" "cloudformation" "validate-template"
        "--template-body" "file://$TEMPLATE_FILE"
        "${ARGUMENT_PROFILE[@]}"
        "${ARGUMENT_REGION[@]}"
    )

    if ! "${cmd_validate_template[@]}" &>/dev/null; then
        echo "Template validation failed."
        exit 1
    fi

    echo "Template is valid."
}

show_planned_deployment() {
    echo "The following resources are prepared for deployment"

    cmd_get_template_summary=(
        "aws" "cloudformation" "get-template-summary"
        "--template-body" "file://$TEMPLATE_FILE"
        "--query" "ResourceIdentifierSummaries[*]"
        "--output" "json"
        "${ARGUMENT_PROFILE[@]}"
        "${ARGUMENT_REGION[@]}"
    )

    planned_deployment_resources=$(
        "${cmd_get_template_summary[@]}"
    )
    echo "$planned_deployment_resources"
}

gain_approval() {
    if [[ $ASSUME_YES -eq 1 ]]; then
        return
    fi
    read -rp "Do you want to proceed with deployment? (Y/N): " APPROVAL
    if [[ "$APPROVAL" != [yY] ]]; then
        echo "Deployment aborted."
        exit 0
    fi
}

deploy_template() {
    cmd_deploy_cfn=(
        "aws" "cloudformation" "deploy"
        "--template-file" "$TEMPLATE_FILE"
        "--stack-name" "$STACK_NAME"
        "${ARGUMENT_PROFILE[@]}"
        "${ARGUMENT_REGION[@]}"
        "${ARGUMENT_PARAMETER_OVERRIDES[@]}"
    )

    if [[ $DRY_RUN -eq 1 ]]; then
        echo "Dry run mode enabled. Skipping deployment."
        echo "Would have ran:"
        echo "${cmd_deploy_cfn[@]}"
        exit 0
    fi

    echo "Deploying CloudFormation template..."

    if ! "${cmd_deploy_cfn[@]}"; then
        echo "Deployment failed. Fetching stack events..."

        cmd_describe_failures_in_deployed_cfn=(
            "aws" "cloudformation" "describe-stack-events"
            "--stack-name" "$STACK_NAME"
            "--query" "StackEvents[?ResourceStatus==\`CREATE_FAILED\` || ResourceStatus==\`UPDATE_FAILED\` || ResourceStatus==\`ROLLBACK_IN_PROGRESS\`].[Timestamp, LogicalResourceId, ResourceStatusReason]"
            "${ARGUMENT_PROFILE[@]}"
            "${ARGUMENT_REGION[@]}"
        )

        "${cmd_describe_failures_in_deployed_cfn[@]}"

        exit 1
    fi
    echo "Deployment successful."
}

# ==============================================================================
# Main
# ==============================================================================

check_for_required_packages
validate_aws_profile
validate_template
show_planned_deployment
gain_approval
deploy_template
