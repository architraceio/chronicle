# 15. Use React for frontend

Date: 2026-04-28

## Status

Accepted

## Context

Our team needs to choose a frontend framework for the new web application. We want to ensure we're selecting something with strong community support, good documentation, and good tooling. We've had experience with both React and Vue in past projects.

## Decision

Use React with TypeScript for the new web application. We will leverage the existing team's expertise and the extensive ecosystem of libraries, tools, and documentation available for React.

## Consequences

Using React means we can leverage the large, active community and vast ecosystem of libraries. The existing team expertise reduces the learning curve and onboarding time. However, React has a steep learning curve for developers new to the ecosystem, and the fast-paced evolution of the framework requires constant attention to staying up to date.

## Alternatives Considered

- **Vue.js**: Rejected because the team had less experience with it, and the ecosystem was smaller than React's
- **Angular**: Rejected due to complexity and the significant learning curve for our team
- **Svelte**: Rejected because while it's gaining popularity, our team preferred the established patterns in React

## Rationale

React's popularity, extensive documentation, and the vast selection of libraries and tools make it a pragmatic choice for our team. The existing familiarity allows us to be productive from day one and reduces the risk of knowledge gaps that might slow development. The ecosystem of tooling supports our development and testing needs well.