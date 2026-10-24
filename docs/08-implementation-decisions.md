# Implementation decisions

Status: recorded October 24, 2026, when implementation started. This file records what the first version actually does and why. The planning documents (01–07) are preserved unchanged as the history of the discussion; where they listed open questions, the answers chosen for the build are below.

## Resolved planning questions

| ID | Decision for the first version | Why |
| --- | --- | --- |
| D01 Stack | Flutter and Dart (the "flytter" in the source chat), one codebase for web, iOS and Android. Supabase for accounts, data and messaging in connected mode. | Confirmed by the team when implementation was requested. Supabase gives authentication, Postgres with row-level security, realtime and Edge Functions without running our own servers. |
| D02 Audience | Broad, with the demonstration story centered on a student seeking a mentor and an internship, plus local services. | Matches the strongest example in the planning notes and exercises role matching. |
| D03 Coverage | 20 Central Jersey towns as a fixed area list. No masjid partners are listed or implied. | Location matching needs known places; partnerships are not confirmed. |
| D04 Direction | Marketplace + natural-language search + transparent personalization (A + B + F in the brief). No organization hub. | As recommended; challenge-specific features are out of scope. |
| D05 Contact | Connection request (pending → accepted / declined / withdrawn). Accepting opens a private, persisted text conversation. | Delivers the team's requested platform messaging while keeping consent: nobody can message you until you accept. |
| D06 Minimum action | Both saving and requesting are implemented and are separate actions. | Saving alone does not make contact. |
| D07 LinkedIn | Optional LinkedIn URL only, validated as a `linkedin.com/in/...` link and shown only to directory viewers. Nothing is imported. Real import is deferred. | A URL field is not an import integration and is never labelled as one. |
| D08 Personalization | Explicit, explainable signals: saves, connection requests, "show less like this", and a small capped contribution from views. Can be turned off or reset. | Visible and testable without training a model. |
| D09 Taxonomy and roles | See "Listing model" below. | Matching needs unambiguous roles. |
| D10 Visibility | Opt-in member directory, off by default. Publishing a listing is a separate action with its own disclosure. | Consent preference from the team's answers. |
| D11 Storage | Demo mode: on-device JSON storage, no account. Connected mode: Supabase with row-level security. | Demo must run without keys; connected mode must enforce access on the server. |
| D12 Challenge | No challenge-specific features (prayer times, events, bookings). | Not in the current requirements. |

## Listing model

Every listing has three independent descriptors:

- **Type** — what kind of opportunity: `service`, `job`, `internship`, `mentorship`, `collaboration`, `volunteer`, `business`.
- **Direction** — the poster's role: `offer` (they make something available) or `request` (they are looking for something).
- **Category** — the subject area: education, technology, engineering, business, careers, creative, health, home, food, community, other.

Direction is always read together with type, and every combination has a plain label shown in the app:

| Type | Offer means | Request means |
| --- | --- | --- |
| Service | Offering a service | Looking for help |
| Job | Hiring | Looking for work |
| Internship | Internship opening | Seeking an internship |
| Mentorship | Offering mentorship | Looking for a mentor |
| Collaboration | Open to collaborate (available to join) | Seeking collaborators (for my project) |
| Volunteering | Volunteers needed (a role is available) | Wants to volunteer |
| Business | Local business (always an offer) | — |

**Businesses** are listings, not a separate entity: the owner publishes a `business` offer describing it. Someone looking for a business posts a service request instead. This keeps one model, one search and one set of permissions.

Profiles stay separate from listings. One member can offer tutoring, seek a website and post a job as three independent listings.

### Statuses

- Listings: `active` ↔ `paused`, and either → `closed`. Closed is final. Only active listings appear in discovery and accept requests. Owners can also delete a listing; requests and conversations keep its title.
- Requests: `pending` → `accepted` or `declined` (recipient only), or `withdrawn` (sender only). Nothing else.

These rules are implemented twice on purpose: in Dart (`ListingStatus.canTransitionTo`, `canTransitionRequest`) for the demo, and in the database (trigger `enforce_listing_rules`, functions `respond_to_connection_request` and `withdraw_connection_request`) for connected mode.

## Matching

Implemented in `lib/src/matching/` with no Flutter dependencies.

