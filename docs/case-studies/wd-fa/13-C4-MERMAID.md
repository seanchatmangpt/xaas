# C4 / Mermaid Architecture

## System context

```mermaid
flowchart LR
  ENG[FA Engineer]
  MGR[FA Manager]
  SRC[WD Evidence Sources]
  SYS[Semantic FA Operating System]
  QMS[Existing Quality / Work Systems]

  SRC --> SYS
  SYS --> ENG
  SYS --> MGR
  ENG --> SYS
  SYS --> QMS
```

## Containers

```mermaid
flowchart TB
  Sources[Source adapters]
  Graph[Canonical RDF / OCEL state]
  Rank[Candidate retrieval and ranking]
  Admit[Deterministic admission]
  Work[sJira work projection]
  Cap[SA2A capability plane]
  UI[Morning Brief / Case View]
  Receipt[Receipt + replay]
  MX[MachineExperience]

  Sources --> Graph
  Graph --> Rank
  Rank --> Admit
  Admit --> Work
  Admit --> UI
  Work --> Cap
  Cap --> Receipt
  Receipt --> MX
  MX --> Graph
```

## Authority boundary

```mermaid
flowchart LR
  O[OBSERVE]
  S[SELECT]
  C[CONSTRUCT]
  H{Engineer disposition}
  D[DO]
  R[Receipt]

  O --> S --> C --> H
  H -->|authorized| D --> R
  H -->|not authorized| C
```

The Friday demo proves through CONSTRUCT plus the human gate. Production DO is outside the evidence ceiling.

## STOGAF projection

```mermaid
flowchart TB
  OSTAR[O* canonical architecture state]
  SJ[sJira]
  SA[SA2A]
  MB[Morning Brief]
  BD[Board / assessment views]
  ASH[Ash/XaaS runtime]
  GEN[Generated runtime target]
  COURT[Chicago + Playwright + receipts]

  OSTAR --> SJ
  OSTAR --> SA
  OSTAR --> MB
  OSTAR --> BD
  OSTAR --> ASH
  OSTAR --> GEN
  ASH --> COURT
  GEN --> COURT
```
