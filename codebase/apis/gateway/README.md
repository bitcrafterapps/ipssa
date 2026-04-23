# Gateway API

This folder is reserved for the API gateway service.

Intended responsibilities:

- public API entry point for web and native clients
- request routing to backend services
- authentication enforcement at the edge
- claim propagation to downstream services
- rate limiting, request policies, and error normalization

Planned upstream services:

- `../auth-api/`
- `../core-api/`
- `../media-api/`

Relevant references:

- `../../../docs/planning/IPSSA_Implementation_Stories_Backlog.md`
- `../../../docs/architecture/IPSSA_AWS_Architecture.md`
