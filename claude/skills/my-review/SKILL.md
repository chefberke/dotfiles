---
name: my-review
description: >
  Line-by-line review of a change set or a GitHub PR/issue, run in a fresh context by the
  reviewer agent. Modes: local changes (auto-detect branch delta / uncommitted / last commit),
  or a PR/issue number. Fans out to parallel subagents when large, reads every changed hunk and
  every new file in full, traces callers of changed symbols, refutes its own findings, and emits
  a fixed-format report. Report only — never edits files. Use when the user says "review",
  "review et", "değişiklikleri incele", "my review", or runs /my-review.
argument-hint: "[#N — a PR or issue number; empty reviews local changes]"
---

# my-review

You finished a feature, or you want eyes on a PR; this reads what changed and hands back one
report. It answers three questions, in this order: is what you wrote wrong, is it unsafe, and is
it finished. The value is in actually reading the diff and checking who calls what — not in
producing findings. Zero findings is a good outcome and never gets padded to look thorough.

## Invocation

Two modes, nothing else.

| Argument | What it reviews |
|---|---|
| `#N` or `N` or `pr N` or `issue N` | GitHub pull request `#N`, or issue `#N` via its linked PR |
| anything else, including empty | Local change set (auto-detect) |

Examples: `/my-review` · `/my-review #16` · `/my-review 16`

An argument that is not a number is not an error and never aborts the run: it means local. There
is no ref, range, or uncommitted-only mode — the local auto-detect already covers committed and
uncommitted work in one pass.

## Which context am I?

**You are the `reviewer` agent** (your system prompt says so) → `Read
~/.claude/skills/my-review/LESSONS.md` first and apply what is in it for the rest of the run;
it is this reviewer's accumulated experience and it outranks your instincts, though never these
rules. Then run Steps 1–6. Your final message is the report.

**Anywhere else** (main conversation, user typed `/my-review`) → do not review, dispatch: spawn
one agent, `subagent_type: "reviewer"`, `run_in_background: false`, prompt `Review the current
change set. Scope argument: $ARGUMENTS` (`none` if empty). Relay what it returns **verbatim** —
the whole `═══ REVIEW ═══` block, or its one-line abort message. No preamble, no summary in your
own words, no offer to fix anything.

Then, only if the report ends with a `LESSON:` line, ask in one sentence whether to keep it. On
yes, append it to `~/.claude/skills/my-review/LESSONS.md` under that file's rules. That is the
only writing this skill ever does, and it happens in your context, not the reviewer's — the
reviewer has no `Write` on purpose. Then stop.

The fresh context is the point: whoever wrote the code is the worst available judge of it.

## Rules

1. **Never edit, stage, commit, or revert.** Not even a trivial fix. Build gates may leave
   artifacts (`dist/`, `target/`, `.next/`); nothing else gets written.
2. **Never fabricate.** A gate you did not run is `n/a`. A caller you did not open cannot appear
   in `IMPACT`. Real error counts only.
3. **Evidence bar for findings.** A finding ships only with a concrete `TRIGGER:` — an input,
   state, or sequence producing a wrong result, a crash, or a security hole. "If someone later
   does X" is not a trigger. No style, naming, formatting, or preference findings, ever. When
   unsure, drop it: a reported bug that is not real costs more than a missed one, because it
   teaches the reader to stop trusting the report.
4. **Evidence bar for gaps.** A gap is code this change obliges but that is not there. It ships
   only if you name the exact place you looked and found nothing — a `file:line`, a symbol, a
   config key — and you actually looked. Advice that would fit any diff ("add more tests",
   "consider documenting this") is not a gap. If you cannot point at the hole, there isn't one.
5. **Two severities.** `CRITICAL` = wrong behavior, data loss, crash, security hole, or breaks an
   existing caller. `WARN` = real defect with a narrow trigger. Nothing else exists. Gaps carry
   no severity; they are listed separately.
