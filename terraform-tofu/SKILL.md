---
name: terraform-tofu
description: "Author or change Terraform/OpenTofu configuration with native test-first development. Use when asked to implement or modify Terraform/OpenTofu configuration, or when another skill needs Terraform/OpenTofu implementation."
---

# Terraform/OpenTofu authoring

Bind one repository-selected engine and version, then use that engine's native tests for the entire change. Never migrate engines as part of this workflow.

## 1. Bind the engine, version, and forge context

1. Read repository instructions, wrappers, CI, version-manager files, `required_version`, dependency locks, and existing `.tftest.hcl` files. Record every engine/version signal.
2. Require repository evidence to select exactly one of `terraform` or `tofu` and one exact supported version. Record the selected CLI and its exact version output. Missing, conflicting, ambiguous, or constraint-only evidence blocks work.
3. Verify the selected version exposes its native test command with `<selected-cli> test -help`. An unavailable command or unsupported required test feature blocks work; never switch engines or add a test framework.
4. Invoke `/forge preflight` exactly once for provider/repository binding. If it reports GitLab, GitHub, or Azure DevOps, load only its selected provider branch. If it proves there is no remote, record `forge_mode: local-only`. Unknown, ambiguous, or profile-mismatched evidence blocks work. Use `/forge snapshot` only when issue, change-request, or CI context exists.

## 2. Inspect the baseline and define one behavior

- Read the affected module, callers, existing tests, provider/version constraints, lock file, and repository Check Gate. Preserve existing wrappers and layout.
- Identify state, backend, provider, credential, provisioner, lifecycle, and live-infrastructure boundaries before changing configuration.
- Define one behavior observable through the module's public inputs, outputs, resources, or checks. Read [authoring rules](reference/authoring.md) only while editing configuration and [native-testing rules](reference/native-testing.md) before writing the test.

## 3. Prove native RED

1. Write or change one behavior-level `.tftest.hcl` test first.
2. Run exactly `<selected-cli> test` through the repository wrapper when one exists; otherwise run exactly `terraform test` or `tofu test` from the correct module directory.
3. Require an observed failure caused by the missing intended behavior. A passing-first test, unrelated error, unexecuted test, parse/setup failure, or external framework is not RED and blocks implementation.
4. Record the command, test file/run block, expected behavior, and failure summary without credentials or sensitive values.

## 4. Make the smallest GREEN change

- Change only enough configuration to satisfy the failing behavior, using the same selected engine and command until the test passes. Record the matching GREEN command and result.
- Do not silently change the engine, backend, state, provider lock selections, credentials, or test mode.

## 5. Refactor while green

Simplify only the changed configuration: delete duplication, improve names, apply repository style, and add no speculative modules or compatibility layers. Re-run the same selected-engine native test after each refactor.

## 6. Validate and hand off

- Run the repository's documented targeted checks and Check Gate with the selected engine. With none documented, run non-mutating fallbacks only: `<selected-cli> fmt -check`, `<selected-cli> validate`, `<selected-cli> test`. Do not initialize or alter a backend/provider lock merely to make validation run; report the blocker.
- The skill never publishes, approves, merges, queues, or performs post-merge actions. Those stay with the enclosing authorized delivery workflow through `/forge`.
- Report engine and exact version, forge binding or local-only mode, baseline, RED/GREEN evidence, changed paths, checks, safety decisions, and blockers.

## Safety stop

Prefer explicit plan-mode native tests and supported native mocks/overrides. Never use credentials, live apply, remote/shared state, backend migration/reconfiguration, or provisioners unless the task explicitly authorizes that exact surface. A native apply-mode test against real infrastructure additionally requires a documented disposable target, isolated credential/state/backend boundaries, and cleanup evidence; otherwise stop before execution.
