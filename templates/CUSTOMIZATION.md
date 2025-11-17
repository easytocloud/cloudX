# CloudX Template Customization Pattern

This document describes how to create customized versions of the cloudX instance template while maintaining synchronization with upstream changes.

## Overview

The cloudX instance template includes **customization markers** that allow teams to maintain their own customized versions while automatically inheriting improvements and updates from the opensource template.

This pattern enables organizations to add their own configurations while staying synchronized with the upstream opensource template.

## Customization Markers

The template includes three customization markers:

### 1. EnvironmentName Parameter
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

### 2. ConfigSets
```yaml
        configSets:
          default:
            - 00_base
            - 10_autoshutdown
            - 20_user
            - 30_post
            # CUSTOMIZATION_MARKER:configSets - Add custom configSets here
```

**Purpose**: Add custom configSets to the default execution order.

**Example Customization**:
```yaml
            - 50_custom
            - 60_organization
```

### 3. ConfigSet Definitions
```yaml
            30Finalize:
              command: |
                touch /home/ec2-user/.install-done
                rm -f /home/ec2-user/.install-running
                chown ec2-user:ec2-user /home/ec2-user/.install-done
        # CUSTOMIZATION_MARKER:configSetDefinitions - Add custom configSet definitions here
    CreationPolicy:
```

**Purpose**: Define the implementation of custom configSets.

**Example Customization**:
```yaml
        50_custom:
          files:
            /home/ec2-user/.config/custom/config.conf:
              content: |
                # Custom configuration
                key=value
              mode: '000644'
              owner: ec2-user
              group: ec2-user
          commands:
            00ApplyCustomConfig:
              command: /tmp/apply-custom-config.sh
```

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

# ConfigSets customization
configSets:
  - 50_myorg

# ConfigSet definitions
configSetDefinitions: |
  50_myorg:
    files:
      /home/ec2-user/.config/myorg/settings.conf:
        content: |
          # Organization-specific settings
          org_name="MyOrg"
          region="us-west-2"
        mode: '000644'
        owner: ec2-user
        group: ec2-user
    commands:
      00ConfigureOrg:
        command: echo "Organization configuration applied"
```

### Step 2: Create Python Script

Create a Python script to apply customizations:

```python
#!/usr/bin/env python3
import sys

def apply_customizations(template_content, customizations):
    # Apply EnvironmentName customizations
    if 'EnvironmentName' in customizations:
        allowed_values = customizations['EnvironmentName']['AllowedValues']
        values_yaml = '\n'.join(f"      - '{v}'" for v in allowed_values)
        marker = "    # CUSTOMIZATION_MARKER:EnvironmentName"
        replacement = f"    AllowedValues:\n{values_yaml}"
        template_content = template_content.replace(marker, replacement)

    # Apply configSets customizations
    if 'configSets' in customizations:
        sets_yaml = '\n'.join(f"            - {s}" for s in customizations['configSets'])
        marker = "            # CUSTOMIZATION_MARKER:configSets"
        template_content = template_content.replace(marker, sets_yaml)

    # Apply configSet definitions
    if 'configSetDefinitions' in customizations:
        definitions = customizations['configSetDefinitions']
        indented = '\n'.join('        ' + line for line in definitions.split('\n'))
        marker = "        # CUSTOMIZATION_MARKER:configSetDefinitions"
        template_content = template_content.replace(marker, indented)

    return template_content

# Load template and customizations, apply, write output
# (See example implementation in Step 4 for complete script)
```

### Step 3: Create Makefile

Create a Makefile to automate the process:

```makefile
OPENSOURCE_URL = https://raw.githubusercontent.com/easytocloud/cloudX/refs/heads/main/templates/cloudX-instance.yaml
CUSTOMIZATIONS_FILE = my-customizations.yaml
OUTPUT_FILE = cloudX-instance-custom.yaml

all: $(OUTPUT_FILE)

$(OUTPUT_FILE): $(CUSTOMIZATIONS_FILE)
	curl -fsSL $(OPENSOURCE_URL) -o template.tmp
	python3 apply-customizations.py template.tmp $(CUSTOMIZATIONS_FILE) $(OUTPUT_FILE)
	rm template.tmp

clean:
	rm -f $(OUTPUT_FILE)
```

### Step 4: Generate Custom Template

```bash
make all
```

This fetches the latest opensource template and applies your customizations.

## Benefits

1. **Automatic Updates**: Inherit all improvements from the opensource template
2. **Clear Separation**: Your customizations are isolated and documented
3. **Version Control**: Track customizations separately from base template
4. **Testability**: Easy to test with different versions
5. **Repeatability**: Automated generation ensures consistency

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

Regularly sync with the upstream template to get security updates and improvements:

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
3. The generated template (`cloudX-instance-custom.yaml`)

This allows tracking what changed and why.

## Example Use Cases

Organizations use this pattern to maintain customized cloudX templates with:

- **Environment name validation**: Restrict environments to approved names (dev, staging, prod)
- **Package repository integration**: Configure AWS CodeArtifact or private PyPI servers
- **Organization-specific shell configurations**: Add company-specific aliases and environment variables
- **Compliance requirements**: Add security scanning, logging, or monitoring configurations

## Alternative: Feature Flags

For simpler customizations, consider using CloudFormation conditions and parameters instead:

```yaml
Parameters:
  EnableCustomFeature:
    Type: String
    Default: 'false'
    AllowedValues: ['true', 'false']

Conditions:
  UseCustomFeature: !Equals [!Ref EnableCustomFeature, 'true']

# In configSet:
        50_custom:
          files:
            /tmp/custom-setup.sh:
              content: !If [UseCustomFeature, "echo 'Custom feature enabled'", "echo 'Custom feature disabled'"]
```

## Support

For questions about the customization pattern:
- Open an issue in the cloudX GitHub repository
- Contact the maintainers

## Contributing

If your customization would benefit others, consider contributing it back to the opensource template as an optional feature!
