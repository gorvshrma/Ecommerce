# Rules that protect the main branch

The rules are active on GitHub. They were created and read back on 2026-10-29.
[Open ruleset 26079102](https://github.com/gorvshrma/Ecommerce/rules/26079102).
The intended settings are saved in [main-ruleset.json](../.github/main-ruleset.json).
Editing that file alone does not update GitHub; an administrator must apply it.

## What happens when you want to change main?

Create a branch, push it, and open a pull request. GitHub checks these five jobs:

1. `Backend Tests & Code Quality`
2. `Frontend Build`
3. `Docker Build Validation`
4. `Trivy Security Scan (backend)`
5. `Trivy Security Scan (frontend)`

All five must pass. They must come from the GitHub Actions app (integration ID
15368), so an unrelated status with the same name cannot satisfy the rule.
Your branch must include the latest `main` changes. Resolve review conversations
before merging. A draft PR must be marked ready before it can merge.

Force pushes and deletion of `main` are blocked. No bypass actors are configured.
There is no required second approval because this is a solo portfolio. You can
ask another person to review; do not claim an independent review when none happened.

## Normal update commands

```bash
git switch main
git pull --ff-only origin main
git switch -c codex/describe-your-change
# Edit files, inspect git diff, test, and stage only intended files.
git commit -m "Describe the change"
git push -u origin codex/describe-your-change
```

Open a PR against `main`. If GitHub says the branch is behind, fetch and merge
`origin/main` into your feature branch, fix conflicts, test, and push again.
Avoid force pushes. Never disable checks just to get a broken change merged.

## How to recover from a bad merge

Make a new branch from current `main`, run `git revert` for the bad commit,
and send the revert through a PR with the same checks. This preserves history.
For a merge commit use `git revert -m 1 COMMIT_ID`; for a squash commit use
`git revert COMMIT_ID`. These commands undo code, not database changes.
[The runbook](RUNBOOK.md) gives the full sequence.

## Rules rollback

Before this work there were no rulesets or legacy protection rules. To restore
that earlier setting, an administrator can delete only ruleset 26079102 from
the GitHub rules page. This removes protection; it is not needed for normal code
rollback. With an authenticated GitHub CLI, the exact API command is:

```bash
gh api --method DELETE repos/gorvshrma/Ecommerce/rulesets/26079102
```

Do not run it during routine work. The `gh` program is optional and is not
installed by this project. The saved before/after API records are outside the repo.

[GitHub rules documentation](https://docs.github.com/en/rest/repos/rules).
