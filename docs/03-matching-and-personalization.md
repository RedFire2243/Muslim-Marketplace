# Matching and personalization

Status: documentation and design notes only. No matching engine, AI integration, behavioral tracking, or product code has been implemented. The design below separates the team's requests from the prior assistant's proposed implementation.

## What the team requested

The team wants a short natural-language signup experience that learns a person's skills, interests, and needs. The home feed should recommend relevant services, jobs, and opportunities. Matching should combine AI understanding with conventional filtering or ranking, return ranked results with explanations, and eventually adapt to which jobs or opportunities people view and accept. These are stated requirements in [the submitted answers](00-source-chat.md#turn-2-user) and [the expanded-guide request](00-source-chat.md#turn-4-user).

The exact meaning of an “accepted job,” the events to record, and how behavior changes recommendations have not been defined.

## Proposed first matching pipeline

The [prior assistant's guide](00-source-chat.md#turn-5-assistant) recommends the following approach. It is a proposal, not an approved architecture.

1. **Understand the person or request.** Ask what they offer, what they seek, what interests them, and which area to prioritize. Convert the answer into structured preferences that the person can review and edit.
2. **Understand the listings.** Give every listing consistent fields for its type, offer/request direction, description, tags, location, and availability. A simple form and manually prepared demo listings can supply these fields initially.
3. **Filter and rank.** Exclude inactive listings and those that fail essential constraints. Rank eligible records using the requested outcome, relevant skills and interests, description relevance, location, recency, and explicit preferences.
4. **Explain the results.** Give a short reason supported by actual user and listing fields. An empty result set should say that no suitable listing was found and offer broader search options.

AI would interpret language; the ranker would evaluate actual listing records. The source recommends a deterministic fallback when an AI call fails or returns invalid output. Keyword/tag relevance is a possible first implementation; embeddings are an alternative if already convenient. Neither a model provider nor a search service has been chosen.

## Extraction boundaries and a source correction

The source's fictional student says:

> I'm a Rutgers student studying engineering. I know some Python and enjoy robotics. I'm looking for engineering internships, project teammates, and professionals willing to mentor students.

An extraction grounded in that statement could record:

| Field | Supported information |
| --- | --- |
| Education context | Rutgers student studying engineering |
| Stated skill | Some Python |
| Interest | Robotics |
| Seeking | Engineering internships, project teammates, mentorship |
| Offering | Not specified |
| Location preference | Not specified in this statement; ask or use a separately confirmed preference |

**Editorial correction:** the original assistant's structured example adds “embedded systems” and a Central Jersey location preference, neither of which appears in this particular statement. Central Jersey is the project's launch geography, but that does not establish an individual's location preference. Do not turn inferred interests or an academic field into confirmed qualifications. The table above corrects the example; it does not define a final schema.

## Match the intended role, not just the words

A listing titled “Volunteer robotics mentor needed” seeks someone to provide mentorship. It does not offer a mentor to a student seeking guidance. The source places that listing near an explanation about a mentor offering experience; those examples should not be combined as a valid match.

| Person's goal | Compatible listing intent | Potential false match |
| --- | --- | --- |
| Receive robotics mentorship | A professional offers robotics mentorship | A youth group needs a mentor |
| Volunteer as a robotics mentor | A youth group seeks a volunteer mentor | A professional offers mentorship to students |
| Find an internship | An employer offers an internship | Another student seeks an internship |
| Hire a tutor | A tutor offers tutoring | Another family needs tutoring |

Shared tags are evidence of subject relevance, but complementary roles determine whether the listing can satisfy the need. Job offers, service offers, requests for providers, and collaboration opportunities need clear semantics before scoring is implemented. Collaboration may be reciprocal rather than a simple opposite of offer/request.

## Proposed initial ranking weights

These values come from the assistant's guide. They total 100% and have not been validated with users or ranking tests.

| Factor | Proposed weight |
| --- | ---: |
| Goal and listing-type fit | 30% |
| Relevant skills and interests | 25% |
| Description relevance | 25% |
| Geographic suitability | 10% |
| Listing recency | 5% |
| Previously expressed preferences | 5% |

Before implementation, define each factor's scale, handling of missing information, tie-breaking, and any minimum relevance threshold. Decide which constraints are mandatory and which are preferences. A remote opportunity may satisfy a local user's request when remote work is acceptable. These details were not settled in the chat.

## Personalization in stages

| Stage | Source and proposed behavior |
| --- | --- |
| Team's intended experience | Recommendations respond to skills/interests and to viewed or accepted jobs/opportunities. |
| Assistant's suggested hackathon scope | Use declared preferences, saved listings, and connection requests as explicit signals. |
| Suggested later work | Incorporate repeated views, completed connections, successful hires, and other outcomes once enough usage exists. |

The assistant recommends avoiding model training from scratch during the hackathon. That reduces scope but does not resolve the team's requested behavior-learning experience. Decide whether the demo must show feed adaptation or only initial personalization, and describe the actual behavior accurately.

## Future verification checklist

These are proposed checks for a later build, not tests that have been run:

- A strong match ranks above a weak match for the same request.
- Offering and seeking the same service do not become interchangeable.
- Inactive listings and listings failing essential constraints are excluded.
- Location and remote preferences behave as stated.
- Unsupported skills or interests are not added during extraction.
- Every explanation points to information that exists in the profile, request, or listing.
- Empty results and AI failure still leave a usable browsing experience.
- Changing an explicit preference produces an understandable ranking change, if personalization is included.

Related notes: [data and trust](04-data-and-trust.md).
