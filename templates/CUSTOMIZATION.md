# CloudX Template Customization Pattern

This document describes how to create customized versions of the cloudX templates while maintaining synchronization with upstream changes.

## Overview

The cloudX templates include **customization markers** that allow teams to maintain their own customized versions while automatically inheriting improvements and updates from the opensource template.

This pattern enables organizations to add their own configurations while staying synchronized with the upstream opensource template.

## Customization Markers

### Where each marker lives

| Marker | Template | Purpose |
|--------|----------|---------|
| `CUSTOMIZATION_MARKER:EnvironmentName` | `cloudX-instance.yaml` | Restrict allowed environment names |
| `CUSTOMIZATION_MARKER:InstanceType` | `cloudX-instance.yaml` | Restrict or extend allowed instance types |
| `CUSTOMIZATION_MARKER:configSets` | `cloudX-environment.yaml` | Add custom SSM document steps |
| `CUSTOMIZATION_MARKER:configSetDefinitions` | `cloudX-environment.yaml` | Implement custom SSM document steps |

> **Note:** As of the SSM State Manager migration, installation logic lives in `cloudX-environment.yaml` (the `CloudXSetupDocument` resource). Step-based customizations target that template, not the instance template.

---

### 1. EnvironmentName Parameter (`cloudX-instance.yaml`)

```yaml
  EnvironmentName:
    Type: String
    Default: 'OTA'
    Description: 'Name of the CloudX environment'
    # CUSTOMIZATION_MARKER:EnvironmentName - Add AllowedValues or other constraints here
```

**Purpose**: Add parameter constraints like `AllowedValues` to restrict environment names.

**Example Customization**:
```yaml
    AllowedValues:
      - 'OTA'
      - 'Prod'
      - 'custom'
```

---

### 2. InstanceType Allowed Values (`cloudX-instance.yaml`)

```yaml
    AllowedValues:
      # CUSTOMIZATION_MARKER:InstanceType - Add or remove AllowedValues here. Ensure new types are added to InstanceArchMap.
      - 't3.xlarge'
      ...
```

**Purpose**: Add or remove allowed instance types. When adding a new type, also add it to the `InstanceArchMap` mapping.

---

### 3. Custom SSM Document Steps (`cloudX-environment.yaml`)

Installation and configuration logic runs as SSM State Manager document steps inside `CloudXSetupDocument`. To add organization-specific setup steps, append to the `mainSteps` list after the built-in `post` step:

```yaml
        mainSteps:
          ...
          - name: post
            ...
          # CUSTOMIZATION_MARKER:configSets - Add custom mainSteps here (after the 'post' step)
          # CUSTOMIZATION_MARKER:configSetDefinitions - Each SSM mainStep contains both name and runCommand inline.
```

**Example — adding a custom step**:
```yaml
          - name: my_custom_step
            action: aws:runShellScript
            inputs:
              runCommand:
                - su - ec2-user -c 'add-to-rc mytool "export MYTOOL_HOME=/opt/mytool"'
                - su - ec2-user -c 'add-to-rc --bash mytool "eval \"$(mytool init bash)\""'
```

**Key difference from the old cfn-init pattern**: each step is a `aws:runShellScript` block with inline `runCommand` commands. There are no separate `files:`, `packages:`, `commands:`, or `services:` keys. Write files using heredocs, install packages with `yum`, and enable services with `systemctl`.

**Shell rc integration via `add-to-rc`**:
- `add-to-rc` is installed early in the document and available to all subsequent steps
- Blocks are idempotent (upsert) — safe to re-run on every State Manager execution
- Target files: `~/.cloudxrc` (all shells), `~/.cloudx.bash` (bash only), `~/.cloudx.zsh` (zsh only)

---

### IMDSv2 requirement

The base template sets `HttpTokens: required` on the instance, which disables IMDSv1. Any custom SSM step that queries instance metadata **must** use the IMDSv2 token pattern:

```bash
TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
VALUE=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/<path>")
```

Plain `curl http://169.254.169.254/...` calls without a token will fail with a `401` once `HttpTokens: required` is in effect.

Instance tags are also accessible from metadata (`InstanceMetadataTags: enabled`), so custom steps can read tags via IMDS rather than calling `aws ec2 describe-tags`.

---

## Implementation Pattern

### Step 1: Create Customization File

Create a YAML file defining your customizations:

```yaml
# my-customizations.yaml

# EnvironmentName customization
EnvironmentName:
  AllowedValues:
    - 'dev'
    - 'staging'
    - 'prod'

# Custom SSM document steps (appended after 'post' step in cloudX-environment.yaml)
customSteps: |
  - name: myorg_setup
    action: aws:runShellScript
    inputs:
      runCommand:
        - su - ec2-user -c 'add-to-rc myorg "export MYORG_ENV=production"'
```

---

### Step 2: Create Python Script

