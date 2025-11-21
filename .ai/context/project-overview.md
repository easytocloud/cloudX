# cloudX Project Overview

cloudX provides AWS CloudFormation templates for setting up Amazon Linux 2023 EC2 instances as remote development backends for VSCode. It serves as a successor to AWS Cloud9.

## Core Components

1.  **CloudFormation Templates**: Located in `templates/`, these define the infrastructure.
    *   `cloudX-environment.yaml`: Sets up the shared environment resources (VPC subnet, IAM groups, Parameter Store).
    *   `cloudX-instance.yaml`: Deploys the actual development instance.
    *   `cloudX-user.yaml`: Optional template for creating dedicated IAM users.

2.  **Installation Scripts**:
    *   `install.sh`: Run via UserData on instance creation.
    *   `ec2cloudx.sh`: Enhanced installation script with CLI options for existing instances.

3.  **Legacy Proxies**:
    *   Historically, this repository contained proxy scripts for connecting to the instances (`cloudX-proxy.sh` and `cloudx-proxy.ps1`).
    *   These have been moved to a dedicated repository: `cloudX-proxy`.

## Naming Convention

The project is named **cloudX**. Always lowercase 'cloud' with a capital 'X', even at the start of a sentence.