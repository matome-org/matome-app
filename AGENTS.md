# Agent rules

The contract for anyone, human or agent, changing this repository. It is
self-contained: do not fetch an external skill to commit, and do not add
a second toolchain beside mise.

Every section except **This project** is shared across repositories and
copied as-is. Architecture, layout, and constraints of this tree live
only under **This project**.

## Premises

- **Performance is a reason to change.** A correct change that makes
  sense is made even when it saves 0.01 ms. Measure when being wrong is
  costly; "nobody will notice" is not a veto.
- **Zero dead code.** Delete unused functions, types, imports, flags,
  and files. A replacement never sits beside what it replaces.
- **Zero duplicated code.** One implementation per behaviour; extract
  and share instead of copying.
- **Zero legacy code.** No shims, deprecated aliases, dual paths, or
  "remove later" leftovers. A cutover finishes in the change that starts
  it.
- **Comments state the code.** A comment names what the next lines do,
  or a constraint the language cannot express. Not a tutorial, a
  history, or an essay.
- **English only.** Code, comments, commits, `docs/`, `README.md`, this
  file, and mise task names and descriptions.

## Working

- **No spin-busy.** Do not rebuild or rerun checks after each edit.
  Implement the whole change first and make it work, then run the
  project's full verification once: whatever build, tests, and checks
  the project defines (**This project** names them). A session that ends
  in several commits verifies the last one, not each commit.
- **Pictures are for releases.** Capture the whole program, on every
  target it ships to, only when preparing a release. Between releases,
  capture only what a change touches, and only when you need to see it.
- **Clean up after every run.** A build, test, or benchmark removes
  what it started, whether it passes or fails: processes, servers,
  devices, containers, temporary files, caches. Keep only the result it
  was meant to produce.

## Tooling: mise

mise pins every tool in `mise.toml` and owns every project command. Run
`mise install` before work, then invoke tools through `mise run <task>`
(or `mise exec -- …` when no task exists). Never call an unpinned system
tool. Never add a parallel runner (Make, npm scripts, shell wrappers).

### Tasks

The work lives in **scripts**; mise only consumes them. A
`[tasks.name]` entry names the script and sets `description`, `depends`,
`env`, `sources`, `outputs`, `usage`, and `confirm`. Git hooks and other
callers run the same script. A job is never duplicated as inline
`run =` shell, a file task, and a script.

- Scripts live in `scripts/`, executable, with a shebang. Use
  `MISE_PROJECT_ROOT` when the repo root matters; otherwise paths are
  relative to the project root.
- **Atomic:** one script, one job. Compose with `depends` (parallel) or
  a `run` array (sequential, stops on failure, `set -e` in shell).
  Aggregators such as `check`, `build`, or `bench` only wire scripts
  together.
- **Idempotent:** a second run with the same inputs leaves the same good
  state. Safe from a hook, CI, or `mise run`.
- Every task has a `description`. Use `alias` only for names used often.
  Destructive tasks use `confirm`.
- Skippable builds declare `sources` and `outputs`; `mise watch` needs
  `sources` alone.
- Arguments come from a `usage` spec as `usage_*` environment variables.
  Never use the deprecated Tera `arg()`, `option()`, or `flag()`.
- No file tasks under `mise-tasks/` or any other mise task directory.
- Inspect with `mise tasks ls` and `mise tasks info <name>`. Point users
  to `mise run <name>`, never to a script or `mise exec` one-off that a
  task already covers.

## Documentation

Documentation answers one question at a time for someone using the
project. The tools that build the project keep it true.

- `README.md` is the front door for someone using the project: what it
  is, how to install or obtain it, the main ideas with links to their
  pages, known limitations, requirements, and license, plus pictures
  when the project has a visible interface. Build and development
  commands live in `docs/`.
- `docs/` holds the guides, measurements, and language traps. They do
  not go in comments, in commit messages, or in this file except as
  rules. Each page answers one question and links to the page for any
  task it does not cover.
- Docs change in the same change as the behaviour they describe.
- Facts come from the code or from running it, and outputs are real.
  Say what was measured and what was only read or argued.
- Write short, plain sentences. No marketing and no promises of future
  work.
- Pictures come from the real program running on isolated, synthetic,
  versioned data, never personal data, accounts, or keys. They are
  regenerated for a release (see **Working**).
- Every relative link, image, and anchor resolves.

## Commits (okt-task-commit)

Agents draft and create commits. The human publishes: **never
`git push`**. When the tree is clean, say a push is ready.

### Procedure

1. Read `git status` and `git diff --cached`. If nothing is staged,
   read `git diff` and the untracked files.
2. Make **one intent per commit**. Split with non-interactive staging
   only: `git add <path>` and `git restore --staged <path>`. Never
   `git add -p` or `git add -i`.
3. Take the **scope** from the paths touched.
4. Show every draft message to the user **before** `git commit`.
5. Commit without pushing.

### Message grammar (Conventional Commits 1.0.0)

```
<type>(<scope>)!: <subject>

<body>

<footer(s)>
```

- **type**: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`,
  `build`, `ci`, or `perf`. One type per commit; `feat` and `fix` drive
  SemVer.
- **scope**: a noun from the paths. Omit only when no scope is honest.
- **!**: marks a breaking change, together with a `BREAKING CHANGE:`
  footer.
- **subject**: imperative, at most 50 characters, lowercase after the
  colon, no trailing period.
- **body**: optional, wrapped at 72 columns. Explain why, not the patch.
- **footers**: `Token: value` lines, such as `Refs: #123`.

Never attribute a commit to an agent: no `Co-Authored-By: <model>`, no
`Generated with <tool>`, no model name anywhere. The human running the
session is the author, with no opt-out. Add other `Co-Authored-By`
trailers only for people the user named in this conversation.

Bad: `feat: add filter and fix duplicate insert`.
Good: `feat(filter): add priority option`, then
`fix(insert): prevent duplicates`.

## This project

- Matome is a Qt 6 Quick client. `matome.pro` builds desktop,
  WebAssembly, and Android targets from `src/core/` and `src/gui/`. The
  local Android build targets an x86_64 emulator; releases add a signed
  arm64 APK.
- `mise.toml` is the command entry point. Existing platform build and
  test implementations are in `.scripts/`; new automation goes in
  `scripts/`.
- The full verification is `mise run verify`: QML lint, translation
  completeness, core and studio tests, and the coverage threshold. Web
  and Android e2e have their own tasks (`mise run test:web`,
  `mise run test:mobile`).
- Release pictures cover desktop, web, and mobile.
- On master, GitHub Actions runs Release Please, then packages web,
  macOS, Windows, Linux, and signed Android assets for GitHub Releases.
- `README.md` presents the client and its downloads; build, test, and
  release instructions live in `docs/`.