6. **No silent skips.** Anything not reviewed goes in `SKIPPED:` with a reason.

---

## Step 1 — Scope

Parse `$ARGUMENTS` first. Strip a leading `#` from a bare number. Case-insensitive keywords.

### 1a — PR / issue number

If the argument is a number, or matches `pr #?N` / `issue #?N` / `#N`:

```bash
N=<number>
# Prefer a pull request
gh pr view "$N" --json number,title,body,baseRefName,headRefName,url,author,files,additions,deletions 2>/dev/null
```

**PR exists** → scope label `PR #$N (<head> → <base>)`. Diff source, in order of preference:

1. Local checkout already on the PR head (or has the ref):  
   `BASE_SHA=$(gh pr view $N --json baseRefOid -q .baseRefOid)`  
   `HEAD_SHA=$(gh pr view $N --json headRefOid -q .headRefOid)`  
   then `git diff $BASE_SHA...$HEAD_SHA` (three-dot: merge-base of base…head, i.e. the PR diff).  
   If OIDs are missing, `git fetch origin pull/$N/head:refs/pr/$N` then  
   `git diff origin/<base>...refs/pr/$N`.
2. Fallback when local git cannot resolve the commits: `gh pr diff $N` for the patch, and  
   `gh pr diff $N --name-only` for the file list. Read file contents at HEAD of the PR via  
   `gh pr diff $N -- <path>` hunks plus `gh api` / local file if checked out.

Also read the PR title and body once — they are stated intent for Step 3 INTENT lines, not
evidence. Do not treat the description as proof the code is correct.

**PR does not exist** → try the issue:

```bash
gh issue view "$N" --json number,title,body,url,state
# Linked PRs that close or reference this issue
gh pr list --search "linked:$N" --json number,title,state,url
# Fallback search
gh pr list --search "$N" --state all --limit 10 --json number,title,state,body,url
```

- Exactly one clear linked/open PR → review that PR as above; scope label  
  `issue #$N → PR #<pr>`.
- Several candidates → reply exactly  
  `my-review: issue #$N links to multiple PRs (<list>). Pass a PR number.` and stop.
- None → reply exactly  
  `my-review: issue #$N has no linked pull request — nothing to diff.` and stop.
- Issue missing too → reply exactly  
  `my-review: no pull request or issue #$N in this repo.` and stop.

`gh` not authenticated or not a GitHub repo → reply exactly  
`my-review: cannot resolve #$N (gh failed: <short error>).` and stop.

For PR scope, **do not** mix in the local working tree. Review the PR commits only. Untracked
local files are out of scope (list under `SKIPPED:` only if the user also has them dirty and it
would confuse — otherwise ignore). Counts come from the PR diff / `gh pr view` additions and
deletions.

Then jump to the classify/exclude block at the end of Step 1 (skip 1b).

### 1b — Local scope

Everything that is not a PR/issue number lands here, `$ARGUMENTS` empty or not. Ignore the
argument's text and auto-detect the scope below.

Not a git repo → reply exactly `my-review: not a git repository — nothing to diff.` and stop.

```bash
for c in origin/main origin/master main master develop; do
  git rev-parse --verify --quiet "$c" >/dev/null && BASE=$c && break
done
[ -z "$BASE" ] && BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
[ -n "$BASE" ] && MERGE_BASE=$(git merge-base HEAD "$BASE")
git status --porcelain     # dirty?
```

| Condition | Scope label | Diff |
|---|---|---|
| `$MERGE_BASE` set and `!= HEAD` (feature branch) | `<BASE>...HEAD + worktree` | `git diff $MERGE_BASE` + untracked |
| else, dirty | `working tree` | `git diff HEAD` + untracked |
| else | `HEAD~1..HEAD` | `git diff HEAD~1 HEAD` |

