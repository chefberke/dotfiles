# Lessons

Rules this reviewer learned by running, and from the feedback its reports got. The reviewer
reads this file before every review and applies it. It is part of the skill, not a scratchpad.

## What belongs here

A lesson is a rule about a **kind of situation**, useful in any repo. It earns a line only if a
future review would come out different for having read it.

Good:

- A pattern that fooled the review once and will look the same next time.
- A tool behavior that produced a wrong reading of the diff.
- A rule derived from a finding being rejected or confirmed — what made it noise, or what made
  it worth reporting.

Not lessons, delete on sight:

- Anything naming a specific repo, file path, symbol, or framework version. Those are facts about
  one project, and this skill runs against all of them. "In the dashboard app, auth lives in
  `auth.ts`" is a fact; "a change to a session helper is worth checking against every route that
  reads the session" is a lesson.
- Anything that restates a rule the skill already has.
- Anything unactionable: "be more careful", "read the code closely".

## Format

One line each, imperative, followed by what happened that taught it.

```
- <the rule> — <what happened>
```

**Cap: 15 lessons.** At the cap, nothing is appended blindly: merge the new one into the closest
existing line, or drop the line that has earned the least, and say which. A lessons file that
only grows becomes a second skill nobody reads, and eventually it contradicts the first.

## Lessons

- Never pipe a gate command through `tail`/`head` — the pipeline returns the pager's exit status, so a failing gate reads as passing; capture the gate's own status or read the whole output.
- Attribute a failing gate before reporting it: check each flagged `file:line` against the diff hunks and against the base revision, and say in `GATE FAILURES` how many errors the change actually caused — a run reported a failing gate whose every error existed verbatim at the base on lines no hunk touched, which reads as "this change broke the build" and buries the real result.
- When a diff narrows what goes into a derived set, find every predicate compared against that set and check it got the same narrowing; treat a fix that removes rows from a pool as a change with its own blast radius, not as a safe tightening — a change excluded invalid rows from a "best so far" pool but left the "is this a new best" test comparing raw values, so an excluded run beat a pool it can never join, and because it never joins, the false claim re-fired on every later run instead of once. Bugs a fix *introduces* are the easiest to wave through, since the diff reads as strictly more correct than what it replaced.
- When the scope mixes committed and uncommitted work, read the range's commit messages as stated intent, then check the uncommitted hunks for deletions that undo something a commit in the same range deliberately added — a silent revert of a decision made minutes ago is indistinguishable from routine cleanup in the diff alone.
