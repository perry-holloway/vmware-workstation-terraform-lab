# AI-assisted development

This project uses AI as a collaborative engineering tool. The repository owner remains responsible for architecture, security decisions, testing, and every accepted change.

## How AI was directed

AI work is framed as a concrete engineering task with boundaries and an expected verification step. Useful task briefs include:

- Review the Terraform orchestration without running `apply` or changing any live VM.
- Propose maintainability improvements as focused commits rather than cosmetic activity.
- Keep Windows host automation in PowerShell and Ubuntu guest setup in Bash.
- Check that secrets, state, generated paths, and private keys cannot be committed.
- Add validation that can run without VMware Workstation or access to the lab network.

Durable instructions for coding agents live in [`AGENTS.md`](../AGENTS.md). They define safety boundaries, validation commands, and review expectations.

## Human review loop

The working loop is:

1. Define a narrow problem and relevant constraints.
2. Ask the AI to inspect the existing implementation before proposing a change.
3. Review the proposal for correctness, security, and fit with the lab architecture.
4. Apply the smallest useful change.
5. Run static checks and inspect the diff.
6. Commit the change with a message that explains its purpose.

AI output is not accepted solely because it is syntactically valid. Commands that affect VMware guests, VMX files, credentials, firewall rules, or Terraform state require additional human scrutiny.

## Example evolution

The initial repository established the working monitoring lab. A later AI-assisted maintainability pass reviewed the public repository against the following goals:

- Make the instructions given to coding agents visible and reusable.
- Explain how AI suggestions are reviewed rather than presenting the project as a generated code dump.
- Add contribution and validation guidance for people who do not have the author's lab.
- Add automated checks that do not attempt to provision VMware infrastructure.
- Strengthen Terraform input validation and reproducibility where appropriate.

Each concern is recorded as a separate commit so reviewers can follow the reasoning and inspect changes independently.

## Verification policy

Safe offline checks include Terraform formatting and validation, static analysis of shell and PowerShell scripts, and parsing JSON or YAML configuration. A successful static check does not prove that a VMware deployment works.

Live verification is reported separately and should identify:

- the host and VMware Workstation version;
- whether the test used fresh clones or existing VMs;
- the Terraform command executed;
- which service endpoints and monitoring targets were checked; and
- any manual steps or deviations from the documented setup.

## Known limitations

- VMware Workstation has no first-party Terraform provider, so this project intentionally uses `terraform_data`, local `vmrun` automation, and SSH provisioners.
- CI cannot reproduce the complete lab because hosted runners do not have the local VMware environment.
- Provisioner-based Terraform resources require deliberate trigger hashes to rerun when scripts or generated configuration change.
- AI can suggest plausible but incorrect commands, versions, or assumptions. Repository checks and human review remain mandatory.

## Contribution disclosure

When AI materially contributes to a change, summarize that assistance in the pull request. A useful disclosure states what the AI helped with, what the contributor changed or rejected, and which checks were run. Do not include private prompts, credentials, machine-specific paths, or sensitive environment details.