Branch state decides before dirtiness: an uncommitted edit on top of branch commits does not
replace them. Row 1 is `git diff $MERGE_BASE` with **no `...HEAD`** — that compares the merge
base to the *working tree*, so committed and uncommitted work land in one review.
`<base>...HEAD` would silently drop the uncommitted part; do not use it.

Two guards, each of which aborts the whole run if you skip it:

- **No base branch resolves** (repo has only `dev`/`trunk`, or no remote) → `$MERGE_BASE` is
  empty, fall through to row 2 or 3. Never run `git merge-base` against an unset ref.
- **Row 3 needs a parent.** If `git rev-parse --verify --quiet HEAD~1` fails (single-commit
  repo), scope is `HEAD`, every file in it is `NEW`, counts come from `git show --stat HEAD`.

Then collect — and add untracked files by hand, because **`git diff` and `--numstat` cannot see
them**, so a feature made of new files otherwise reads as zero files and zero lines:

```bash
git diff --numstat <range>                                    # tracked: +/- per file
git ls-files --others --exclude-standard -z | xargs -0 wc -l  # untracked: added lines each
```

Untracked files are `NEW`, `+<lines> −0`. For row 1, split committed from uncommitted for the
header using `git diff --name-only $MERGE_BASE HEAD` vs `git diff --name-only HEAD` plus the
untracked list — do not field-split `git status --porcelain`, which quotes paths containing
spaces and writes renames as `R old -> new`. Uncommitted files get an `(uncommitted)` tag in the
report.

### Classify (both 1a and 1b)

Empty diff → reply exactly `my-review: no changes in scope (<label>).` and stop.

Classify each file `NEW` / `MODIFIED` / `DELETED` / `RENAMED`. **Exclude and list under
`SKIPPED:`**: lockfiles, `dist/`, `build/`, `.next/`, `vendor/`, `node_modules/`, `*.min.*`,
`*.snap`, files with a codegen header, binaries, and any single file with more than 2000 changed
lines (`+a` + `−d` for that path; for an untracked file, its full length).

---

## Step 2 — Gates in the background

Detect from the project and launch with `run_in_background: true` **before** Step 3, so they
compile while you read; collect them with the `Monitor` tool in Step 6. A gate you background and
never monitor is `n/a` — rule 2 forbids guessing at its result.

For **PR scope (1a)**: run gates only if the working tree matches the PR head (same commit). If
you are not on the PR head, set all gates to `n/a` with reason `not on PR head` — do not run
build/lint against unrelated local code and report it as the PR's result.

| Signal | build | lint | types |
|---|---|---|---|
| `package.json` | `scripts.build` | `scripts.lint` | `scripts.typecheck`/`type-check`, else `npx tsc --noEmit` if `tsconfig.json` |
| `Cargo.toml` | `cargo build` | `cargo clippy -- -D warnings` | folded into build |
| `go.mod` | `go build ./...` | `go vet ./...` | folded into build |
| `pyproject.toml` | n/a | `ruff check .` if configured | `mypy .` if configured |
| `Makefile` with the target | `make build` | `make lint` | `make typecheck` |

Use the package manager the lockfile implies (`pnpm`/`yarn`/`bun`/`npm`). A command that is
absent is `n/a`, never a substituted guess. On failure keep the error count and first 3 lines.
Never run the test suite: these projects do not have one, and "no tests" is a deliberate choice
here, not a gap.

---

## Step 3 — Correctness: read every file

This step asks one question — is the code that is there wrong? Security and completeness are
Step 4's, handled by their own agents, because both are questions about the change set as a
whole and neither survives being cut into per-file batches. **Launch Step 4's two agents in the
same message as this step's work**, so all three lenses run at once instead of in sequence.

**Mode is arithmetic, not a feeling.** `F` = reviewable files after exclusions, tracked *and*
untracked; `L` = total changed lines (`+a` + `−d`), untracked counting their full length.

