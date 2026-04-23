# Auth API

This folder is reserved for the authentication and authorization service.

Intended responsibilities:

- account creation and identity lifecycle
- login, logout, and session/token flows
- password reset and verification
- permission catalog and platform-global RBAC
- global role assignments and permission claims
- access control support for web, iOS, and Android clients

Primary downstream domain relationship:

- identity and global claims used by `../core-api/`
- chapter-scoped authorization remains Core-owned even when Auth issues gateway-trusted identity context

Relevant references:

- `../../../docs/architecture/IPSSA_Data_Schema.md`
- `../../../docs/architecture/IPSSA_SQL_First_Schema_Spec.md`
- `../../../docs/architecture/migrations/003_auth.sql`
