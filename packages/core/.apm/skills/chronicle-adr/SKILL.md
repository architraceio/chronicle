---
name: chronicle-adr
description: Record architectural or design decisions as ADR markdown files in this repository. Use when a design decision has been settled (including the user accepting your proposal, or you choosing a dependency, library or pattern while implementing), when a plan is approved or being implemented, when a Chronicle hook asks you to record decisions, or when the user asks to log a decision.
---

# Chronicle: record a decision as an ADR

You write the prose; the bundled script owns numbering, file names, templates and status changes. Never number or name ADR files yourself.

The script lives in this skill's folder: `scripts/chronicle-adr` (for example `.claude/skills/chronicle-adr/scripts/chronicle-adr` or `.agents/skills/chronicle-adr/scripts/chronicle-adr`). Run it with `bash <path> <command>` from the repository root.

## Procedure

1. **Split.** Identify each distinct decision in your input (a plan, the conversation, or the user's description). One ADR per decision. A plan usually holds several; pure task steps with no choice between alternatives are not decisions.
2. **Check for overlap.** Run `chronicle-adr list`. If an existing ADR covers the same subject:
   - same choice → skip it, it is already recorded;
   - different choice → the new ADR supersedes the old one (step 4 uses `--supersedes N`); tell the user.
3. **Choose the status.** `Accepted` when the plan was approved or the user agreed / it is being implemented; otherwise `Proposed`. Follow the status a Chronicle hook message gives you.
4. **Create the file.** `chronicle-adr new --title "<noun phrase>" --status <Accepted|Proposed> [--supersedes N] [--plan <archived plan path>]`. It prints the new file's path and fills in number, date and status.
5. **Fill in the sections** of the created file with Edit/Write. Keep every heading the template created. Replace each placeholder question with real content:
   - **Context**: the forces and constraints that made a decision necessary, taken from the conversation.
   - **Decision**: what was chosen, concretely (names, versions, scope).
   - **Consequences**: what becomes easier and what becomes harder.
   - **Alternatives / Why / Rationale** (where the template has them): name each rejected alternative and the reason it lost.
6. **If superseding**, run `chronicle-adr supersede N --by M`. This is the only allowed change to an existing ADR.
7. Run `chronicle-adr index` to refresh the decisions README, then report the new path(s) in one line each.

## Quality bar

- Title is a noun phrase: "Postgres for primary store", not "We will use Postgres".
- Active voice, concrete, short. No marketing.
- Never invent context, numbers or alternatives that are not in your input. If something essential is missing (usually the reason), ask the user one focused question instead of guessing.
- Never combine several decisions into one ADR.
- Never edit an existing ADR's content; supersede it instead.

## First run

If `.chronicle.json` does not exist, the script uses defaults (`docs/decisions`, Nygard template). To configure, run `chronicle-adr init [--template adr-nygard|adr-extended|adr-lightweight] [--dir docs/decisions]`.