- `F ≤ 10` **and** `L ≤ 1000` → **SOLO**, review them yourself
- otherwise → **FAN-OUT**

Do not override in either direction. "I can handle this one" on a 30-file diff is how a review
goes shallow without anyone noticing; six agents on a 3-file diff is pure overhead. Record the
mode for the header.

### The procedure — identical in both modes

Largest change first: attention is a budget, spend it where the most changed. Finish each file
before starting the next.

1. Diff for the path — `git diff <range> -- <path>` or the PR patch hunks for that path. Read
   every hunk. Read the `-` line and the `+` that replaced it, and name the difference in
   behavior. Not "get the gist".
2. Read the surrounding code — at minimum the full enclosing function and the file's imports —
   so you judge the change in context, not as a floating hunk. On PR scope without a local
   checkout, read via the best available source (checked-out worktree, `gh api` file contents at
   the head SHA).
3. `NEW` files: `Read` the entire file, top to bottom. Note its exports, any module-level side
   effects, and whether it duplicates something that already exists (grep two or three of its
   distinctive names before concluding it is novel).
4. **Blast radius.** For every changed function signature, exported symbol, prop, type, exported
   constant, route, env var, or DB column, `Grep` for call sites (it honours `.gitignore`, so it
   will not drag `node_modules/` in; falling back to Bash, pass
   `--exclude-dir={node_modules,dist,build,.next,.git}`). Open the plausible ones and decide
   whether the change breaks them. Renamed or removed → find every remaining reference. A caller
   you checked and found still-correct is not a finding; one that breaks is, cited by `file:line`.
5. `DELETED` files: grep for imports of that path.

Record per file: `STATUS`, a one-line `INTENT` (what the change does as the code actually reads,
not as the commit message or PR body claims), and any findings with `LINE CODE LABEL WHY TRIGGER
IMPACT FIX`. Record this for every file, clean ones included — you need it to reason and to count
— but a clean file does **not** get a block in the report. It contributes to the `Clean:` count
and nothing more. Only files with findings are printed.

### FAN-OUT

Batch the ordered list: any file over 100 changed lines gets its own batch, the rest grouped so
no batch exceeds ~5 files or ~400 changed lines. **Cap at 10 batches** — overflow goes in
`SKIPPED:` with the reason `not reviewed — exceeded 10-batch cap`, plus a `NEXT:` item to rerun
once the change set is smaller, naming the files it never reached. Largest-first means the
biggest changes are always covered, and an honest partial review beats a complete-looking shallow
one. Launch every batch in a single message, `subagent_type: "general-purpose"`,
`run_in_background: false`.

Each agent gets the procedure above verbatim, plus:

> Report only — do not edit, stage, or write any file.
> Files in your batch: `<paths>` · Diff range: `<range or PR #N>`
>
> Evidence bar: a finding ships only if you can state a concrete TRIGGER — an input, state, or
> sequence producing a wrong result, crash, or security hole. "Could be a problem later", "not
> very clean", naming, formatting, and style are NOT findings. When unsure, drop it. Prefer zero
> findings over a plausible-sounding guess.
>
> Severities: CRITICAL (wrong behavior / data loss / crash / security / breaks an existing
> caller) or WARN (real defect, narrow trigger). Nothing else exists.
>
> Return EXACTLY this, in English, and nothing else — one block per file:
>
> ```
> FILE: <path>
> STATUS: NEW|MODIFIED|DELETED|RENAMED
> INTENT: <one line: what the change does, as the code actually reads>
> NEWFILE: <NEW only — "N exports, <side effects or 'no module-level side effects'>">
> FINDINGS: none
> - SEV: CRITICAL|WARN
>   LINE: <line number in the new file>
>   CODE: <the changed source line, trimmed to 60 chars>
>   LABEL: <3-6 word name for the defect>
>   WHY: <1-2 sentences on the mechanism>
>   TRIGGER: <concrete input/state/sequence that makes it fail>
>   IMPACT: <what breaks downstream — cite real file:line you actually opened>
>   FIX: <the concrete change, one line>
> ```
>
> `FINDINGS: none` and the `- SEV:` blocks are mutually exclusive: a clean file gets that line
> and nothing after it, a file with findings omits it and lists one block per finding.

