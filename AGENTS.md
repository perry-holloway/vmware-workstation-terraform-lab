# Repository guidance for coding agents

## Project scope

This repository provisions a four-VM monitoring lab for VMware Workstation Pro on Windows. Terraform coordinates local `vmrun` commands and remote provisioning over SSH. PowerShell manages the Windows host and VMware VMX files; Bash scripts configure Ubuntu guests.

## Working rules

- Keep changes focused and explain why they are needed.
- Do not run `terraform apply`, start or stop VMs, edit VMX files, or connect to lab hosts unless the user explicitly requests it.
- Never commit Terraform state, real variable files, credentials, SSH keys, generated VM paths, or environment-specific IP addresses.
- Preserve the division between Windows orchestration in PowerShell and guest provisioning in Bash.
- Make provisioning scripts safe to rerun. Prefer explicit checks and idempotent commands.
- Quote paths and external input defensively, especially in PowerShell commands passed through Terraform.
- When a provisioned file or script changes, ensure the relevant `triggers_replace` hash in `main.tf` covers it.
- Pin deployable dependencies where practical and document intentional floating versions.

## Required validation

Run the checks that apply to the files changed:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

For Bash scripts, run ShellCheck when available:

```bash
shellcheck scripts/*.sh
```

For PowerShell scripts, run PSScriptAnalyzer when available:

```powershell
Invoke-ScriptAnalyzer -Path scripts -Recurse -Severity Warning,Error
```

Validate edited JSON and YAML files with an appropriate parser. Validation must not require VMware Workstation or live VMs unless the change specifically concerns integration behavior.

## Review expectations

- Describe the user-visible or operational effect of the change.
- Identify commands run and any checks that could not be performed.
- Call out changes to ports, credentials, network exposure, image versions, or destructive behavior.
- Keep documentation and `terraform.tfvars.example` synchronized with new variables and defaults.
- Prefer multiple focused commits over a single unrelated batch.

## AI-assisted contributions

AI-generated suggestions are drafts, not authority. Verify commands against the target operating system, inspect security-sensitive changes manually, and record meaningful AI assistance in the pull request description. Do not claim a validation command passed unless it was actually run.
