# Auth API

This folder is reserved for the authentication and authorization service.

Intended responsibilities:

- account creation and identity lifecycle
- login, logout, and session/token flows
- password reset and verification
- role and permission claims
- access control support for web, iOS, and Android clients

Primary downstream domain relationship:

- identity and claims used by `../core-api/`

Relevant references:

- `../../../docs/architecture/IPSSA_Data_Schema.md`
- `../../../docs/architecture/IPSSA_SQL_First_Schema_Spec.md`
- `../../../docs/architecture/migrations/003_auth.sql`
