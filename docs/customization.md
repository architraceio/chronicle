# Customization

Chronicle is designed to be minimal but flexible. You can customize many aspects of how it works.

## ADR Templates

Chronicle ships with three ADR templates:

### Nygard Classic (default)

The classic ADR template by Michael Nygard, with title, date, status, context, decision, and consequences.

### Extended 

Extended template that adds YAML frontmatter and two extra sections — Alternatives Considered and Rationale.

### Lightweight

Four-section template: Title, Decision, Why, Trade-offs.

You can select a template during installation, or modify it in `.chronicle.json`:

```json
{
  "template": "adr-extended"
}
```

## Custom Templates

You can also use a custom template file by pointing to its path:

```json
{
  "template": "./my-custom-template.md"
}
```

## Keyword Customization

The automatic decision detection uses a keyword prefilter to reduce costs.

You can customize the keywords in `.chronicle.json`:

```json
{
  "stopHook": {
    "prefilterKeywords": ["feature request", "implementation approach", "technology choice"]
  }
}
```

## Customizing the Decision Logger Subagent

You can modify the `decision-logger` subagent prompt found in `.claude/agents/decision-logger.md` or `.opencode/agent/decision-logger.md` to change the quality standards or formatting.

## Decision Directory

You can customize where ADRs are stored in `.chronicle.json`:

```json
{
  "decisionsDir": "docs/architecture/decisions"
}
```

## Archive Plans

You can disable the archiving of raw plans by setting:

```json
{
  "archivePlans": false
}
```