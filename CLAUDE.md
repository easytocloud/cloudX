# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project name

**cloudX** — always lowercase 'cloud', capital 'X', even at the start of a sentence.

## What this repo is

CloudFormation templates that provision Amazon Linux 2023 EC2 instances as VSCode remote development backends (Cloud9 successor). There is no build system, no test suite, and no locally-runnable code. The "product" is the three YAML templates in `templates/`.

Client-side connectivity (SSH proxy, VSCode integration) lives in the separate [cloudX-proxy](https://github.com/easytocloud/cloudX-proxy) repository — do not add proxy functionality here.

## Deployment model

Templates are deployed directly to AWS CloudFormation. On merge to `main`, GitHub Actions runs semantic-release and syncs `templates/*.yaml` to `s3://cloudx-public/templates/` (the public launch-stack URL referenced in the README). AWS credentials for the S3 publish are loaded from 1Password via the `OP_SERVICE_ACCOUNT_TOKEN` secret.

To manually validate a template before pushing:
```bash
aws cloudformation validate-template --template-body file://templates/cloudX-environment.yaml
aws cloudformation validate-template --template-body file://templates/cloudX-instance.yaml
aws cloudformation validate-template --template-body file://templates/cloudX-user.yaml
```

## Three-tier architecture

| Template | Deploy when | Creates |
|---|---|---|
| `cloudX-environment.yaml` | Once per environment (e.g. "OTA", "Prod") | IAM role/profile, security group, IAM group with ABAC policies, SSM Parameter Store entries at `/cloudX/{EnvironmentName}/...`, SSM Command Document (CFN-generated name stored in Parameter Store at `/cloudX/{EnvironmentName}/SetupDocumentName`), and an `AutoUpdateAssociation` targeting instances tagged `cloudX:update=auto` on a weekly cron |
| `cloudX-instance.yaml` | Per developer per environment | EC2 instance (AL2023), a `SetupAssociation` that fires once on launch (targeting this instance by ID) and passes per-instance parameters to the setup document |
| `cloudX-user.yaml` | Optional, per developer | IAM user `cloudX-{Env}-{User}`, access keys stored in Parameter Store — prefer SSO roles over this |

The environment template stores all shared config in SSM Parameter Store; the instance template reads it via `{{resolve:ssm:...}}` — no values are duplicated between stacks.

## Pet model: SSM State Manager, not UserData

Instance configuration is delivered by SSM State Manager, not UserData. UserData only starts the SSM Agent. All setup logic lives in the `CloudXSetupDocument` SSM Command Document inside `cloudX-environment.yaml`.

- **First run**: `SetupAssociation` (per-instance, in `cloudX-instance.yaml`) has no schedule — it fires once on association creation (`ApplyOnlyAtCronInterval: false`) and never again.
- **Recurring updates**: `AutoUpdateAssociation` (in `cloudX-environment.yaml`) targets `tag:cloudX:update=auto` instances on a `cron(0 2 ? * SUN *)` schedule (Sundays at 02:00 UTC) with `ApplyOnlyAtCronInterval: true` — strictly schedule-only, never fires on association creation or tag match. This prevents a race with `SetupAssociation` on first launch.
- **Manual mode**: Set `UpdateMode=manual` on the instance stack; the instance gets tag `cloudX:update=manual` and is never picked up by the auto-update association.

To push an update to running instances without recreating them:
```bash
# Update the environment stack (new document version)
aws cloudformation update-stack --stack-name cloudX-OTA-environment \
  --template-body file://templates/cloudX-environment.yaml \
  --capabilities CAPABILITY_IAM

# Trigger immediate re-convergence
aws ssm start-associations-once \
  --association-ids $(aws ssm list-associations \
    --association-filter-list key=DocumentName,value=cloudX-OTA-setup \
    --query 'Associations[].AssociationId' --output text)
```

## SSM document structure

The `CloudXSetupDocument` runs as root except for the `user` step. Steps in order:

1. `base` — yum packages, directory scaffold, marker file `.install-running`
2. `resolve_owner_tag` — if the ABAC owner tag is empty (cloudX-instance.yaml's `UserName` left blank), resolves it to the launching SSO principal's session name, read from the instance's own `aws:servicecatalog:provisioningPrincipalArn` auto-tag (Service Catalog only — see below). Runs early, right after `base`, to minimize the window where the instance's ABAC tag doesn't match anyone and `ssm:StartSession` would fail. Never overwrites an already-set tag.
3. `autoshutdown` — writes idle-shutdown script + systemd timer
4. `install_add_to_rc` — installs `/usr/local/bin/add-to-rc` (upsert-safe rc block manager)
5. `install_direnv_layouts` — writes direnv layout files for `uv` and CodeArtifact
6. `write_bootstrap` — writes `/tmp/cloudx-user-bootstrap.sh` (runs as ec2-user in next step)
7. `user` — `su - ec2-user -c '/bin/bash /tmp/cloudx-user-bootstrap.sh'`
8. `post` — sets zsh as default shell, optionally installs Docker, tags instance with `cloudX:version=<document>@<timestamp>`, removes `.install-running`, and removes `~/.cloudX` (retired — see below)
9. `install_cloudx_cli` — writes `/usr/local/bin/cloudX` (`update`, `whoami`, `timeout show`/`timeout set`, `--version`)

All steps must be idempotent — they run on every State Manager execution, not just at launch.

### No per-user state files — tags are the source of truth

`~/.cloudX/` is retired. Idle-shutdown timeout and the applied cloudX version used to live in files under that directory (`autoshutdown-configuration`, `version`); both are now EC2 tags exclusively:

- `cloudX:shutdown_timeout` — read live (no caching) by `cloudX-stop-if-inactive.sh` on every run, falls back to `30` if unset. Seeded once from the `ShutdownTimeout` CFN parameter at first launch, then never overwritten by reconvergence — change it via `cloudX timeout set <minutes>`, effective within a minute.
- `cloudX:version` — written by `post`, read via `cloudX --version` (or `cloudX whoami` for the ABAC owner tag).

Resolving "self" for `UserName` and reading the ABAC tag key name (itself environment-specific, via `/cloudX/${EnvironmentName}/AbacTag`) both require Service Catalog as the launch path — there's no equivalent for a direct `create-stack` launch.

### Shell rc management

`add-to-rc` writes named, idempotent blocks (`# BEGIN:<name>` / `# END:<name>`) to `~/.cloudxrc` (all shells), `~/.cloudx.bash`, or `~/.cloudx.zsh`. Both `.bashrc` and `.zshrc` source these files. Use `add-to-rc` for all shell environment changes in custom steps.

### Mandatory vs optional software

Mandatory (always installed, no toggle): Homebrew, direnv, uv, zsh + oh-my-zsh + oh-my-easytocloud.
Optional (CloudFormation parameters): `NVM` (+ `NvmVersion`), `DOCKER`, `PRIVPAGE`, `FORTOOLS`.
Intentionally absent: pip — use `uv pip install` / `uv run` instead of modifying the OS Python.

## Customization pattern

Organizations maintain their own template variants by:
1. Inserting values at `CUSTOMIZATION_MARKER` comments in the templates
2. Using a Python script + Makefile to fetch upstream and apply a YAML customization file
3. Custom SSM steps are appended after the `post` step using the same `aws:runShellScript` pattern

See `templates/CUSTOMIZATION.md` for the full pattern with code examples.

## Commit conventions

Semantic Release runs on every push to `main` and drives versioning + S3 publish. Commits must follow Conventional Commits:

- `feat(scope): ...` → minor release
- `fix(scope): ...` → patch release
- `refactor/perf/docs(scope): ...` → patch release
- `chore/style/test(scope): ...` → no release
- Body starting with `BREAKING CHANGE:` → major release

## archive/

`install.sh` and everything under `archive/` are legacy — kept for reference only. Do not update them or reference them in new work.

## Known limitations

### Single region per environment name

The environment template creates global IAM resources (IAM Group, IAM Users via `cloudX-user.yaml`) named after `EnvironmentName` (e.g. `cloudX-OTA-Group`, `cloudX-OTA-erik`). IAM is a global AWS service — deploying the same `EnvironmentName` in two regions within the same account would cause a name clash and the second stack deployment would fail.

This is by design: cloudX is intended for single-region deployments per environment name. If multi-region is needed, use distinct environment names per region (e.g. `OTA-use1`, `OTA-euw1`).

Note: `cloudX-user.yaml` is deprecated in favour of SSO. Once all users have migrated to SSO roles, the IAM User naming constraint no longer applies.
