# cloudX

**cloudX** — 'cloud' always lowercase, capital X, even at the start of a sentence.

## What is cloudX

CloudFormation templates that provision Amazon Linux 2023 EC2 instances as VSCode remote development backends — a Cloud9 successor. Instance configuration is managed via SSM State Manager (not UserData), enabling updates to running instances without recreation.

## Repository layout

- `templates/` — the three CloudFormation templates that are the product
- `archive/` — legacy scripts, kept for reference only, not maintained
- `.ai/context/` — structured context files for AI tooling; read all files here for full project understanding

## Related repositories

- **[cloudX-proxy](https://github.com/easytocloud/cloudX-proxy)** — client-side SSH proxy; Python, published on PyPI, installable with `uvx`. Handles SSH config, key management, and automatic instance wake-up on Mac and Windows.
