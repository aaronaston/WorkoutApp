# Docs

This folder contains architecture and decision documentation.

## Structure
- architecture/ : system architecture references and artifacts
- decisions/ : architecture and design decisions (ADRs, DDRs, registries)
- features/ : feature-level requirements and technical design docs

## Architecture Approach

This project uses a combined meta-framework: Zachman for coverage, TOGAF for lifecycle and governance, and C4 for communication. The canonical description lives in `docs/architecture-framework.md`.

```text
  +------------------------------+      +------------------------+      +-----------------------------+
  | Zachman Coverage             | ---> | TOGAF ADM Lifecycle     | ---> | C4 Communication Views      |
  | What / How / Where / Who     |      | Vision -> Change Mgmt   |      | Context -> Code             |
  | When / Why                   |      |                        |      |                             |
  +------------------------------+      +------------------------+      +-----------------------------+
                   ^                                                            |
                   |                                                            v
                   +---------------------- Project Artifacts -------------------+
```

Target artifact list for WorkoutApp:
- C4 Context diagram (missing; only textual context in `docs/architecture/README.md`)
- C4 Container diagram (missing; only textual container view in `docs/architecture/README.md`)
- C4 Component diagram for workout session flow + data sync boundaries (present; see `docs/architecture/c4-component-workout-session-sync-boundaries.md`)
- Core data model sketch for workouts, sessions, metrics, history (present; see `docs/architecture/README.md` and `docs/decisions/ddr/ddr-0003-core-data-models.md`)
- Primary flow diagram for workout tracking + sync timeline (present; see `docs/architecture/primary-flow-workout-tracking-sync-timeline.md`)
- Deployment view for device-only or device + backend topology (present; see `docs/architecture/deployment-view-device-and-backend-topology.md`)
- ADR/DDR entry for each non-trivial architectural decision (in progress; see `docs/decisions/`)
