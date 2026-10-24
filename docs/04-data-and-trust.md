# Data and trust

Status: proposed conceptual model only. No database, authentication, messaging, imports, verification, demo records, or integrations have been created.

The team explicitly requested manual profiles plus LinkedIn import, an opt-in directory, and platform messaging. The [prior assistant's guide](00-source-chat.md#turn-5-assistant) recommends smaller substitutes for the hackathon. Those recommendations do not supersede the [team's submitted answers](00-source-chat.md#turn-2-user).

## Core model proposed in the chat

Keep people separate from individual offers and needs. One accountant might offer tax preparation, seek a website, and post a job for an assistant; those should be separate listings linked to the same person.

### Profile

| Proposed fields | Purpose |
| --- | --- |
| `id`, `display_name`, `short_bio` | Identify and introduce the person. |
| `skills[]`, `interests[]` | Describe confirmed skills and stated interests. |
| `offering_summary`, `seeking_summary` | Distinguish what the person can provide from what they need. |
| `city_or_area`, `preferred_categories[]` | Support discovery and preferences. |
| `community_affiliations[]` | Optional masjid or organization affiliation. |
| `linkedin_url` | Optional professional reference in the assistant's reduced-scope proposal. |
| `visibility`, `created_at` | Represent visibility choice and creation time. Exact visibility values remain undecided. |

### Marketplace listing

| Proposed fields | Purpose |
| --- | --- |
| `id`, `owner_id` | Identify the listing and its owner. |
| `title`, `description` | Explain the offer or need. |
| `listing_type`, `direction` | Identify the kind of opportunity and whether it is offered or requested. |
| `category`, `tags[]` | Supply consistent discovery and matching metadata. |
| `location`, `remote_available` | Explain where participation is possible. |
| `compensation_type` | Optional indication of paid, unpaid, or other compensation. No payment flow is proposed for the MVP. |
| `status`, `created_at` | Support availability and recency. Exact listing status values remain undecided. |

The source suggests these `listing_type` values: `service`, `job`, `internship`, `mentorship`, `collaboration`, `volunteer`, and `business`. It proposes using `direction` to distinguish offers from requests but does not define final allowed values.

Before implementation, settle how `category` differs from `listing_type`, and whether `business` represents a business directory entry, a service listing, or a separate entity. Also define the roles in mentorship, employment, volunteering, and collaboration. Matching cannot rely on the same direction rules for every opportunity without those definitions. See [matching and personalization](03-matching-and-personalization.md#match-the-intended-role-not-just-the-words).

### Connection request

| Proposed fields | Purpose |
| --- | --- |
| `id`, `sender_id`, `recipient_id`, `listing_id` | Link a request to the people and listing involved. |
| `message` | Carry an initial inquiry. |
| `status` | The assistant suggests `pending`, `accepted`, or `declined`. |
| `created_at` | Record request creation time. |

The assistant also suggests a small saved-listing table or collection, without specifying its fields. Detailed organization administration and message-thread infrastructure are deferred recommendations, not established product decisions.

## Requested features versus proposed shortcuts

| Topic | Team's stated direction | Assistant's suggested hackathon approach | Still to decide |
| --- | --- | --- | --- |
| Profile sources | LinkedIn import plus manual profiles | Manual entry and an optional LinkedIn URL; real integration later | Whether import is required for the demo, and what “import” means |
| Contact | Platform messaging | A save or connection-request action with visible confirmation | Whether a request is enough or an actual conversation must work |
| Directory | Opt-in | Opt-in listings and visibility controls | Who may search, which fields are visible, and how consent works |
| Community membership | Muslims broadly; start with Central Jersey masjids | Optional affiliation, separate from profile visibility | How affiliations are represented and whether any are verified |
| Behavioral learning | Adapt to views and accepted opportunities | Explicit signals first | Which events to collect and what users can control |

A connection request with one message is not a complete platform messaging system. A stored LinkedIn URL is not an import integration. Future demos and documentation must describe whichever behavior is actually implemented.

## Visibility and affiliation

The user's “opt-in directory” answer establishes a consent preference, but it does not define the viewing audience. Do not assume that opting in means a fully public profile. The guide recommends letting people control displayed information and remove profiles or listings; the precise controls are still open.

The guide also recommends optional masjid affiliation rather than requiring every person to belong to a specific organization. A self-reported affiliation does not establish membership, endorsement, or identity verification. No real masjid partnership or verification process is confirmed in the source discussion.

## Demo data and trust recommendations

The assistant recommends fictional profiles and opportunities across a few Central Jersey locations, clearly marked as sample data. Do not present invented records as real job openings, real community members, verified providers, or masjid endorsements. These are rules for preparing a future demo; no sample dataset exists from this documentation pass.

For a later real deployment, the guide calls for persistent storage, authentication, access controls, protected messaging, reporting/moderation, and an appropriate verification process before making verification claims. None has been designed in detail or implemented here. The technology stack, hosting provider, and backend remain unselected; the word “flytter” in the source needs clarification.

## Decisions needed before a build

- Define offer/request roles and the canonical listing taxonomy.
- Decide the minimum contact experience and its acceptance states.
- Decide whether LinkedIn import is essential or can be deferred.
- Define opt-in, viewing permissions, editing/removal controls, and affiliation labels.
- Decide how saved listings and behavioral signals relate to profiles and recommendations.
- Choose a clearly disclosed demo storage/authentication approach after the stack is confirmed.

Sources: [team answers](00-source-chat.md#turn-2-user), [expanded-guide request](00-source-chat.md#turn-4-user), and [assistant guide, especially sections 5, 6, 8, and 13](00-source-chat.md#turn-5-assistant).
