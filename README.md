# terraform-state-resources-cfn

A simple AWS CloudFormation template and bash script used to deploy it to your AWS account.

## Introduction

This repository provides a framework for managing Terraform state using AWS CloudFormation. It includes the necessary CloudFormation templates, parameter files, and deployment scripts to set up an S3 bucket for storing Terraform state files and a DynamoDB table for state locking. This setup ensures a secure and efficient way to manage Terraform state in a cloud environment.

## Prerequisites

### Local System Requirements

- **AWS CLI**: Ensure the AWS Command Line Interface is installed and configured. [AWS CLI Installation Guide](https://aws.amazon.com/cli/)

### AWS Requirements

- **AWS Account**: An active AWS account
- **AWS CLI Profile**: Configured AWS CLI with some form of credentials to the AWS Account.

#### Required AWS Permissions to Deploy the CFN stack

Ensure the following AWS permissions are granted for the profile or IAM role being used:

- `cloudformation:CreateChangeSet`
- `cloudformation:ExecuteChangeSet`
- `dynamodb:CreateTable`
- `s3:CreateBucket`
- `s3:PutBucketEncryption`
- `s3:PutBucketPolicy`
- `s3:PutBucketVersioning`
- `s3:PutBucketPublicAccessBlock`

#### AWS Price estimate

A naive AWS estimate calculation is as follows:

[Example AWS price estimate](https://calculator.aws/#/estimate?id=e31394ddaf337e1896ceabe36fa234d3045db44e)

Which comes out to be an upper bound of `$0.83/month`, or `$9.96/year`.

> [!NOTE]
This estimate is however very flawed as it makes upper bounds assumptions on the amount of data stored, and how frequent its accessed. Most calculation variables assume a minimum of `1 GB` of data stored, written, or read. This is however going to be much larger than what a small Terraform state management system will use, making this a highly rounded up calculation.

## Usage

To deploy the CloudFormation template, follow these steps:

0. ***Assumed pre-requisites***

    It is assumed that your aws account and profile has been set up correctly. This can be checked using.

    ```sh
    aws sts get-caller-identity
    ```

    or if you are using an aws cli profile

    ```sh
    aws sts get-caller-identity --profile YOUR_PROFILE_NAME
    ```

    You can see what profiles you currently have using

    ```sh
    aws configure list-profiles
    ```

1. **Clone the repository**:

    ```sh
    git clone https://github.com/your-repo/terraform-state-resources-cfn.git
    cd terraform-state-resources-cfn
    ```

2. **Deploy the CloudFormation stack**:

    ```sh
    ./scripts/deploy-cfn.sh --template simple-terraform-state-resource --profile YOUR_AWS_PROFILE
    ```

### Script Parameters

#### Required

- `-t`, `--template TEMPLATE`: The name of the CloudFormation template (without extension) located in `./cfn/templates/`.

#### Optional

- `-d`, `--dry-run`: Perform a dry run without making any changes.
- `-h`, `--help`: Display the help message and exit.
- `-p`, `--profile AWS_PROFILE`: Specify the AWS profile to use.
- `-r`, `--region REGION`: The AWS region to deploy the stack in.
- `-y`, `--assume-yes`: Automatically proceed without prompting for approval.

### Example usages

#### Example 1 - Default AWS CLI Credentials

Deploy the stack with the specified template and use default AWS credentials:

```sh
./scripts/deploy-cfn.sh --template simple-terraform-state-resource
```

#### Example 2 - Use an AWS Profile

Deploy the stack with the specified template and use an AWS CLI Profile:

```sh
./scripts/deploy-cfn.sh -t simple-terraform-state-resource --profile my_profile
```

#### Example 3 - Select a specific region

Deploy the stack with the specified template and use an AWS CLI Profile and a specified region:

```sh
./scripts/deploy-cfn.sh -t simple-terraform-state-resource -p my_profile --region us-west-2
```

## Repository layout

```text
.
├── LICENSE
├── README.md
├── cfn
│   ├── parameters
│   │   └── simple-terraform-state-resource.json
│   └── templates
│       └── simple-terraform-state-resource.yml
└── scripts
└── deploy-cfn.sh
```

- **LICENSE**: Contains the license information for this repository.
- **README.md**: This file, providing an overview of the repository.
- **cfn/**: Directory containing CloudFormation-related files.
  - **parameters/**: Directory for CloudFormation parameter files.
    - **simple-terraform-state-resource.json**: Parameter file for the CloudFormation stack.
  - **templates/**: Directory for CloudFormation templates.
    - **simple-terraform-state-resource.yml**: CloudFormation template to create resources for Terraform state management.
- **scripts/**: Directory containing scripts for managing the CloudFormation stack.
  - **deploy-cfn.sh**: Script to deploy the CloudFormation stack.

## Parameter Override Files

The inclusion of a corresponding `.json` file in the `./cfn/parameters/` directory, named the same as a template, will be assumed to be a parameter override file to use when deploying.

>[!TIP]
> A lack of a corresponding `.json` just means no parameter override will be used. Make sure the template includes defaults for the parameters.

For example, if you have a template named `simple-terraform-state-resource.yml`, you should include a file named `simple-terraform-state-resource.json` in the parameters directory. This `.json` file will be used to override the default parameters specified in the CloudFormation template during deployment.
