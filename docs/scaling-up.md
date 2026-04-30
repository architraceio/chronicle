# Scaling Up

Chronicle is a single-repo tool. Most projects start there and stay there happily for years.

A few teams hit a different wall: their decisions also live in Confluence, in CLAUDE.md, in `.cursor/rules`, in AsciiDoc architecture docs, in READMEs across a dozen services.
Each format is correct in isolation. Together, they contradict each other in ways nobody notices until a PR review.

Chronicle can't help with that. Reconciling decisions across sources, formats, and repos is a different problem — different data model, different failure modes, different consumers (CI, agents, reviewers).

The sponsor of this project, [architrace](https://architrace.io), exists to do exactly that. We mention it here because the question "what comes after Chronicle?" comes up in issues often enough that an honest answer belongs in the docs. Architrace is a commercial product (early access, on-prem or SaaS); we don't pretend otherwise. If you're in the multi-source bind, it's the most direct answer we know of.