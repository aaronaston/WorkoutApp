# Architecture Meta-Framework (C4 + TOGAF + Zachman)

## Unifying idea
- Zachman = the coverage map (what you must address, across perspectives and interrogatives).
- TOGAF = the process + governance (how you move from vision to implementation).
- C4 = the communication format (how you visualize architecture at each depth).

## Structure (Three layers)

### Layer A: Coverage (Zachman)
Use the 6x6 matrix as a checklist to ensure nothing critical is missing.
Do not fill every cell; aim for sufficient coverage by scope and risk.

### Layer B: Process (TOGAF ADM)
Run the ADM phases as the backbone and iterate as needed.
Each phase maps to a subset of Zachman cells and produces artifacts in a consistent format.

### Layer C: Representation (C4)
Use C4 diagrams as the default visual output for systems and apps.
Extend with data, process, org, and motivation views where C4 does not cover the Zachman columns.

## Mapping

### Zachman rows -> TOGAF phases
- Planner/Owner -> Architecture Vision + Business Architecture
- Designer/Builder -> Information Systems Architecture + Technology Architecture
- Subcontractor/Operational -> Implementation Governance + Change Management

### Zachman columns -> C4 + extra views
- What (Data): C4 + ER/data models, data flow diagrams
- How (Function): C4 components + BPMN/process maps
- Where (Network): C4 container deployment + infra/network diagrams
- Who (People): Context diagrams + org charts/RACI
- When (Time): Event timelines, schedules, SLAs
- Why (Motivation): Vision, principles, OKRs, business case

## Deliverable model (example outputs by phase)

### Architecture Vision (TOGAF)
- Zachman: high-level Why/What/Who/Where
- C4: Context diagram
- Artifacts: vision, principles, stakeholder map

### Business Architecture
- Zachman: What/How/Who/Why at Owner level
- C4: optional (business context only)
- Artifacts: capability map, value streams, process models

### Information Systems Architecture
- Zachman: What/How at Designer level
- C4: Container + Component diagrams
- Artifacts: service catalog, data models, integration flows

### Technology Architecture
- Zachman: Where/How at Builder level
- C4: Deployment diagrams
- Artifacts: infra topology, standards, platform choices

### Opportunities & Solutions / Migration Planning
- Zachman: When/Why across rows
- C4: target vs current views
- Artifacts: roadmap, transition architectures

### Implementation Governance / Change Management
- Zachman: all columns at Subcontractor/Operational
- C4: code-level if needed
- Artifacts: compliance checks, ADRs, feedback loop

## Operating principle
- Zachman is your completeness lens.
- TOGAF is your lifecycle and decision gates.
- C4 is your shared language for system architecture.

This avoids diagram sprawl, keeps enterprise alignment, and makes architecture consumable by multiple audiences.

## Glossary

### C4 deployment diagram
A view that shows where C4 containers run in the real world (environments, nodes, networks) and how they connect at runtime. It focuses on deployment nodes/infrastructure and the mapping of containers onto those nodes, rather than component packaging inside a container.
