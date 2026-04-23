# Codebase

This folder contains the implementation surfaces of the IPSSA platform.

## Structure

- `apis/`
  Backend services such as the gateway, auth API, core API, and media API.

- `uis/`
  Client-facing user interfaces, including the web frontend and native mobile apps.

This folder exists to keep executable code and code-adjacent scaffolding separate from the planning and architecture documents in `docs/`.

## Key References

- `../docs/planning/IPSSA_Implementation_Stories_Backlog.md`
  Delivery sequencing and implementation scope across services and clients.

- `../docs/architecture/IPSSA_Data_Schema.md`
  Logical domain model for auth, core, and media.

- `../docs/architecture/IPSSA_SQL_First_Schema_Spec.md`
  PostgreSQL-oriented schema specification to guide backend persistence.

- `../docs/architecture/migrations/`
  Ordered SQL migration artifacts derived from the first-pass DDL.
