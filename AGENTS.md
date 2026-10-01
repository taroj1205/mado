# AGENTS.md

## Design and plan

- Before implementing a feature, read `.agents/references/launcher.md` (local only, gitignored because it holds private artifact IDs). It links the Launcher design canvas and the implementation plan doc, and says how to read them and which goal ID (`M2-07`) to put on branches and commits.

## Order of work

- Before starting a goal, check its native blocked-by relationships with `gh api repos/taroj1205/mado/issues/<n>/dependencies/blocked_by`. If a blocker is open, do not start the goal. Work the nearest blocker that is not itself blocked, or ask which to do. Goal numbers and the issue body do not show order.
- Do not open a PR for a goal while a blocker is open. If one was opened by mistake, close it or convert it to a draft and say why.

## Commits

- Before committing, read `.agents/references/commits.md`. It covers the subject format and when to add `Closes #<issue>`.

## Research before designing

- Before designing a goal or choosing an approach, read primary sources: official Apple and Swift documentation, Swift Evolution proposals, and WWDC sessions. Match them to the toolchain in use (Swift 6.4, Xcode 27, macOS 14 or later) and check that a proposal has shipped before relying on it.
- Skip blog summaries, aggregator pages, and AI-generated "skills" sites unless a primary source backs the same claim.
- State the sources and what was adopted or rejected in the design discussion, and record the decision that matters in the issue or commit body. If no authoritative source exists, say so instead of presenting a guess as best practice.

## Pull requests

- Never commit to `main` directly. Work on a task branch with a conventional name (`feat/...`, `fix/...`, `chore/...`) and open a PR with the `pr-local` skill.
- Build the PR body from `.github/pull_request_template.md`. `gh pr create --body` and `--body-file` don't apply it, so copy its sections in.
- PRs are ready for review by default. Do not merge them; merging is the maintainer's call.
- After every push, wait for the CI result on the latest head before calling the work done, and report a failure as a failure.
- CI runs the toolchain it is pinned to, which can lag the local one. A rule that passes locally can still fail in CI, so do not rely on the local result alone.
