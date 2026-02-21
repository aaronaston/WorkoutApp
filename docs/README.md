# Docs

This folder contains architecture and decision documentation.

## Structure
- architecture/ : system architecture references and artifacts
- decisions/ : architecture and design decisions (ADRs, DDRs, registries)
- features/ : feature-level requirements and technical design docs

## Architecture Approach

This project uses a combined meta-framework: Zachman for coverage, TOGAF for lifecycle and governance, and C4 for communication. The canonical description lives in `docs/architecture-framework.md`.

```
  +------------------------------+      +------------------------+      +-----------------------------+
  | Zachman Coverage             | ---> | TOGAF ADM Lifecycle     | ---> | C4 Communication Views      |
  | What / How / Where / Who     |      | Vision -> Change Mgmt   |      | Context -> Code             |
  | When / Why                   |      |                        |      |                             |
  +------------------------------+      +------------------------+      +-----------------------------+
                   ^                                                            |
                   |                                                            v
                   +---------------------- Project Artifacts -------------------+
```

Target artifact list for WorkoutApp (gaps vs current docs):
- C4 Context diagram (missing; only textual context in `docs/architecture/README.md`)
- C4 Container diagram (missing; only textual container view in `docs/architecture/README.md`)
- C4 Component diagram for workout session flow + data sync boundaries (missing; only textual components in `docs/architecture/README.md`)
- Core data model sketch for workouts, sessions, metrics, history (present; see `docs/architecture/README.md` and `docs/decisions/ddr/ddr-0003-core-data-models.md`)
- Primary flow diagram for workout tracking + sync timeline (missing; DDR-0004 is narrative only)
- Deployment view for device-only or device + backend topology (missing)
- ADR/DDR entry for each non-trivial architectural decision (in progress; see `docs/decisions/`)
