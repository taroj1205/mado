# AGENTS.md

## Design and plan

- Before implementing a feature, read `.agents/references/launcher.md` (local only, gitignored because it holds private artifact IDs). It links the Launcher design canvas and the implementation plan doc, and says how to read them and which goal ID (`M2-07`) to put on branches and commits.

## Commits

- Before committing, read `.agents/references/commits.md`. It covers the subject format and when to add `Closes #<issue>`.

## Research before designing

- Before designing a goal or choosing an approach, read primary sources: official Apple and Swift documentation, Swift Evolution proposals, and WWDC sessions. Match them to the toolchain in use (Swift 6.4, Xcode 27, macOS 14 or later) and check that a proposal has shipped before relying on it.
- Skip blog summaries, aggregator pages, and AI-generated "skills" sites unless a primary source backs the same claim.
- State the sources and what was adopted or rejected in the design discussion, and record the decision that matters in the issue or commit body. If no authoritative source exists, say so instead of presenting a guess as best practice.
