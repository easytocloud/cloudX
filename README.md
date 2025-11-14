# cloudX

AWS CloudFormation templates for setting up Amazon Linux 2023 EC2 instances as remote development backends for VSCode.

## Introduction

cloudX is a worthy successor to AWS Cloud9, providing a modern remote development environment using VSCode with Amazon Linux 2023. With Cloud9 no longer available for new customers, cloudX offers a flexible alternative for cloud-based development.

**This repository contains the AWS-side CloudFormation templates.** For client-side setup (SSH configuration and proxy management), see the [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy) repository.

## Quick Deploy

Deploy the CloudFormation templates directly to your AWS account:

### 1. Environment Setup (Required - Once Per Environment)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-environment&templateURL=https://cloudx-public.s3.amazonaws.com/templates/cloudX-environment.yaml)

Creates IAM resources, security groups, and stores environment configuration in Parameter Store.

### 2. Instance Deployment (Required - Per Developer Per Environment)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-instance&templateURL=https://cloudx-public.s3.amazonaws.com/templates/cloudX-instance.yaml)

Deploys an EC2 instance with development tools configured via UserData.

### 3. User Setup (Optional - Per Developer Per Environment)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-user&templateURL=https://cloudx-public.s3.amazonaws.com/templates/cloudX-user.yaml)

Creates a dedicated IAM user with access keys for instance management.

## CloudFormation Templates

### Multiple Environments Support

cloudX supports multiple isolated environments within a single AWS account. Each environment has its own:
- VPC subnet for instance placement
- IAM group for user permissions
- Security group configuration
- SSO domain settings

This allows you to separate development, testing, and production environments, or create isolated workspaces for different teams or projects.

### cloudX-environment.yaml

**Deploy this template once per environment (e.g., "OTA", "Prod", "Dev").**

Creates the core infrastructure for a cloudX environment:
- IAM instance profile with SSM access and necessary AWS service permissions
- Security group for instance networking
- IAM group with ABAC policies for user access control
- Parameter Store configuration storing all environment settings

Parameters:
- `EnvironmentName`: Unique name for this environment (e.g., "OTA", "Prod") - used to isolate resources
- `Subnet`: The VPC subnet ID where instances will be deployed
- `SSODomain`: Your AWS SSO domain (e.g., "mycompany.awsapps.com") for SSO tools configuration
- `AbacTag`: The tag key used for attribute-based access control (default: `ez2:cloudx:user`)

All configuration is stored in SSM Parameter Store at `/cloudX/{EnvironmentName}/...` for use by instance and user templates.

### cloudX-instance.yaml

**Deploy this template for each developer instance within an environment.**

Creates an EC2 instance configured as a development backend:
- Amazon Linux 2023 (latest AMI, automatically updated)
- Configurable instance type (default: t3.large) and volume size
- Automatic software installation via UserData (runs `install.sh`)
- Tagged with environment and username for ABAC permissions
- SSM-enabled for secure connections without SSH keys in AWS

Parameters:
- `UserName`: Username without prefix (e.g., "john") - will be combined with environment for ABAC
- `EnvironmentName`: Name of the cloudX environment (must match an existing environment)
- `InstanceType`: EC2 instance type (default: t3.large)
- `VolumeSize`: Root volume size in GB (default: 16)
- Software packages: `BREW`, `DIRENV`, `SSO`, `ZSH`, `UV`, `NVM`, `PIP`, `DOCKER`, `ANACONDA`, `PRIVPAGE`, `FORTOOLS`

The instance automatically retrieves configuration from the environment's SSM parameters. Software selection can be controlled via template parameters or EC2 instance tags.

### cloudX-user.yaml

**Optional: Deploy for each developer per environment if dedicated IAM credentials are needed.**

Creates a dedicated IAM user with environment-scoped access:
- IAM username format: `cloudX-{EnvironmentName}-{UserName}` (e.g., "cloudX-OTA-john")
- Automatic membership in the environment's IAM group
- Access key pair automatically generated
- Credentials stored securely in Parameter Store at `/cloudX/{EnvironmentName}/{UserName}/CloudXUserAccessKey*`
- Email notification support for credential distribution

Parameters:
- `UserName`: Username without prefix (e.g., "john")
- `EnvironmentName`: Name of the cloudX environment (must match an existing environment)
- `EmailAddress`: Email address for credential notification (optional)

**Note:** You can skip this template if developers already have appropriate IAM/SSO permissions. The ABAC policies in the environment's IAM group will match the full username format `cloudX-{EnvironmentName}-{UserName}` to control instance access.

## Client-Side Setup

For setting up your local machine to connect to cloudX instances, please refer to the **[cloudX-proxy](https://github.com/easytocloud/cloudX-proxy)** repository. It handles:

- SSH configuration and proxy management
- Automatic instance startup via SSM
- SSH key management and deployment
- VSCode Remote Development integration
- Support for both Unix-like systems and Windows

## Software Installation on Instances

The `install.sh` script runs automatically via UserData on instance creation. Software selection can be controlled via:

1. **CloudFormation parameters** (recommended) - Select software during stack deployment
2. **EC2 instance tags** - Set tags manually after deployment or via automation

### Available Software Packages

| Package | Description | Default |
|---------|-------------|---------|
| `UV` | UV package manager - extremely fast pip/venv alternative | ✓ Recommended |
| `BREW` | Homebrew package manager | ✓ Recommended |
| `DIRENV` | Automatic environment variable management | ✓ Recommended |
| `SSO` | AWS SSO tools for multi-account access | ✓ Recommended |
| `ZSH` | Zsh + Oh My Zsh with easytocloud theme | ✓ Recommended |
| `PRIVPAGE` | AWS CLI output privacy tool | ✓ Recommended |
| `FORTOOLS` | Multi-account AWS iteration tools | ✓ Recommended |
| `NVM` | Node Version Manager | Optional |
| `PIP` | Python pip package manager | Optional |
| `DOCKER` | Docker container runtime | Optional |
| `ANACONDA` | Anaconda data science distribution | Optional |

**Installation Methods:**

- **Via CloudFormation**: Set parameter values to `true` or `false` during stack deployment
- **Via EC2 Tags**: Add tags with key matching the package name (lowercase) and value `true`
- **Via `ec2cloudx.sh`**: For existing instances, use command-line options (e.g., `--brew --zsh --docker`)

The `SSODomain` is automatically retrieved from the environment configuration but can be overridden via instance tags if needed.

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