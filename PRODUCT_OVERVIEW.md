# Product Overview

## Purpose
This document provides a root-level summary of the IPSSA platform: what it is, who it serves, and the major functionality planned across mobile, web, and backend services.

For deeper detail, see:

- `README.md`
- `docs/product/IPSSA_Mobile_App_Opportunity.md`
- `docs/planning/IPSSA_Implementation_Stories_Backlog.md`

---

## Platform Summary

The IPSSA platform is a **native-mobile-first member platform** for the Independent Pool & Spa Service Association.

Its goal is to transform IPSSA from a traditional membership organization into an active operational platform that members use to:

- protect their routes
- coordinate emergency, sick-time, and vacation coverage
- build trust and accountability across chapters
- improve member communication
- strengthen public-facing credibility
- train for required certification paths

The platform includes:

- native iOS app
- native Android app
- limited web frontend for marketing, BD, and selected member workflows
- backend APIs for auth, business logic, media, and routing

---

## Primary User Groups

### Members
Independent pool and spa service professionals using the platform for daily business operations, route protection, chapter participation, and learning.

### Chapter Officers
Presidents, Tech-4-Tech chairs, moderators, and other operational leaders who manage chapter workflows, communication, and dispute handling.

### Moderators / Admins
Users responsible for moderation, escalation, and operational oversight.

### Prospects / Homeowners
External users primarily interacting through the web presence, member profiles, and trust signals.

---

## Core Product Areas

## 1. CoverageMatch
The flagship capability of the platform.

CoverageMatch transforms IPSSA's Tech-4-Tech route coverage benefit into a structured, trackable, and reputation-aware coordination system.

### Core functionality
- sick-day coverage requests
- emergency coverage broadcasts
- planned vacation coverage workflows
- location-aware candidate ranking
- swipeable provider selection / match deck
- provider accept / decline flow
- shared coverage dossier after match confirmation
- proof-of-service tracking
- post-job mutual ratings
- gamified trust and reputation tiers

### Why it matters
- protects member revenue during illness, injury, and time off
- improves confidence in who covers a route
- creates auditability and accountability
- turns a legacy membership benefit into a real operational moat

---

## 2. Coverage Dossier and Proof of Service
Once a coverage match is accepted, the platform creates a shared operational record for the job.

### Core functionality
- route handoff details
- pool count and service notes
- customer contact protocol
- proof photo uploads
- timestamps
- optional location verification
- stop-level checklist completion
- exception reporting
- completion confirmation

### Why it matters
- gives members evidence that work was done
- reduces disputes
- protects customer relationships
- creates a shared system of record for coverage events

---

## 3. Ratings, Reputation, and Gamification
The platform includes a two-sided trust model so both the requesting company and the covering company can rate each other.

### Core functionality
- requester rates service quality, communication, and professionalism
- covering company rates handoff quality, communication, and fairness
- aggregate CoverageScore
- trust visibility thresholds
- provisional score states for new users
- tier badges and status progression
- anti-gaming and moderation review paths

### Why it matters
- creates visible trust before a match is accepted
- rewards reliable members
- improves matching quality over time
- gives the network stronger self-governance

---

## 4. Chapter Community
The platform includes structured chapter communication rather than relying on scattered texts and emails.

### Core functionality
- announcements
- tips and tricks
- customer issue discussions
- optional general chapter chat
- searchable thread history
- pinned content
- moderation and reporting
- de-identified posting guidance for sensitive customer issues

### Why it matters
- improves chapter communication
- makes tribal knowledge reusable
- reduces missed information
- gives officers better operational tools

---

## 5. Member Profiles and Trust Signals
Members can maintain richer business profiles that support both internal matching and external credibility.

### Core functionality
- business identity and experience
- certifications and exams completed
- service areas
- specialties
- contact methods
- trust/reputation surfaces from CoverageMatch
- future public-facing credibility signals

### Why it matters
- improves internal matching quality
- supports lead generation and professionalism
- makes IPSSA membership more legible to prospects and homeowners

---

## 6. Certification Prep Lab
The platform includes a gamified training area to help members prepare for water chemistry and related certification requirements.

### Core functionality
- short practice sessions
- immediate answer explanations
- review deck for missed questions
- spaced repetition
- points, streaks, and badges
- optional leaderboards
- curriculum-aligned content
- progress tracking across sessions

### Why it matters
- supports first-year compliance
- turns education into an active platform habit
- increases member value beyond route coverage alone

---

## 7. Chapter and Administrative Operations
The platform is not only member-facing; it also supports chapter-level administration and operational governance.

### Core functionality
- chapter membership and role handling
- officer-specific permissions
- moderation workflows
- rating dispute workflows
- emergency coverage actions by chapter leaders
- attendance and chapter communication tools

### Why it matters
- makes the system manageable at chapter scale
- supports trust, moderation, and escalation
- keeps governance aligned with IPSSA's real operating model

---

## 8. Web Frontend
The web layer is intentionally narrower than the native apps.

### Core functionality
- marketing pages
- product positioning
- BD/contact and lead capture
- limited member portal
- selected profile/trust visibility
- limited account and learning views where appropriate

### Why it matters
- supports growth and adoption
- gives the organization a public-facing presence
- avoids forcing operational mobile workflows into the browser unnecessarily

---

## Platform-Level Capabilities

These features span the whole platform:

- authentication and authorization
- role and claims management
- API gateway routing
- media uploads and storage lifecycle
- notifications and reminders
- audit logging
- moderation controls
- observability and operations
- scalable infrastructure and deployment

---

## Client Surfaces

### Native mobile apps
Primary place where members will use:

- CoverageMatch
- coverage execution
- Chapter Community
- ratings
- Prep Lab
- profile and chapter workflows

### Web frontend
Primarily used for:

- marketing
- BD
- limited member portal functions

---

## Backend Service Surfaces

### Gateway
- API entry point
- request routing
- auth enforcement
- edge policies

### Auth API
- account lifecycle
- sessions/tokens
- verification
- password reset
- roles and claims

### Core API
- chapters
- profiles
- CoverageMatch
- ratings
- community
- Prep Lab
- notification orchestration

### Media API
- upload authorization
- proof photo handling
- signed access URLs
- retention and deletion workflows

---

## Product Direction

The platform is designed to move IPSSA from a passive association model toward a **network-powered operations platform** where:

- trust is measurable
- route coverage is operationalized
- education becomes active and sticky
- chapter coordination improves
- member professionalism becomes more visible

In practical terms, the platform is meant to help members:

- make more money
- protect their routes
- maintain customer relationships
- participate more effectively in chapter life
- build stronger credibility through the network

---

## Summary

At a high level, this platform combines:

- route protection
- operational coordination
- reputation systems
- chapter communication
- learning and certification support
- public credibility and lead support

into one member platform centered on IPSSA's real differentiator: **Tech-4-Tech support made reliable, trackable, and useful every week instead of only during emergencies.**
