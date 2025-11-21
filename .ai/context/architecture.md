# cloudX Architecture

The cloudX system is built on a multi-tier CloudFormation architecture designed for flexibility and isolation.

## 1. Environment Layer (`cloudX-environment.yaml`)
This is the foundational layer. It is deployed once per logical environment (e.g., "Dev", "Prod", "OTA").
- **Resources**:
    - IAM Instance Profile: Grants instances permission to use SSM and other necessary services.
    - Security Group: Controls network access to the instances.
    - IAM Group: Manages user permissions via ABAC (Attribute-Based Access Control).
    - SSM Parameters: Stores configuration details (Subnet ID, Security Group ID, etc.) at `/cloudX/{EnvironmentName}/...`.

## 2. Instance Layer (`cloudX-instance.yaml`)
This layer deploys the actual development workstations. It is deployed for each developer.
- **Resources**:
    - EC2 Instance: Amazon Linux 2023.
    - UserData: Configures the environment using embedded scripts and CloudFormation Init metadata.
- **Configuration**:
    - Reads parameters from the Environment Layer via SSM.
    - Uses CloudFormation parameters to control software installation (e.g., `NVM`, `DOCKER`, `PIP`).

## 3. User Layer (`cloudX-user.yaml`) - Optional
This layer manages IAM credentials for developers who don't have existing access.
- **Recommendation**: Use SSO Roles with appropriate permissions instead of dedicated IAM users whenever possible.
- **Resources**:
    - IAM User: Created with a specific naming convention `cloudX-{EnvironmentName}-{UserName}`.
    - Access Keys: Generated and stored in Parameter Store.

## Client Connection
Connection to the instances is handled by the **cloudX-proxy** tool (external repository).
- It uses AWS SSM Session Manager to establish a secure connection.
- It handles SSH key management and configuration.
- It supports both Unix-like systems and Windows.