Create a Python script to apply customizations:

```python
#!/usr/bin/env python3
import sys

def apply_customizations(template_content, customizations):
    # Apply EnvironmentName customizations (instance template)
    if 'EnvironmentName' in customizations:
        allowed_values = customizations['EnvironmentName']['AllowedValues']
        values_yaml = '\n'.join(f"      - '{v}'" for v in allowed_values)
        marker = "    # CUSTOMIZATION_MARKER:EnvironmentName"
        replacement = f"    AllowedValues:\n{values_yaml}"
        template_content = template_content.replace(marker, replacement)

    # Apply custom SSM steps (environment template)
    if 'customSteps' in customizations:
        steps = customizations['customSteps']
        # Indent to match the mainSteps list level (10 spaces)
        indented = '\n'.join('          ' + line for line in steps.split('\n'))
        marker = "          # CUSTOMIZATION_MARKER:configSets - Add custom mainSteps here (after the 'post' step)"
        template_content = template_content.replace(marker, indented)

    return template_content
```

---

### Step 3: Create Makefile

Create a Makefile to automate the process:

```makefile
OPENSOURCE_INSTANCE_URL = https://raw.githubusercontent.com/easytocloud/cloudX/refs/heads/main/templates/cloudX-instance.yaml
OPENSOURCE_ENV_URL      = https://raw.githubusercontent.com/easytocloud/cloudX/refs/heads/main/templates/cloudX-environment.yaml
CUSTOMIZATIONS_FILE = my-customizations.yaml
OUTPUT_INSTANCE = cloudX-instance-custom.yaml
OUTPUT_ENV      = cloudX-environment-custom.yaml

all: $(OUTPUT_INSTANCE) $(OUTPUT_ENV)

$(OUTPUT_INSTANCE): $(CUSTOMIZATIONS_FILE)
	curl -fsSL $(OPENSOURCE_INSTANCE_URL) -o instance.tmp
	python3 apply-customizations.py instance.tmp $(CUSTOMIZATIONS_FILE) $(OUTPUT_INSTANCE) --target instance
	rm instance.tmp

$(OUTPUT_ENV): $(CUSTOMIZATIONS_FILE)
	curl -fsSL $(OPENSOURCE_ENV_URL) -o env.tmp
	python3 apply-customizations.py env.tmp $(CUSTOMIZATIONS_FILE) $(OUTPUT_ENV) --target environment
	rm env.tmp

clean:
	rm -f $(OUTPUT_INSTANCE) $(OUTPUT_ENV)
```

---

### Step 4: Generate Custom Templates

```bash
make all
```

This fetches the latest opensource templates and applies your customizations.

---

## Benefits

1. **Automatic Updates**: Inherit all improvements from the opensource templates — including new SSM document steps
2. **Push updates to running instances**: Because setup runs via SSM State Manager, re-deploying the environment template pushes updates to running instances without recreating them
3. **Clear Separation**: Your customizations are isolated and documented
4. **Version Control**: Track customizations separately from base templates
5. **Testability**: Easy to test with different versions
6. **Repeatability**: Automated generation ensures consistency

---

## Best Practices

### Minimize Customizations

Keep customizations minimal. Consider contributing improvements back to the opensource template instead of customizing.

### Document Intent

Clearly document why each customization exists:

```yaml
# JUSTIFICATION: Security policy requires environment name validation
EnvironmentName:
  AllowedValues:
    - 'dev'
    - 'staging'
    - 'prod'
```

### Regular Updates

Regularly sync with the upstream templates to get security updates and improvements:

```bash
# Weekly or monthly
make clean && make all
```

### Test Thoroughly

Always test generated templates in a development environment before production deployment.

### Version Control Everything

Commit three things:
1. Your customization file (`my-customizations.yaml`)
2. The generation script (`apply-customizations.py`)
3. The generated templates (`cloudX-instance-custom.yaml`, `cloudX-environment-custom.yaml`)

---

## Triggering Updates on Running Instances

Because setup is managed by SSM State Manager, you can push your customizations to already-running instances without recreating them:

```bash
# Re-deploy the environment template (creates a new document version)
aws cloudformation update-stack --stack-name cloudX-OTA-environment \
  --template-body file://cloudX-environment-custom.yaml \
  --capabilities CAPABILITY_IAM

# Trigger immediate re-convergence on all instances in the environment
aws ssm start-associations-once \
  --association-ids $(aws ssm list-associations \
    --association-filter-list key=DocumentName,value=cloudX-OTA-setup \
    --query 'Associations[].AssociationId' \
    --output text)
```

Or wait for the weekly scheduled run — all instances automatically converge within 7 days.

---

## Support

For questions about the customization pattern:
- Open an issue in the cloudX GitHub repository
- Contact the maintainers

## Contributing

If your customization would benefit others, consider contributing it back to the opensource template as an optional feature!
