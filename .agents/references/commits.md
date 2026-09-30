# Commits

- Subject: `type(scope): summary`, scope required. Put the goal ID in the scope, e.g. `feat(M0-01): ...`. The commit-msg hook in `.githooks/` enforces this.
- When a commit finishes a goal, add `Closes #<issue>` on its own line at the end of the body. GitHub closes the issue when the commit reaches the default branch.
- Find the issue by goal ID: `gh issue list --repo taroj1205/mado --search "M0-02 in:title" --state all`.
- Use `Closes` only for the issue the commit actually completes. Never use it for a milestone tracker (`M0: 土台` and similar); those close when their sub-issues are done.
- A commit that only moves a goal forward does not close it. Reference it with `Refs #<issue>` instead.
