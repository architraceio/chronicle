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