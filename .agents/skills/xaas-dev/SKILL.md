---
name: xaas-dev
description: Development workflow for XAAS (Phoenix, Ash Framework, PostgreSQL, Docker, and Mix test suites).
---

# XAAS Development Workflow

Standard operating procedures for developing, testing, and running XAAS services.

---

## Core Commands

### Dependency Management & Setup
```bash
mix deps.get
mix compile
```

### Database Operations (PostgreSQL & Ash)
```bash
mix ecto.create
mix ecto.migrate
mix ash.codegen --name <migration_name>
mix ash.migrate
```

### Running Tests
```bash
# Run all unit and integration tests
mix test

# Run a specific test file
mix test test/xaas/some_test.exs

# Run with coverage report
mix test --cover
```

### Code Quality & Formatting
```bash
# Format Elixir code
mix format

# Run Credo linter (if installed)
mix credo --strict
```

### Local Server
```bash
mix phx.server
```
