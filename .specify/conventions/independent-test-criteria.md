# Independent Test Criteria

A user story's **independent test** (referenced in `spec.md`) passes when all four criteria are met:

1. The feature can be deployed to production without any other in-progress story's code
2. The feature delivers measurable business value on its own
3. The feature has no hard runtime dependency on another P2 or P3 story's tasks
4. All acceptance scenarios for the story pass in isolation

## What "independent" allows

- Integration with shared foundational components (auth, DB, logging, shared utilities)
- Reliance on P1 stories that are already merged
- Use of third-party services and APIs

## What "independent" prohibits

- Blocking on a sibling story that is not yet complete
- Shared mutable state that only makes sense when another story is also deployed
- UI flows that require another story's screens to reach

## Grey areas

| Situation | Decision |
|---|---|
| Story B reads data that Story A writes | Only independent if Story A is already merged |
| Story B extends Story A's UI | Split into separate routes/pages; avoid shared component state |
| Stories share a migration | Extract migration to a foundational task; both stories depend on it |

## How to write the independent test in spec.md

Use a concrete, runnable description — not "the feature works":

> **Bad**: "The search feature is complete"
>
> **Good**: "Given a logged-in user, when they enter a query in the search bar and press Enter, results appear within 2 seconds and each result links to the correct detail page"
