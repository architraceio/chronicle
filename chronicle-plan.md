# Chronicle — Project Plan

> **Decisions that don't disappear.**
>
> Chronicle is an open-source companion for AI coding agents that captures architectural and design decisions as ADR markdown files in your repository. Local-first, no account, no telemetry. Sponsored by [architrace](https://architrace.io).

---

## 1. What Chronicle Is

A small set of markdown files plus one bash installer. It teaches Claude Code (full auto-capture) and OpenCode (manual capture via slash command) to write ADRs into a folder you choose. Nothing more.

The technical core is intentionally minimal:

- A `decision-logger` subagent, defined in markdown, that knows how to write a properly structured ADR.
- For Claude Code: two shell hook scripts that fire on plan acceptance and at turn end, both delegating to the subagent.
- For OpenCode: a `/log-decision` slash command and an AGENTS.md instruction that nudges the primary agent to invoke the subagent when relevant.
- Three ADR templates the user picks from at install time.
- One install script that asks where ADRs should live, which agent(s) to install for, and copies the right files into `.claude/` and/or `.opencode/`.

No CLI binary. No Node.js. No Go. No MCP server. No telemetry. No "doctor" or "status" commands. The project is *content*, not software.

## 2. Strategic Frame

Chronicle is an OSS project sponsored by architrace. It stands on its own as a useful tool. Its strategic role for architrace is **content-driven demand generation** — getting the architrace name in front of qualified senior engineers via a free, high-quality tool that earns category trust over time.

Two architrace placements, no more:

1. **Sponsor block in the README.** Bottom of fold, single block.
2. **An editorial mention in `docs/scaling-up.md`** — an honest "what comes after Chronicle" page that names architrace because that's the honest answer.

Everywhere else, Chronicle stands alone. No mentions in install output, no CTAs in command output, no branded footer in generated ADRs by default, no telemetry. The constraint that makes the sponsorship credible is the constraint that gives the brand mention weight when it does appear.

Chronicle does not detect competing decision sources, reconcile across files, gate CI, serve decisions to agents across repos, or do anything else that overlaps with the architrace platform. That separation is clean by design.

## 3. Naming

- **Project:** Chronicle
- **GitHub:** `github.com/architrace/chronicle`
- **Microsite:** `chronicle.architrace.io` — hosts `install.sh` and a small landing page

The architrace organization namespace makes the sponsorship visible without putting branding inside the tool. Users who notice the URL see "architrace"; users who just use the tool see "Chronicle."

## 4. Repository Layout

```
chronicle/
├── README.md
├── LICENSE                       # MIT
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── SECURITY.md
│
├── install.sh                    # POSIX, the only executable
├── uninstall.sh
│
├── claude-code/                  # Claude Code adapter
│   ├── agents/
│   │   └── decision-logger.md
│   ├── hooks/
│   │   ├── chronicle-save-plan.sh
│   │   └── chronicle-prefilter.sh
│   ├── commands/
│   │   └── log-decision.md
│   ├── settings.snippet.json     # merged into .claude/settings.json
│   └── claude-md-snippet.md      # appended to CLAUDE.md
│
├── opencode/                     # OpenCode adapter (markdown only)
│   ├── agent/
│   │   └── decision-logger.md
│   ├── command/
│   │   └── log-decision.md
│   └── agents-md-snippet.md      # appended to AGENTS.md
│
├── templates/                    # shared ADR templates
│   ├── adr-nygard.md             # default
│   ├── adr-extended.md           # frontmatter + alternatives + rationale
│   └── adr-lightweight.md        # 4-section minimum
│
├── docs/
│   ├── getting-started.md
│   ├── how-it-works.md
│   ├── customization.md
│   ├── claude-code.md            # what the Claude Code adapter does
│   ├── opencode.md               # what the OpenCode adapter does
│   ├── why-adrs.md               # SEO content
│   └── scaling-up.md             # the architrace editorial mention
│
├── examples/
│   └── decisions/                # 6-8 realistic example ADRs
│
└── .github/
    ├── workflows/
    │   ├── shellcheck.yml
    │   └── release.yml
    ├── ISSUE_TEMPLATE/
    ├── PULL_REQUEST_TEMPLATE.md
    └── FUNDING.yml
```

That's the whole project. The only files that contain logic are `install.sh`, `uninstall.sh`, and the two shell hooks under `claude-code/hooks/`. Everything else is markdown or JSON snippets.

## 5. Adapter Capabilities

Honest disclosure of the asymmetry: the two adapters don't capture decisions identically. The README and docs say so plainly.

| Capability | Claude Code | OpenCode |
|---|---|---|
| Manual capture via slash command | `/log-decision` | `/log-decision` |
| Plan acceptance auto-capture | Yes — `PostToolUse` hook on `ExitPlanMode` | No — user invokes `/log-decision` after switching from plan to build |
| Mid-session decision auto-capture | Yes — `Stop` hook with regex prefilter + LLM judge | No — AGENTS.md instructs the primary agent to suggest `/log-decision`; user decides |
| Subagent that writes the ADR | Yes (`.claude/agents/decision-logger.md`) | Yes (`.opencode/agent/decision-logger.md`) |
| Persistent delegation rule | CLAUDE.md snippet | AGENTS.md snippet |

The reason for the gap is technical, not strategic: OpenCode plugins are TypeScript, not shell, and there's no built-in prompt-type hook for sending turn content to a fast LLM judge. Adding that capability would put code back into the project, which is exactly the scope creep we removed earlier. If demand shows up, a small TypeScript plugin can be a v0.2 addition; for v0.1, OpenCode users get manual capture only and that's communicated up front.

## 6. ADR Templates

Three templates ship with Chronicle. Default is **Nygard classic** because that's what the broadest audience knows and trusts.

### 6.1 `adr-nygard.md` (default)

```markdown
# {number}. {title}

Date: {ISO date}

## Status

{Proposed | Accepted | Deprecated | Superseded by ADR-XXXX}

## Context

What is the issue we're seeing that motivates this decision?

## Decision

What is the change we're actually proposing or doing?

## Consequences

What becomes easier or harder because of this change?
```

### 6.2 `adr-extended.md`

Adds YAML frontmatter (id, status, date, supersedes, links, tags) and two extra sections — Alternatives Considered and Rationale. For teams that want richer metadata.

### 6.3 `adr-lightweight.md`

Four sections: Title, Decision, Why, Trade-offs. For teams that want a paper trail without ceremony.

Template selection is stored in `.chronicle.json` at the project root. Custom templates are supported by pointing `template` at any file path.

## 7. Component Specifications

### 7.1 `decision-logger` subagent (shared logic, two file copies)

The subagent file is essentially identical between adapters; only the frontmatter differs slightly to match each agent's conventions. Both versions instruct:

```markdown
---
name: decision-logger
description: Writes architectural decisions as ADR markdown in the project's configured decisions directory. Invoke whenever a non-trivial design choice is finalized, a plan is accepted, or the user explicitly requests decision logging.
tools: Read, Write, Glob, Bash
---
You are an ADR specialist. Write a single ADR file to the configured decisions directory using the configured template.

Procedure:
1. Read `.chronicle.json` to find `decisionsDir` (default: `docs/decisions/`) and `template` (default: `adr-nygard`).
2. Read existing ADRs via Glob to determine the next 4-digit number.
3. Read the template file from the chronicle install location (provided in `.chronicle.json` as `installDir`).
4. Fill in the fields. The "why" must answer not just what was chosen but why the alternatives were rejected.
5. Write to `<decisionsDir>/<NNNN>-<kebab-title>.md`. Never overwrite an existing file.
6. Print the new ADR's path on completion.

Quality bar:
- Title is a noun phrase, not a sentence ("Postgres for primary store", not "We will use Postgres").
- Active voice.
- Status is `Accepted` when invoked from `ExitPlanMode`; `Proposed` when invoked from a Stop-hook safety net unless the input clearly indicates the decision is final.
- At least one rejected alternative is named in the extended/lightweight templates.

Never:
- Invent context that wasn't in the input.
- Combine multiple decisions into one ADR.
- Modify existing ADRs (use a new ADR with `Superseded by` for that).
```

### 7.2 `claude-code/hooks/chronicle-save-plan.sh`

POSIX shell. Receives JSON on stdin from the `PostToolUse` hook. Verifies `tool_name == "ExitPlanMode"`, archives the raw plan, and emits a structured stdout JSON instructing Claude to invoke the `decision-logger` subagent.

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
[ "$TOOL" = "ExitPlanMode" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_DIR/.chronicle.json"
[ -f "$CONFIG" ] || { echo "{}"; exit 0; }

DECISIONS_DIR=$(jq -r '.decisionsDir // "docs/decisions"' "$CONFIG")
ARCHIVE_PLANS=$(jq -r '.archivePlans // true' "$CONFIG")

PLAN=$(echo "$INPUT" | jq -r '.tool_response.plan // empty')
[ -z "$PLAN" ] && exit 0

if [ "$ARCHIVE_PLANS" = "true" ]; then
  PLAN_DIR="$PROJECT_DIR/$DECISIONS_DIR/_plans"
  mkdir -p "$PLAN_DIR"
  TS=$(date -u +"%Y%m%dT%H%M%SZ")
  SLUG=$(echo "$PLAN" | head -1 | sed 's/[^a-zA-Z0-9]/-/g' | tr -s '-' | cut -c1-50 | tr A-Z a-z)
  echo "$PLAN" > "$PLAN_DIR/${TS}-${SLUG:-plan}.md"
fi

jq -n --arg plan "$PLAN" '{
  "decision": "block",
  "reason": "A plan was accepted. Invoke the decision-logger subagent with the following plan content to produce a structured ADR before continuing:\n\n\($plan)"
}'
```

### 7.3 `claude-code/hooks/chronicle-prefilter.sh`

Cheap regex pre-filter for the `Stop` hook. Greps the turn transcript for decision keywords. Always exits 0 (non-blocking). On a match, emits an `additionalContext` JSON object that nudges the LLM judge that follows it in the hook chain. The default keyword set is editable in `.chronicle.json`:

- "let's go with", "we'll use", "we'll go with", "decided to", "going to use"
- "the decision is", "I'll choose", "chosen approach", "trade-off"
- "instead of", "rather than", "as opposed to" (paired with "use" or "go")
- "ADR", "architectural decision"

### 7.4 `claude-code/settings.snippet.json` (merged into `.claude/settings.json`)

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "ExitPlanMode",
      "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/chronicle-save-plan.sh" }
      ]
    }],
    "Stop": [{
      "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/chronicle-prefilter.sh" },
        {
          "type": "prompt",
          "prompt": "Transcript: $ARGUMENTS\n\nDid the assistant finalize a non-trivial architectural, design, or trade-off decision in this turn that is not already recorded in docs/decisions/? If yes, return {\"decision\":\"block\",\"reason\":\"Invoke the decision-logger subagent for: <one-line summary>\"}. Otherwise return {\"decision\":\"approve\"}."
        }
      ]
    }]
  }
}
```

The install script merges this into the user's existing `.claude/settings.json` with `jq`, preserving every existing key. Conflicts produce a diff and a prompt.

### 7.5 `claude-code/commands/log-decision.md` and `opencode/command/log-decision.md`

```markdown
---
description: Manually capture an architectural decision as an ADR.
---
Invoke the `decision-logger` subagent. Pass it the decision the user wants to record, including: the context that led to it, the choice made, alternatives considered, and the rationale.

If the user hasn't provided enough information for a complete ADR, ask one focused clarifying question before invoking the subagent.
```

The OpenCode version may need minor frontmatter adjustments to match its slash-command schema; the body is identical.

### 7.6 `claude-code/claude-md-snippet.md` and `opencode/agents-md-snippet.md`

Both append a fenced block with `<!-- chronicle:start --> ... <!-- chronicle:end -->` markers so `uninstall.sh` can remove cleanly.

```markdown
<!-- chronicle:start -->
## Decision logging

When you finalize a non-trivial design, architectural, or trade-off decision —
or when a plan is accepted from plan mode — delegate to the `decision-logger`
subagent with:

- the context that motivated the decision
- the chosen approach
- alternatives considered and why they were rejected
- the rationale (the "why")

Trivial choices (variable names, formatting, single-file refactors) do not need
ADRs. When in doubt, log it; superseding is cheap, lost context is not.
<!-- chronicle:end -->
```

## 8. Configuration

`.chronicle.json` at the project root, written by the installer.

```jsonc
{
  "version": 1,
  "decisionsDir": "docs/decisions",
  "template": "adr-nygard",              // adr-extended | adr-lightweight | <path>
  "archivePlans": true,                  // archive raw accepted plans (Claude Code only)
  "agents": ["claude-code", "opencode"], // which adapters were installed
  "stopHook": {
    "enabled": true,                     // Claude Code only
    "prefilterKeywords": [],             // empty = use defaults
    "judgeModel": "claude-haiku-4-5-20251001"
  },
  "installDir": "/path/to/chronicle"     // where templates and subagent definitions live
}
```

User-global config at `~/.chronicle/config.json` (lower precedence; project wins).

## 9. Install Script

### 9.1 Invocation

```bash
curl -fsSL https://chronicle.architrace.io/install.sh | bash
```

The script is also published as the canonical `install.sh` at the repo root, with sha256 sums published per release. POSIX-compliant (`bash`, `jq`, standard utilities only). Refuses to run as root. Verifies all download checksums against published sums.

### 9.2 Interactive flow

```
> Chronicle installer
> 
> Project: /home/you/projects/cool-app
> 
> ? Which agent(s) do you use? (detected: .claude/ exists)
>   ▸ Claude Code
>     OpenCode
>     Both
> 
> ? Where should ADRs be stored? (relative to project root)
>   [docs/decisions/]
> 
> ? Which ADR template?
>   ▸ Nygard classic (recommended)
>     extended (adds frontmatter + alternatives + rationale)
>     lightweight (4 sections only)
> 
> ? Enable the auto-capture Stop hook (Claude Code)?
>   This adds an LLM judge that runs at the end of each Claude turn to
>   detect undocumented decisions. Cost: ~$0.001 per turn (Haiku),
>   reduced ~10x by the keyword prefilter.
>   ▸ Yes (recommended)
>     No, just the plan-mode hook
> 
> ? Add the delegation rule to CLAUDE.md / AGENTS.md?
>   ▸ Yes
>     Show me the rule first
>     No
> 
> Installing for Claude Code:
>   ✓ Wrote .chronicle.json
>   ✓ Created docs/decisions/
>   ✓ Copied .claude/agents/decision-logger.md
>   ✓ Copied .claude/hooks/chronicle-{save-plan,prefilter}.sh
>   ✓ Merged .claude/settings.json (existing hooks preserved)
>   ✓ Added delegation rule to CLAUDE.md
> 
> Done. Try it:
>   1. Run `claude` and use plan mode (Shift+Tab Shift+Tab)
>   2. Accept a plan — your first ADR will appear in docs/decisions/
>   3. Or run /log-decision to capture a decision manually
> 
> Docs: https://chronicle.architrace.io/docs
```

### 9.3 Critical install behaviors

- **Detects existing setups.** Looks for `.claude/` and `.opencode/` and pre-selects the right adapter.
- **Never overwrites** an existing `.claude/settings.json`. The merger preserves all existing hooks. Conflicts → diff + prompt.
- **Never overwrites** existing CLAUDE.md or AGENTS.md. Appends a fenced block with markers for clean uninstall.
- **Idempotent.** Running twice is safe.
- **`--dry-run` flag.** Prints every change without applying.
- **Non-interactive flags** for CI/automation: `--agent claude-code`, `--decisions-dir docs/adr`, `--template adr-extended`, `--no-stop-hook`.
- **Refuses to overwrite.** If files conflict and the user declines the merge, the installer aborts cleanly without partial state.

### 9.4 Distribution

| Channel | Status at launch |
|---|---|
| `curl install.sh` | Day 1 — `chronicle.architrace.io/install.sh` |
| GitHub Releases | Day 1 — signed tarballs with sha256 |
| Homebrew tap | Post-launch — installs `install.sh` and runs it |

No npm, no Cargo, no Go releases. There's nothing to compile.

## 10. Documentation

| Page | Purpose | Architrace mention? |
|---|---|---|
| `getting-started.md` | Install in 60s, first ADR in 3 min | No |
| `how-it-works.md` | The hooks, the subagent, the templates | No |
| `customization.md` | Custom templates, custom keywords, custom subagent prompt | No |
| `claude-code.md` | What the Claude Code adapter does, including limitations | No |
| `opencode.md` | What the OpenCode adapter does and why capture is manual | No |
| `why-adrs.md` | Educational content; SEO target | No |
| `scaling-up.md` | When Chronicle isn't enough — the editorial architrace mention | **Yes** |

The architrace mention lives on exactly one page. Everywhere else, Chronicle stands alone.

### 10.1 Sponsor block (README, bottom of fold)

```markdown
---

### Sponsored by architrace

Chronicle is built and maintained with support from [architrace](https://architrace.io) —
a platform that reconciles ADRs, Confluence pages, READMEs, and AI agent rule files into
one source of truth across an organization. If your decisions live in more places than
one repo can hold, architrace is worth a look.

Architrace's sponsorship keeps Chronicle free, open-source, and unbranded.

---
```

### 10.2 `scaling-up.md` editorial mention

```markdown
# Scaling up

Chronicle is a single-repo tool. Most projects start there and stay there happily for years.

A few teams hit a different wall: their decisions also live in Confluence, in CLAUDE.md,
in `.cursor/rules`, in AsciiDoc architecture docs, in READMEs across a dozen services.
Each format is correct in isolation. Together, they contradict each other in ways nobody
notices until a PR review.

Chronicle can't help with that. Reconciling decisions across sources, formats, and repos
is a different problem — different data model, different failure modes, different
consumers (CI, agents, reviewers).

The sponsor of this project, [architrace](https://architrace.io), exists to do exactly
that. We mention it here because the question "what comes after Chronicle?" comes up in
issues often enough that an honest answer belongs in the docs. Architrace is a commercial
product (early access, on-prem or SaaS); we don't pretend otherwise. If you're in the
multi-source bind, it's the most direct answer we know of.
```

## 11. Launch Plan

### 11.1 Pre-launch (3 weeks)

- README polished — install command above the fold, value prop in two sentences, demo GIF showing plan acceptance → ADR appearing.
- Install flow tested on macOS, Linux, WSL, GitHub Codespaces.
- 6-8 realistic example ADRs in `examples/decisions/`.
- 5 design partners using Chronicle in private beta. Quotes secured for the README.
- Submitted to awesome-claude-code and awesome-opencode lists, scheduled for launch day.
- Microsite live at `chronicle.architrace.io`.

### 11.2 Launch week

- **Day 1:** Show HN — angle is "Chronicle: capture architectural decisions while you code with Claude Code or OpenCode." Sponsorship disclosed in the post.
- **Day 2:** r/ExperiencedDevs, r/programming.
- **Day 2:** Twitter/X + LinkedIn from architrace, framed as "we sponsored an OSS tool we wanted to exist."
- **Day 3:** Anthropic Discord, OpenCode Discord, dev tooling Slacks.
- **Day 5:** Long-form blog post on architrace.io: "Why we sponsor Chronicle." Earnest, technical, not salesy.
- **Day 7:** dev.to / Hashnode cross-post: "Building a turn-end LLM judge with Claude Code hooks." Authored under an individual name.

### 11.3 Post-launch metrics (90 days)

| Metric | 30-day | 90-day |
|---|---|---|
| GitHub stars | 300 | 1,500 |
| `install.sh` requests (proxy for installs) | 600 | 4,000 |
| Unique organizations (aggregate from web logs) | 60 | 350 |
| `docs/scaling-up.md` page views | — | 2,000+ |
| architrace.io contact form fills attributed to Chronicle | 5 | 40 |

The 90-day conversion target is intentionally modest. Chronicle's job is to put the architrace name in front of qualified senior engineers consistently and earn category trust over months. Direct conversions are a happy second-order effect.

## 12. Roadmap

### v0.1 — Launch
- Claude Code adapter (full hooks)
- OpenCode adapter (markdown only — manual capture via slash command)
- Three ADR templates
- Install script for both adapters
- Documentation set

### v0.2 — Quality of life
- `.chronicle.json` keyword customization properly documented
- Better numbering for parallel branches (collision-resistant on merge)
- Homebrew tap

### v0.3 — Demand-driven additions
Decisions deferred to actual signal:
- OpenCode TypeScript plugin for deterministic capture (only if requested)
- Cursor adapter (only if requested)
- Codex CLI adapter (only if requested)
- `chronicle import` for existing `adr-tools`-format ADRs

The default is "we don't add it." Each addition needs a concrete user asking for it.

## 13. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Anthropic ships built-in ADR feature | Pivot Chronicle to add value on top (templates, OpenCode, custom prompts) rather than compete |
| Stop-hook costs surprise users | Prefilter cuts ~90% of turns; explicit cost note at install; opt-out available |
| Generated ADRs are low-quality | Strong subagent prompt; quality bar enforced; honest "review before committing" line in install output |
| Hook system changes break the integration | Pin against documented hook events; test matrix covers latest 3 minor versions of Claude Code and OpenCode |
| OpenCode users feel second-class | Documentation is upfront about the asymmetry; v0.3 plugin path exists if demand shows up |
| `ExitPlanMode` clear-context bug means some plans go uncaptured | Document the limitation; suggest non-clear-context accept by default |
| Users feel sponsorship is a pretext | Be aggressive about *not* mentioning architrace — the constraint signals trust |

## 14. License & Governance

- **License:** MIT.
- **CLA:** none. DCO sign-off in PR template.
- **Maintainer model:** architrace team for v0.x. Open contributor model from v1.
- **FUNDING.yml:** points to architrace as the organizational funder.
- **Telemetry:** none. Public commitment in README.

## 15. Open Questions for You

1. **Microsite scope.** `chronicle.architrace.io` for `install.sh` and a landing page — confirm this is what you want, or prefer a fully separate domain (e.g., `chronicle-md.com`) with a sponsor backlink?
2. **Sponsor block wording.** §10.1 has a draft. Anything to change?
3. **`scaling-up.md` voice.** §10.2 has a draft. Comfortable with the honesty, or want it softer/sharper?
4. **Launch story framing.** "Chronicle: an OSS tool sponsored by architrace" — confirm this is the framing rather than "architrace launches Chronicle."
5. **OpenCode plugin in v0.1?** Currently scoped out (manual capture only). If the OpenCode launch story matters more than scope discipline, a small TypeScript plugin can come back into v0.1 — your call.
6. **Footer comment in generated ADRs.** Currently scoped out entirely (not even opt-in). If you want the option available, it can be opt-in default-off.

## Appendix A — Example ADR

```markdown
# 14. Postgres for primary store

Date: 2026-04-27

## Status

Accepted

## Context

The application needs a primary transactional store for user accounts, sessions,
and order data. Expected scale at 12 months is ~10M rows in the largest table
with mixed read/write workload and strong consistency requirements for the
order pipeline. The team has prior operational experience with both Postgres
and MongoDB.

## Decision

Use Postgres 16 as the primary transactional store. Schema migrations managed
via dbmate. Connection pooling via pgbouncer in transaction mode.

## Consequences

ACID guarantees match the order pipeline's requirements; rich query language;
mature operational tooling; team familiarity reduces ramp.

Schema migrations require care under load. Horizontal write scaling requires
future work (Citus or app-level sharding) if growth exceeds projections.

A follow-on ADR will be needed for read-replica strategy once read load
justifies it.

## Alternatives Considered

- **MongoDB**: Rejected because the order pipeline's consistency model would
  require multi-document transactions throughout, eroding MongoDB's main
  ergonomic advantage while keeping its operational cost.
- **DynamoDB**: Rejected due to query-pattern lock-in and lack of ad-hoc
  analytical access for the analytics team.
- **SQLite + Litestream**: Viable for a smaller product but write throughput
  would be a ceiling within 6 months at projected scale.

## Rationale

Postgres' consistency model maps directly onto the order pipeline's
requirements without architectural workarounds, and the team's existing
operational fluency reduces both initial and ongoing cost. MongoDB's
ergonomic advantages disappear under multi-document transaction requirements;
DynamoDB's cost model and query rigidity work against the analytics use case.
Postgres is the only candidate where no significant constraint is in tension
with the actual workload.
```

---

*Chronicle is sponsored by [architrace](https://architrace.io).*