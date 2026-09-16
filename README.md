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
- `UserName`: ABAC tag value. Leave empty to assign the instance to yourself (the SSO user launching the stack) automatically; set explicitly only when provisioning on behalf of someone else
- `EnvironmentName`: Name of the cloudX environment (must match an existing environment stack)
- `InstanceType`: EC2 instance type (default: t3.2xlarge)
- `VolumeSize`: Root volume size in GB (default: 80)
- `ShutdownTimeout`: Minutes of inactivity before the instance shuts itself down (default: 30). Change it later without redeploying via `cloudX timeout set <minutes>` on the instance
- `UpdateMode`: `auto` (re-applies setup every 7 days) or `manual` (first launch only, default: `auto`)
- Software packages: `NVM`, `NvmVersion`, `DOCKER`, `PRIVPAGE`, `FORTOOLS`

Leaving `UserName` empty requires the instance to be provisioned via AWS Service Catalog — self-assignment resolves the launching SSO principal from Service Catalog's `aws:servicecatalog:provisioningPrincipalArn` auto-tag.

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

Instances tagged `cloudX:update=auto` also converge automatically every Sunday at 02:00 UTC without any manual trigger. After a successful run, each instance is tagged `cloudX:version=<document>@<timestamp>`; run `cloudX --version` on the instance to read it back.

## Identity Center (SSO) Permission Set

`VSCodeConnectPolicy` (created by `cloudX-environment.yaml`, see [templates/cloudX-environment.yaml](templates/cloudX-environment.yaml)) grants `cloudX-proxy` the permissions it needs, scoped per-user via an ABAC condition on the instance's `AbacTag` tag. As written, that condition matches `aws:username`, which is only populated for **IAM users** (`cloudX-user.yaml`). It is never populated for an **Identity Center (SSO)** principal — those authenticate as an assumed-role session (`arn:aws:sts::<account>:assumed-role/AWSReservedSSO_.../<session-name>`), so `aws:username` is empty and the condition simply never matches.

For SSO, the equivalent global condition key is **`sts:RoleSessionName`**. AWS Identity Center sets the session name to the SSO user's identifier (typically their username or email, depending on the identity source) — verify what your Identity Center actually issues with `aws sts get-caller-identity` while assumed, and make sure it's what you tag instances with (see `UserName` under [cloudX-instance.yaml](templates/cloudX-instance.yaml#L54), and the automatic self-assignment described in [CLAUDE.md](CLAUDE.md)).

### Where this lives

IAM Identity Center's Permission Sets and Account Assignments are managed centrally — in the Identity Center **management account** (or a delegated administrator account), not in the workload account(s) where `cloudX-environment.yaml`/`cloudX-instance.yaml` are deployed. This is a structurally different piece of infrastructure from the rest of cloudX:

- It's defined **once**, independent of any single environment (`OTA`, `Prod`, etc.) — not redeployed per environment.
- It's **assigned** to whichever account(s) and group(s)/user(s) should get cloudX access, via Account Assignments.
- There is currently no CloudFormation template for this in the repo (deliberately, for now) — create the Permission Set by hand or via your own IaC in the Identity Center account, using the exact permissions below. A dedicated template (with the ABAC tag key as a parameter, matching `AbacTag` from the environment stack) is a natural follow-up once the manual version is validated.

### Permission Set contents

Create a Permission Set (e.g. named `cloudX-Connect`) with an **inline policy** equivalent to `VSCodeConnectPolicy`, but with `aws:username` replaced by `sts:RoleSessionName`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GetStatusWithSSM1",
      "Effect": "Allow",
      "Action": "ssm:DescribeInstanceInformation",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/<AbacTag>": "${sts:RoleSessionName}"
        }
      }
    },
    {
      "Sid": "GetStatusWithSSM2",
      "Effect": "Allow",
      "Action": "ssm:DescribeInstanceInformation",
      "Resource": "arn:aws:ssm:*:*:*"
    },
    {
      "Sid": "StartEc2",
      "Effect": "Allow",
      "Action": "ec2:StartInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/<AbacTag>": "${sts:RoleSessionName}"
        }
      }
    },
    {
      "Sid": "StartSession1",
      "Effect": "Allow",
      "Action": "ssm:StartSession",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/<AbacTag>": "${sts:RoleSessionName}"
        }
      }
    },
    {
      "Sid": "StartSession2",
      "Effect": "Allow",
      "Action": "ssm:StartSession",
      "Resource": "arn:aws:ssm:*::document/AWS-StartSSHSession"
    },
    {
      "Sid": "AllowSendPubKey",
      "Effect": "Allow",
      "Action": ["ec2-instance-connect:SendSSHPublicKey"],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/<AbacTag>": "${sts:RoleSessionName}"
        }
      }
    }
  ]
}
```

Replace `<AbacTag>` (all four occurrences) with the literal tag key configured as the `AbacTag` parameter on the target environment's `cloudX-environment.yaml` stack (default `ez2:cloudx:user`) — Permission Set policies can't use `{{resolve:ssm:...}}` or CloudFormation `!Sub` the way the workload-account templates do, since this isn't a CloudFormation-deployed resource (yet). If you run multiple environments with **different** `AbacTag` values, you need either one Permission Set per distinct tag key, or a single Permission Set whose policy lists a condition per tag key used.

Resource ARNs above are left account/region-wildcarded (`*:*`) since a Permission Set is typically assigned across multiple accounts/regions; scope them down to specific accounts if you only ever assign this to one.

### What's intentionally left out

`AKSKRotationPolicy` (the other policy `cloudX-environment.yaml` attaches to the IAM Group) grants `iam:CreateAccessKey`/`DeleteAccessKey`/etc. scoped to `user/${aws:username}` — it exists to let IAM users rotate their own long-lived access keys. This has **no SSO equivalent**: an Identity Center session has no IAM user and no access keys to rotate, so nothing needs to replace it in the Permission Set.

### Account Assignment

Once the Permission Set exists, create an **Account Assignment** targeting each workload account that runs cloudX instances, and the Identity Center group(s) or user(s) that should get access. Users then see cloudX access as an available role when they sign in via the Identity Center portal or `aws sso login`, and `cloudX-proxy` picks up their session automatically — no separate AKSK setup needed.

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
