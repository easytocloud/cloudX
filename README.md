# cloudX

AWS CloudFormation templates for setting up Amazon Linux 2023 EC2 instances as remote development backends for VSCode.

## Introduction

cloudX is a worthy successor to AWS Cloud9, providing a modern remote development environment using VSCode with Amazon Linux 2023. With Cloud9 no longer available for new customers, cloudX offers a flexible alternative for cloud-based development.

**This repository contains the AWS-side CloudFormation templates.** For client-side setup (SSH configuration and proxy management), see the [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy) repository.

## Quick Deploy

Deploy the CloudFormation templates directly to your AWS account:

### 1. Environment Setup (Required - Once Per Environment)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-environment&templateURL=https://cloudx-public.s3.amazonaws.com/templates/cloudX-environment.yaml)

Creates IAM resources, security groups, SSM setup document, and stores environment configuration in Parameter Store.

### 2. Instance Deployment (Required - Per Developer Per Environment)
[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudX-instance&templateURL=https://cloudx-public.s3.amazonaws.com/templates/cloudX-instance.yaml)

Deploys an EC2 instance and wires it up to the environment's SSM setup document.

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
- Parameter Store entries at `/cloudX/{EnvironmentName}/...`
- SSM Command Document (`cloudX-{EnvironmentName}-setup`) containing all instance setup logic
- Auto-update association that re-applies the setup document every 7 days to all instances tagged `cloudX:update=auto`

Parameters:
- `EnvironmentName`: Unique name for this environment (e.g., "OTA", "Prod") — used to namespace all resources
- `Subnet`: The VPC subnet ID where instances will be deployed
- `SSODomain`: Your AWS SSO domain (e.g., "mycompany.awsapps.com") for SSO tools configuration
- `AbacTag`: The tag key used for attribute-based access control (default: `ez2:cloudx:user`)

### cloudX-instance.yaml

**Deploy this template for each developer instance within an environment.**

Creates an EC2 instance configured as a development backend:
- Amazon Linux 2023 (latest AMI, automatically selected)
- Configurable instance type (default: t3.2xlarge) and volume size
- Configuration delivered via SSM State Manager — not UserData
- Tagged with environment and username for ABAC permissions
- Tagged with `cloudX:update` and `cloudX:version` for update lifecycle management

Parameters:
- `UserName`: Username without prefix (e.g., "john")
- `EnvironmentName`: Name of the cloudX environment (must match an existing environment stack)
- `InstanceType`: EC2 instance type (default: t3.2xlarge)
- `VolumeSize`: Root volume size in GB (default: 80)
- `UpdateMode`: `auto` (re-applies setup every 7 days) or `manual` (first launch only, default: `auto`)
- Software packages: `NVM`, `NvmVersion`, `DOCKER`, `PRIVPAGE`, `FORTOOLS`

### cloudX-user.yaml

**Optional: Deploy for each developer per environment if dedicated IAM credentials are needed.**

**Recommendation:** We strongly prefer users to be identified via an SSO Role with appropriate permissions. This template is provided for scenarios where IAM users are strictly required.

This template creates a dedicated IAM user with environment-scoped access:
- IAM username format: `cloudX-{EnvironmentName}-{UserName}` (e.g., "cloudX-OTA-john")
- Automatic membership in the environment's IAM group
- Access key pair automatically generated and stored in Parameter Store at `/cloudX/{EnvironmentName}/{UserName}/CloudXUserAccessKey*`

Parameters:
- `UserName`: Username without prefix (e.g., "john")
- `EnvironmentName`: Name of the cloudX environment (must match an existing environment)
- `EmailAddress`: Email address for credential notification (optional)

## Pet Model: Updating Running Instances

cloudX instances are long-lived — you do not need to recreate an instance to apply configuration changes. All setup logic lives in the SSM document inside the environment stack. To push an update to running instances:

```bash
# 1. Update the environment stack (publishes a new document version)
aws cloudformation update-stack --stack-name cloudX-OTA-environment \
  --template-body file://templates/cloudX-environment.yaml \
  --capabilities CAPABILITY_IAM

# 2. Trigger immediate re-convergence on all instances in the environment
aws ssm start-associations-once \
  --association-ids $(aws ssm list-associations \
    --association-filter-list key=DocumentName,value=cloudX-OTA-setup \
    --query 'Associations[].AssociationId' --output text)
```

Instances tagged `cloudX:update=auto` also converge automatically every Sunday at 02:00 UTC without any manual trigger. After a successful run, each instance is tagged `cloudX:version=<document>@<timestamp>` and the value is written to `~/.cloudX/version` on the instance.

## Client-Side Setup

For setting up your local machine to connect to cloudX instances, please refer to the **[cloudX-proxy](https://github.com/easytocloud/cloudX-proxy)** repository. It handles:

- SSH configuration and proxy management
- Automatic instance startup via SSM
- SSH key management and deployment
- VSCode Remote Development integration
- Support for both Unix-like systems and Windows

## Software on Instances

Software is installed and kept up to date by the SSM setup document. Selection is controlled via CloudFormation parameters on the instance stack.

### Available Software Packages

| Package | Description | Default |
|---------|-------------|---------|
| Homebrew | Package manager (basis for all other installs) | Mandatory |
| direnv | Automatic environment variable management | Mandatory |
| uv | Extremely fast Python package and project manager | Mandatory |
| zsh + Oh My Zsh | Shell with easytocloud theme | Mandatory |
| `PRIVPAGE` | AWS CLI output privacy tool | `true` |
| `FORTOOLS` | Multi-account AWS iteration tools | `true` |
| `NVM` | Node Version Manager | `false` |
| `NvmVersion` | NVM version to install (e.g. `0.40.3`) | `0.40.3` |
| `DOCKER` | Docker container runtime | `false` |

**Note:** pip is intentionally not provided. Use `uv pip install` or `uv run` to manage Python dependencies without modifying the OS Python installation.

## Customization

Organizations can maintain their own template variants by inserting values at `CUSTOMIZATION_MARKER` comments in the templates. A Python script + Makefile pattern lets you fetch the upstream templates and apply a YAML customization file on top. See [`templates/CUSTOMIZATION.md`](templates/CUSTOMIZATION.md) for the full pattern.

## Repository Contents

```
.
├── templates/
│   ├── cloudX-environment.yaml    # Environment setup (deploy once)
│   ├── cloudX-instance.yaml       # Instance template (per developer)
│   ├── cloudX-user.yaml           # Optional IAM user creation
│   └── CUSTOMIZATION.md           # Pattern for org-specific variants
└── archive/                       # Legacy scripts (reference only, not maintained)
```

## Contributing

Issues and pull requests are welcome. For client-side proxy functionality, please contribute to the [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy) repository instead.
