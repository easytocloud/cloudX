# cloudX Project Overview

cloudX provides AWS CloudFormation templates for setting up Amazon Linux 2023 EC2 instances as remote development backends for VSCode. It serves as a successor to AWS Cloud9.

## Core Components

**CloudFormation Templates** in `templates/`:

- `cloudX-environment.yaml` — shared environment resources: IAM, security group, Parameter Store, SSM setup document, auto-update association. Deploy once per environment.
- `cloudX-instance.yaml` — EC2 instance + per-instance SSM State Manager association. Deploy per developer.
- `cloudX-user.yaml` — optional dedicated IAM user with access keys. Prefer SSO roles instead.

## Configuration Delivery

Instance setup is managed entirely by **SSM State Manager**, not UserData. The setup document lives inside `cloudX-environment.yaml` and is re-run automatically on a schedule. This means configuration changes can be pushed to running instances without recreating them — instances are treated as long-lived "pets".

## Software on Instances

Mandatory (always installed): Homebrew, direnv, uv, zsh + Oh My Zsh.
Optional via CloudFormation parameters: NVM (with configurable version), Docker, privpage, for-tools.
Intentionally absent: pip — `uv pip install` / `uv run` are the correct tools to avoid modifying OS Python.

## Archive

`install.sh` and everything under `archive/` are legacy reference material. The old proxy scripts (`cloudX-proxy.sh`, `cloudx-proxy.ps1`) have been superseded by the dedicated [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy) repository. Do not update archived files.

## Naming Convention

The project is named **cloudX**. Always lowercase 'cloud' with a capital 'X', even at the start of a sentence.