You are the assembler, not a rubber stamp. A returned finding is a *proposal*: it still has to
survive Step 5, and any block that arrives malformed, or whose `IMPACT` cites a file the agent
never opened, gets dropped.

---

## Step 4 — Two more lenses, in parallel

Two agents, always, in both modes, launched in the same message as Step 3:
`subagent_type: "general-purpose"`, `run_in_background: false`. Each gets the full changed-file
list and the diff range — not a batch. They are separate contexts on purpose: an agent holding
one checklist and nothing else does not get distracted by the hunk it just read.

### 4a — Security

> Report only — do not edit, stage, or write any file.
> Changed files: `<all paths>` · Diff range: `<range or PR #N>`
>
> Read the diff and judge only what it actually touches. Walk this list; skip every row the
> change set does not trigger, and do not go hunting for a finding to justify your existence —
> returning `FINDINGS: none` is a normal result.
>
> - a new or changed route, handler, action, or job → is there an authn check, and does it
>   verify ownership of the id it was handed, not merely that someone is logged in?
> - request data reaching a query, shell command, file path, redirect, template, or HTML sink →
>   parameterized, escaped, or validated?
> - a hardcoded key, token, or password; a secret reaching a log line, error message, or client
>   payload; a `.env`-shaped file added to the repo
> - a permission, CORS, cookie, or auth-config value loosened
> - a new or bumped dependency, especially one that runs code at install time
>
> Evidence bar: state a concrete TRIGGER — the request, input, or state that reaches the hole.
> "Could be unsafe", "should be validated in principle" and anything you have not traced from an
> attacker-reachable entry point are NOT findings. When unsure, drop it.
>
> Return one block per finding, and nothing else — these fields only, no `STATUS`, `INTENT`, or
> `NEWFILE` line:
>
> ```
> FILE: <path>
> SEV: CRITICAL|WARN
> LINE: <line number in the new file>
> CODE: <the changed source line, trimmed to 60 chars>
> LABEL: <3-6 word name for the defect>
> WHY: <1-2 sentences on the mechanism>
> TRIGGER: <the request, input, or state that reaches the hole>
> IMPACT: <what an attacker gets — cite real file:line you actually opened>
> FIX: <the concrete change, one line>
> ```
>
> Nothing found → return exactly `FINDINGS: none` and stop.

### 4b — Completeness

> Report only — do not edit, stage, or write any file.
> Changed files: `<all paths>` · Diff range: `<range or PR #N>`
>
> Read the diff yourself and work out what each file does — you are launched alongside the
> correctness lens, so no INTENT lines exist yet and none will be handed to you.
>
> Findings are about code that is there and wrong. Your job is the opposite: code this change
> obliges but that nobody wrote — the thing forgotten on the way to "done". Read the diff, then
> for each change ask what it commits the rest of the repo to. The usual pairs:
>
> | The change | Verify it exists |
> |---|---|
> | new field, enum member, or variant | every exhaustive switch, mapping, label table, schema, serializer, form, factory |
> | new or changed DB column / model | a migration, and one that matches the model |
> | new route, endpoint, or action | it is registered, and it has the auth check its siblings have |
> | new env var or config key | `.env.example`, config schema, deploy config, README |
> | renamed or removed symbol | every remaining reference — including strings, docs, and config |
> | new user-facing string | the key exists in every locale file that exists |
> | new error or failure path | somebody actually handles it |
> | new loading, empty, or failure state in UI | the other states of the same component exist too |
>
> Check only the rows the diff triggers. **Verify by grepping for the sibling and finding it
> absent** — a gap you did not look for does not exist, and a gap you cannot point at is not a
> gap. Never report a missing test: this project does not use them. Advice that would fit any
> diff on earth ("consider documenting this") is not a gap either. Zero gaps is a normal result.
>
> Return exactly this, one block per gap, and nothing else:
>
> ```
> GAP: <what is missing, one line>
> WHERE: <the file:line or place you looked and found nothing>
> WHY: <what in the change makes it required — name the file:line that obliges it>
> ```
>
> Nothing missing → return exactly `GAPS: none` and stop.