1. **Understanding text.** A deterministic parser recognises role phrases ("looking for", "I can", "hiring"), opportunity words ("mentor", "internship", "volunteers", "tutor"), a fixed vocabulary of about 70 skills and subjects, the 20 area names, and remote preferences. Seeking *people* who provide something ("interns", "volunteers") means you offer that opportunity. Self-description ("an engineering student") is context, never a skill. Nothing is inferred that was not written.
2. **Optional AI extraction** (connected mode, onboarding only): the `extract-profile` Edge Function asks Claude for structured suggestions. The app validates the shape, drops any value whose words do not appear in the member's answers, merges with the parser's output, and falls back to the parser on timeout (8 s), malformed output, refusal or any error. Search always uses the parser.
3. **Eligibility.** Inactive listings, your own listings, explicit filters (type, category, area within 15 miles or remote, remote only) and explicit wording ("remote only", "in person only") are hard constraints. "Show less like this" hides a listing from recommendations.
4. **Role compatibility.** For a goal, a listing of the same type must take the complementary role: seeking X is served by an offer of X, offering X by a request for X. Collaboration is reciprocal (complementary 1.0, same direction 0.7). A few related types score partially: offering mentorship ↔ a volunteer role (0.6), seeking a service ↔ a local business (0.7), seeking a business ↔ a service offer (0.6). When a request names goals, incompatible listings are excluded; a search without goals uses profile goals only to rank.
5. **Scoring** (weights are configurable and are an initial design, not validated performance):

| Factor | Weight | Value |
| --- | ---: | --- |
| Goal and listing type | 30% | Best compatibility over the member's goals (0–1) |
| Skills and interests | 25% | Stated subjects found in the listing (and consistent with its category or tags) blended 60/40 with profile skills and interests found |
| Description relevance | 25% | Weighted keyword coverage: title 1.0, tags 0.8, description 0.6, category 0.4 |
| Location | 10% | 1 − distance / 25 miles; remote listings 1.0 when remote is welcome, 0.7 otherwise |
| Recency | 5% | Half-life of 30 days |
| Your activity | 5% | 0.5 + 0.5·tanh(affinity / 2) |

6. **Missing signals.** When the member has not provided a signal (no area, no keywords, no activity), the factor is left out and the remaining weights are renormalized, so missing information neither helps nor hurts. When only the listing lacks it (no location), the factor counts as a neutral 0.5.
7. **Minimum relevance.** Search results need at least 0.25 overall and real evidence from the typed words: a goal subject, a keyword or a context term found in the listing. A request that names only a type ("looking for an internship") lists every compatible listing. Profile data can rank results but never admits them. Recommendations need at least 0.30. An empty list is a valid answer and is shown as such.
8. **Ties** break by newest, then by listing id, so results are deterministic.
9. **Explanations** are generated only from the signals above: the role match, the subjects or skills found, the matched search words, distance or remote availability, activity, and recency. Incidental mentions (a designer request that mentions "tutoring") count weakly and never produce a reason.

## Personalization

Each listing contributes once per signal: saved +1.0 (unsaving cancels it), connection request +1.5, "show less like this" −2.0, viewed +0.25 with views capped at +0.75 per category. Affinity combines the listing's category, half its type, and a quarter of matching tags. Accepting a connection request is never treated as accepting a job. Members can turn activity-based personalization off (events stop being recorded; the database refuses them too) or reset it (events are deleted). Settings shows what was learned and why.

## Privacy and trust

- Directory visibility is opt-in. When off, others see only your name on listings you publish and requests you send; you don't appear in member search; introductions to you are refused.
- Goals, personalization settings, saved listings, activity and conversations are private. In connected mode these live in tables only their owner (or the two participants) can read.
- Masjid affiliation is free text labelled "self-reported" everywhere it appears.
- All seed content is fictional and marked "Sample". There are no real people, job openings, partnerships, testimonials or verified providers.

## Two operating modes

| | Demo mode | Connected mode |
| --- | --- | --- |
| Data | Fictional seed data, stored as one JSON document in device storage (localStorage on the web) | Supabase Postgres |
| Identity | Switch between fictional members; create new local members | Email and password accounts |
| Authorization | Enforced in `DemoBackend` | Enforced by row-level security and security-definer functions |
| AI extraction | Never | Optional, behind `AI_EXTRACTION=true` and a server-side key |
| Reset | Restores sample data (demo storage only) | Not available |

Both modes implement the same `MarketplaceBackend` interface, so screens, state and matching are shared. Missing or broken backend configuration never blocks the demo.

## Architecture

- `lib/src/domain` — typed models and status rules.
- `lib/src/matching` — parser, extraction validation, ranking, preferences, member matching.
- `lib/src/data` — repository interfaces, the demo backend, the Supabase backend, seed data.
- `lib/src/state` — Riverpod providers and controllers (session, data, discovery, onboarding, outbox, actions).
- `lib/src/features` — screens; `lib/src/ui` — design system and shared widgets; `lib/src/routing` — go_router with an adaptive shell.

## Deferred

LinkedIn import or OAuth; payments; social graph and introductions through mutual connections; organization administration, verification and moderation tools; push notifications; read receipts; attachments in messages; server-side ranking for large datasets; a trained recommendation model.
