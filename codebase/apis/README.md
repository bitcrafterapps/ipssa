# APIs

This folder is the container for the backend services of the IPSSA platform.

Path:

- `codebase/apis/`

Current service stubs:

- `gateway/`
  API gateway / edge routing / auth enforcement

- `auth-api/`
  Authentication and authorization service

- `core-api/`
  Core business domains such as chapters, profiles, CoverageMatch, ratings, community, and Prep Lab

- `media-api/`
  Uploads, proof photos, media metadata, and media lifecycle operations

Each service directory currently contains a lightweight `README.md` describing its intended responsibility.

This folder is intentionally lightweight for now and serves as the backend container until implementation begins.