Both agents' output is a *proposal*, same as Step 3's: it goes through Step 5 before it reaches
the report. Merge duplicates — a file reviewer and the security agent flagging the same line is
one finding, keeping the higher severity.

---

## Step 5 — Refute before reporting

**Every CRITICAL gets an independent refuter**, in both modes. They are rare by design, so this
costs an agent or two. Launch them in one message, `subagent_type: "general-purpose"`,
`run_in_background: false`:

> Try to refute this claim about `<file>:<line>`. Read the actual file and every caller involved
> — do not reason from the claim alone.
> CLAIM: `<label>` — `<why>`
> TRIGGER: `<trigger>` · IMPACT: `<impact>`
> Look for what the claim missed: an early return, upstream validation, a default value, a caller
> that already handles this case, a type that makes the state unreachable.
> Default to REFUTED when uncertain — a reported bug that is not real costs far more than a
> missed one.
> Return exactly two lines: `VERDICT: CONFIRMED|REFUTED` then `REASON: <one line>`.

REFUTED → delete the finding. Do not demote it to WARN to keep it alive, do not mention it in the
report. You cannot audit your own reasoning with the same reasoning that produced it; the
separate context is the whole point.

**Self-refute every WARN**: re-open the cited line (does `CODE` actually say what you wrote
down?), re-open every caller named in `IMPACT` (does it break the way you claimed?), walk
`TRIGGER` concretely to a wrong result without inserting "and if someone later…", then hunt for
the guard you missed — an early return, upstream validation, a default value, a caller that
already handles the case. Findings die here more often than anywhere else. Uncertain → drop it.
This applies to whatever the Step 3 and Step 4 agents proposed, with the same severity you would
apply to your own work: an agent's confidence is not evidence.

**Check every GAP yourself**: open the place the agent says is empty and confirm it is actually
empty. Grep the symbol it claims is unreferenced. Gaps are the easiest thing in this report to
get wrong, because "I did not find it" and "it is not there" look identical from the outside —
and a gap that turns out to already exist is the fastest way to teach the reader to skim past
this section. Cannot confirm the absence → drop it.

---

## Step 6 — The report

Fixed template. Same section order, same labels, same width, every run. Filled from real data —
never invent a line to make the shape look complete.

Write it in plain English: short sentences, common words, no jargon beyond the names the code
itself uses. The reader is scanning this after a long session, not studying it. No emoji — the
labels already carry the severity, and a wall of icons makes a report harder to read, not
easier.

```
═══ REVIEW ══════════════════════════════════════════════════
Scope: <scope label> · <N> files (<c> committed, <u> uncommitted) · +<added> −<removed>
Gates: build <pass|fail|n/a> · lint <pass|fail|n/a> · types <pass|fail|n/a>
Mode:  correctness <solo | N agents> · security 1 · gaps 1 · <n> refuted
Clean: <n> of <r> reviewed files, no findings

VERDICT: <BLOCK | REVIEW | PASS> — <n> critical, <n> warn, <n> gaps
─────────────────────────────────────────────────────────────

▸ <path>  +<a> −<d>
  <INTENT, one line>

  1. CRITICAL · <LABEL>
     L<line>  <CODE>
     <WHY>
     Trigger: <trigger>
     Impact:  <impact>
     Fix:     <fix>

  2. WARN · <LABEL>
     L<line>  <CODE>
     ...

▸ <path> (NEW)  +<a>
  Read in full. <NEWFILE line>

  1. WARN · <LABEL>
     ...

─────────────────────────────────────────────────────────────
GAPS
  1. <what is missing, one line>
     Where: <the place you looked and found nothing>
     Why:   <what in the change obliges it — file:line>

GATE FAILURES
  <gate>: <count> errors
    <first 3 error lines, indented>

SKIPPED: <path (reason)>, <path (reason)>

NEXT: 1. <file:line — shortest possible action>  2. <...>

LESSON: <one line — a general rule this run suggests adding>
═════════════════════════════════════════════════════════════
```

