# Native-testing rules

Use only the native test features supported by the bound engine/version. Terraform and OpenTofu can differ; verify the selected CLI's documentation and `test -help` instead of assuming parity.

## Test shape

- Put tests in `.tftest.hcl` files and assert caller-visible behavior: outputs, resources, checks, or plan diagnostics.
- Prefer the default plan-mode execution. Use native mock providers, mock data/resources, and overrides only when the bound version supports them and the behavior needs them.
- Keep fixtures deterministic and local. Assert the real behavioral delta rather than source text, internal expression shape, incidental ordering, or provider implementation details.
- One RED covers one missing behavior. Preserve the same run block, command, variables, and safe execution mode through GREEN and refactor.
- An expected failure is valid only when it identifies the intended missing behavior. Parser errors, initialization failures, unavailable providers, credentials, networking, or unrelated assertions block implementation.

## Apply-mode guard

Do not use `command = apply` against real infrastructure by default. It is allowed only when explicit task authority names the live-apply surface and all of these are documented before execution:

1. a disposable target with bounded ownership;
2. isolated credentials with least privilege and no value disclosure;
3. isolated local state and backend boundaries that cannot touch shared/remote state;
4. deterministic cleanup plus observed cleanup evidence.

Missing or ambiguous evidence stops the run. Native mocks or plan-mode coverage are the safe replacement; never weaken the behavior merely to avoid the guard.

Official command references:

- Terraform tests: <https://developer.hashicorp.com/terraform/language/tests>
- OpenTofu tests: <https://opentofu.org/docs/cli/commands/test/>
