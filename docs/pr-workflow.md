# PR Workflow

## Before opening a PR

1. Start from an up-to-date `main`.
2. Create a focused branch: `git checkout -b port/<feature>`.
3. Port the upstream test first, then the implementation.
4. Run the gates:

   ```bash
   make format-check
   make lint
   make test
   ```

5. Update `plans/parity.md` (including the **Where we are** block) and any
   affected inventory rows.
6. Commit atomically using the `port: ...` format described in `AGENTS.md`.

## PR contents

- One completed feature per PR where practical.
- Link the upstream Go file, test, and behavior being ported.
- List any intentional divergence and why it cannot be avoided.
- Include gate results and the upstream commit (`6b8d4ba`).

## Review checklist

- [ ] Behavior matches `vendor/ultraviolet/`.
- [ ] Upstream tests or equivalent characterization specs were added.
- [ ] `make lint` and `make test` pass.
- [ ] No changes under `lib/` or `vendor/`.
- [ ] Parity plan and inventory are current.
- [ ] Divergences are documented.

## After merge

Push the branch result to `main` and confirm the remote is up to date. The next
session should be able to resume from the **Where we are** block alone.