- **Scope line**: the `(<c> committed, <u> uncommitted)` part appears only when the scope
  includes both; otherwise just `<N> files`. For PR scope use `PR #N (head → base)` as the
  label and omit the committed/uncommitted split.
- **Mode line**: always present. How the correctness lens ran (`solo` or `N agents`), then the
  two lens agents, then how many proposed findings and gaps died in Step 5 (`0 refuted` when
  none were proposed). If a report looks thin, this says whether it went shallow or whether the
  findings genuinely died under refutation.
- **`(uncommitted)`** goes after the path in the `▸` header, so it is obvious which findings sit
  in work you can still amend versus work already in history.
- **Only files with findings get a `▸` block.** A file you read and found clean is not printed —
  it is one tick in the `Clean:` count. The `INTENT` line stays, but only inside the blocks that
  survive, where it says what the code with the finding in it is doing.
- **`Clean:` line**: always present, one line, no file names. `<n>` is reviewed files with zero
  findings; `<r>` is reviewed files in total. `<r>` is **not** the Scope line's `<N>` — that one
  counts every file in the change set, this one counts what survived exclusions, so `<r> ≤ <N>`
  and the difference is exactly what `SKIPPED:` lists. All clean → `Clean: all <r> reviewed
  files, no findings`.
- **Order**: files with CRITICAL first, then WARN; git diff order within a tier; findings sorted
  by line and numbered `1.`, `2.`, `3.` within their file.
- **VERDICT**, in order: any CRITICAL or any gate `fail` → `BLOCK`; else any WARN or GAP →
  `REVIEW`; else `PASS`.
- **`GAPS`**: numbered, ordered by how much of the feature is broken without them. This is the
  section that answers "did I finish?", so it earns its place only by staying short and literal
  — every line points at something that is genuinely not there.
- **Omit** the `GAPS` section if there are none, the `GATE FAILURES` section if nothing failed,
  and the `SKIPPED:` line if nothing was skipped.
- **Nothing to report at all** (no findings, no gaps, no gate failures) → the `▸` area is empty,
  so print one rule line instead of two and go from `VERDICT` straight to `NEXT: nothing
  blocking.` The header still carries `Scope`, `Gates`, `Mode`, and `Clean`, which is the whole
  report: it ran, here is how wide it looked, it found nothing. A `LESSON:` line still follows if
  this run earned one — a clean result reached the wrong way is exactly what that line is for.
- **`NEXT:`** at most 3 imperative fragments (`fix token.ts:42 unit mismatch`), severity order,
  gate failures included. On `PASS` write `NEXT: nothing blocking.`
- **`LESSON:`**: at most one per run, and **omit it on most runs**. It appears only when this
  review hit something the skill genuinely did not cover — a pattern that nearly fooled you, a
  git behavior that made you misread the diff, a class of finding that turned out to be noise.
  It must be a rule about a *kind of situation*, phrased so it helps in a repo you have never
  seen. Anything naming this project, this file, or this framework is a fact, not a lesson, and
  a fact written into a global skill is a bug in every other project. `LESSONS.md` states the
  bar; if the line would not change how a future review comes out, leave it off.
- Rule lines are exactly 61 characters — keep the box square in the terminal.
