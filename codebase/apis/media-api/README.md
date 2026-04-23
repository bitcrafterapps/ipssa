# Media API

This folder is reserved for the media and file lifecycle service.

Intended responsibilities:

- upload authorization
- proof-photo and asset metadata management
- signed URL generation for private media access
- media validation and storage rules
- retention and deletion workflows

Primary media classes:

- Coverage Dossier proof photos
- profile images and related assets
- future moderated attachments if needed

Relevant references:

- `../../../docs/architecture/IPSSA_Data_Schema.md`
- `../../../docs/architecture/IPSSA_SQL_First_Schema_Spec.md`
- `../../../docs/architecture/migrations/005_media_and_coverage.sql`
