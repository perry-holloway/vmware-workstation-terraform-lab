# Contributing

Thank you for helping improve the VMware Workstation monitoring lab. Contributions should remain usable by people who do not share the author's exact VM paths, network, or credentials.

## Before making a change

- Read [`AGENTS.md`](AGENTS.md) for repository safety and validation rules.
- Create a branch from `main` and keep the change focused.
- Do not commit `terraform.tfvars`, Terraform state, SSH material, generated VM paths, or real credentials.
- Use `terraform.tfvars.example` when documenting inputs.

## Local validation

Install Terraform and run:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Changes to guest provisioning scripts should also pass ShellCheck when it is installed:

```bash
shellcheck scripts/*.sh
```

Changes to PowerShell scripts should pass PSScriptAnalyzer when it is installed:

```powershell
Invoke-ScriptAnalyzer -Path scripts -Recurse -Severity Warning,Error
```

These checks do not start VMs or prove that the complete lab deploys. Describe any live VMware testing separately.

## Pull requests

Include:

- the problem being solved;
- the important implementation choices;
- validation commands and their results;
- any checks that could not be performed;
- operational or security effects; and
- material AI assistance, including what was reviewed or corrected by the contributor.

Prefer commit messages in the form `type: concise description`, for example:

```text
docs: explain template preparation
fix: quote VMX paths passed to vmrun
ci: validate Terraform configuration
```

Do not split one logical change into artificial commits, but keep unrelated documentation, automation, and behavior changes separate.

## Design expectations

- Host-side VMware automation belongs in PowerShell.
- Ubuntu guest provisioning belongs in Bash.
- Provisioning should be safe to rerun.
- New user-configurable behavior should have a documented Terraform variable and a representative example value.
- Files used during provisioning must be included in the appropriate replacement trigger so Terraform notices changes.
- Avoid introducing a cloud dependency for functionality that can be validated locally.

## Reporting issues

Include the Windows version, VMware Workstation version, Terraform version, relevant sanitized configuration, and the failing command. Redact passwords, keys, tokens, full user paths, and private network details that are not necessary to reproduce the problem.
