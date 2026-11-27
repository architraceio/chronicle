# 0016. Serverless API design

Date: 2026-04-29

## Status

Accepted

## Context

We're designing a new API for our platform that should be highly scalable and cost-effective. We want a design approach that makes our services highly available and resilient, but without the overhead of managing servers, while also allowing for rapid scaling.

## Decision

Use a serverless approach with AWS Lambda and API Gateway for the new API. We will design our functions to be stateless, idempotent, and to leverage the ecosystem of managed services.

## Consequences

The serverless approach allows us to scale automatically and pay only for actual usage, which reduces costs significantly. It also simplifies infrastructure operations. However, it may limit our ability to customize runtime behavior, increase cold start latency, and makes debugging more challenging.

## Alternatives Considered

- **Monolithic architecture on EC2**: Rejected because it's more complex to manage, scales less efficiently, and requires more operational overhead.
- **Kubernetes with ECS**: Rejected because while it's more flexible, the operational overhead was deemed too high for this project.
- **Traditional microservices with Docker**: Rejected because it's more complex and requires more infrastructure management.

## Rationale

The serverless approach aligns with our goal of minimal operational overhead while achieving scalability. It's a good fit for our workload which consists of many small, independent functions that can be scaled independently. The cost model matches our usage patterns, and we've had positive experiences with serverless in other parts of our platform.