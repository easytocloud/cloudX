# cloudX Architecture

The cloudX system is built on a multi-tier CloudFormation architecture designed for flexibility and isolation.

## 1. Environment Layer (`cloudX-environment.yaml`)

Deployed once per logical environment (e.g., "Dev", "Prod", "OTA"). Creates all shared resources:

- **IAM Instance Profile** — grants instances permission to use SSM and other necessary AWS services.
- **Security Group** — controls network egress for instances.
- **IAM Group with ABAC policies** — governs which IAM users can start/connect to their own instances.
- **SSM Parameter Store** — stores all environment config at `/cloudX/{EnvironmentName}/...` so instance and user stacks need no hardcoded values.
- **SSM Command Document** (`cloudX-{EnvironmentName}-setup`) — contains the full instance setup and configuration logic as a series of idempotent `aws:runShellScript` steps.
- **AutoUpdateAssociation** — an SSM State Manager association that targets all instances tagged `cloudX:update=auto` within the environment and re-runs the setup document on a `rate(7 days)` schedule.

## 2. Instance Layer (`cloudX-instance.yaml`)

Deployed per developer per environment. Creates:

- **EC2 Instance** — Amazon Linux 2023, reads environment config from Parameter Store via `{{resolve:ssm:...}}`.
- **SetupAssociation** — an SSM State Manager association targeting this specific instance by ID. Fires immediately on launch (`ApplyOnlyAtCronInterval: false`) to deliver the first-run configuration, then recurs only on a `rate(365 days)` far-future schedule (effectively never). Passes per-instance parameters (`NVM`, `NvmVersion`, `DOCKER`, `PRIVPAGE`, `FORTOOLS`, `ShutdownTimeout`) to the setup document.
- **Tags** — instance is tagged `cloudX:update=auto|manual` (controls whether the environment-level auto-update association picks it up) and `cloudX:version` (written by the setup document post-step with the document name and timestamp of the last successful run).

**UserData is minimal** — it only ensures the SSM Agent is running and creates a `.install-running` marker. All configuration is delivered by the SSM document, not UserData.

## 3. User Layer (`cloudX-user.yaml`) — Optional

Manages IAM credentials for developers who cannot use SSO.

- **Recommendation**: Prefer SSO roles with matching permissions over dedicated IAM users.
- IAM username format: `cloudX-{EnvironmentName}-{UserName}`.
- Access keys are generated and stored in Parameter Store.

## Pet Model: SSM State Manager

Instances are long-lived ("pets"), not disposable. Configuration changes are pushed to running instances by updating the environment stack (which creates a new document version) and triggering `aws ssm start-associations-once`. The 7-day auto-update association ensures all `auto`-tagged instances converge automatically without any manual trigger.

All setup document steps are idempotent — they are designed to be re-run safely on every State Manager execution.

## Client Connection

Connection is handled by the **cloudX-proxy** tool (separate repository: [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy)).
- Uses AWS SSM Session Manager for secure connections without open inbound ports.
- Handles SSH key management, configuration, and automatic instance wake-up.
- Supports both Unix-like systems and Windows.