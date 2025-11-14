# cloudX

AWS CloudFormation templates for setting up Amazon Linux 2023 EC2 instances as remote development backends for VSCode.

## Introduction

cloudX is a worthy successor to AWS Cloud9, providing a modern remote development environment using VSCode with Amazon Linux 2023. With Cloud9 no longer available for new customers, cloudX offers a flexible alternative for cloud-based development.

**This repository contains the AWS-side CloudFormation templates.** For client-side setup (SSH configuration and proxy management), see the [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy) repository.

## Quick Deploy

Deploy the CloudFormation templates directly to your AWS account:

### 1. Environment Setup (Required - Deploy Once)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-environment&templateURL=https://s3.amazonaws.com/cloudx-public/templates/cloudX-environment.yaml)

Creates IAM resources and stores configuration in Parameter Store.

### 2. Instance Deployment (Required - Per Developer)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-instance&templateURL=https://s3.amazonaws.com/cloudx-public/templates/cloudX-instance.yaml)

Deploys an EC2 instance with development tools configured via UserData.

### 3. User Setup (Optional - Per Developer)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-user&templateURL=https://s3.amazonaws.com/cloudx-public/templates/cloudX-user.yaml)

Creates a dedicated IAM user with access keys for instance management.

## CloudFormation Templates

### cloudX-environment.yaml

**Deploy this template first (once per AWS account/region).**

Creates the core infrastructure:
- IAM instance profile with SSM access
- Parameter Store configuration for subnet, ABAC tag, and group settings
- IAM group for cloudX users with permissions to start, stop, and connect to instances

Parameters:
- `Subnet`: The VPC subnet ID where instances will be deployed
- `AbacTag`: The tag key used for attribute-based access control (default: `ez2:security:vscodeuser`)
- `GroupName`: Name for the IAM group (default: `cloudX`)

### cloudX-instance.yaml

**Deploy this template for each developer instance.**

Creates an EC2 instance configured as a development backend:
- Amazon Linux 2023 (latest AMI)
- Instance type: t3.large
- Automatic software installation via UserData (runs `install.sh`)
- Tagged with username for ABAC permissions
- SSM-enabled for secure connections

Parameters:
- `UserName`: Username for instance tagging and identification (default: `cloudXuser`)

The instance installs development tools automatically on first boot. Software selection can be controlled via EC2 instance tags (see `install.sh` for available options).

### cloudX-user.yaml

**Optional: Deploy for each developer if dedicated IAM credentials are needed.**

Creates a dedicated IAM user:
- Member of the cloudX group (with instance management permissions)
- Access key automatically generated and stored in Parameter Store
- Credentials available at: `/hc/cloudX/{UserName}/CloudXUserAccessKey*`

Parameters:
- `UserName`: The IAM username to create (default: `cloudXuser`)

**Note:** You can skip this template if developers already have appropriate IAM/SSO permissions.

## Client-Side Setup

For setting up your local machine to connect to cloudX instances, please refer to the **[cloudX-proxy](https://github.com/easytocloud/cloudX-proxy)** repository. It handles:

- SSH configuration and proxy management
- Automatic instance startup via SSM
- SSH key management and deployment
- VSCode Remote Development integration
- Support for both Unix-like systems and Windows

## Software Installation on Instances

The `install.sh` script (run automatically via UserData) supports various development tools. You can control which software gets installed by setting EC2 instance tags:

| Tag | Software | Notes |
|-----|----------|-------|
| `brew` | Homebrew | Package manager (implied by other brew-based tools) |
| `direnv` | direnv | Environment variable manager |
| `sso` | SSO Tools | AWS SSO integration tools |
| `zsh` | Zsh + Oh My Zsh | Alternative shell with easytocloud theme |
| `pip` | pip + Python tools | Python package manager |
| `docker` | Docker | Container runtime |
| `anaconda` | Anaconda | Python data science distribution |
| `nvm` | Node Version Manager | Node.js version manager |
| `privpage` | privpage | AWS CLI output privacy tool |
| `fortools` | for-tools | Iteration tools for AWS operations |
| `SSODomain` | (value) | Your AWS SSO domain for configuration |

Set tag values to `true` to enable installation. Example: Tag key `zsh` with value `true` will install Zsh and Oh My Zsh.

For more flexible installation on existing instances, see the `ec2cloudx.sh` script which supports command-line options.

## Repository Contents

```
.
├── templates/
│   ├── cloudX-environment.yaml    # Environment setup (deploy once)
│   ├── cloudX-instance.yaml       # Instance template (per developer)
│   └── cloudX-user.yaml           # Optional IAM user creation
├── install.sh                     # UserData installation script
├── ec2cloudx.sh                   # Enhanced installation script with CLI options
└── distribution/bin/              # Legacy proxy scripts (see note below)
```

## Contributing

Issues and pull requests are welcome. For client-side proxy functionality, please contribute to the [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy) repository instead.

---

### Legacy Note

The `distribution/bin/cloudX-proxy.sh` and `Windows/cloudx-proxy.ps1` scripts in this repository are maintained for compatibility but have been superseded by the dedicated **[cloudX-proxy](https://github.com/easytocloud/cloudX-proxy)** tool, which provides improved SSH proxy management and configuration.