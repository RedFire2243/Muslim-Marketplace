# Decisions and open questions

Status: planning record, October 24, 2026. This is a list for a later scope discussion; it does not request implementation now.

## Current working boundary

The current instruction is to read the shared chat and create Markdown files without coding the product. The archived assistant's build prompts, reminder offer, and suggestions do not authorize those actions in this project.

## What the team explicitly stated

These are the strongest baseline requirements from [turn 2](00-source-chat.md#turn-2-user), repeated in [turn 4](00-source-chat.md#turn-4-user):

- Start with Central Jersey and the Muslim community broadly, with local masjids as the intended community context.
- Help people find actual services, things they need done, work, and professional opportunities.
- Keep setup simple and the barrier to entry low.
- Collect skills, interests, and needs through natural language during signup.
- Use hybrid matching, ranked results, and reasons for recommendations.
- Eventually adapt recommendations to viewed and accepted opportunities.
- Support manual profiles and LinkedIn import, an opt-in directory, and platform messaging.
- Optimize for startup potential within a one-day, four-person hackathon; two members have more experience using AI coding tools.

The broad audience and use-case list are recorded in the [product brief](01-product-brief.md). The chat does not select one initial segment from that list.

## Choices that materially affect the first build

Every item below remains open. Recommendations are attributed to the prior assistant unless marked as an editorial clarification.

| ID | Decision | Evidence or tension | Proposed way forward, pending a team choice |
| --- | --- | --- | --- |
| D01 | Development tool and stack | The user wrote “flytter”; its meaning was not resolved. | Clarify the tool before choosing a framework, backend, AI provider, or deployment service. |
| D02 | Initial audience and use case | The team listed many community segments and opportunity types. | Choose one demonstration story. The source suggests local services plus professional opportunities. |
| D03 | Initial coverage | The team envisioned Central Jersey masjids broadly; the assistant suggested a few participating communities. | Decide the first pilot scope. No organizations or partnerships are confirmed. |
| D04 | Product direction | The guide offers six alternatives and recommends marketplace + natural-language discovery + light personalization. | Select the first product boundary; see the [six directions](01-product-brief.md#six-possible-directions-from-the-chat). |
| D05 | Contact experience | Platform messaging was requested; the guide substitutes a connection request and defers extensive chat. | Decide whether the demo needs a conversation, an inquiry with a status, or another contact flow. |
| D06 | Minimum action | The guide's priority table permits save or inquiry; later checks expect both. | Decide whether saving is enough. Saving alone does not make contact. |
| D07 | LinkedIn | Import was requested; manual entry and an optional URL were proposed to reduce scope. | Decide whether real import is essential and define what it imports. A URL field is a reference, not an integration. |
| D08 | Personalization depth | The team wants learning from views and accepted jobs; the guide proposes explicit interests, saves, and requests first. | Define “accepted” and whether the demo must visibly adapt after an interaction. |
| D09 | Listing taxonomy and roles | Listing type, category, offer/request direction, and business entries overlap. | Define canonical terms and complementary roles. Someone seeking a mentor needs a mentor offer, not another request for a mentor. |
| D10 | Visibility and trust | “Opt-in directory” does not specify who can view which fields. | Define audience, consent, editing/removal controls, affiliation labels, and verification claims. Optional affiliation was a recommendation. |
| D11 | Storage and identity | The guide allows a managed backend or a clearly described local demo fallback. | Choose persistence, user identity, and real versus simulated actions after confirming the stack. |
| D12 | Award or challenge | Startup potential is the team's priority. The guide suggests a venture award and conditionally a masjid-specific challenge. | Verify current rules and choose the target before adding organization hub features. |

Source: [assistant guide, especially sections 3–8 and 13–14](00-source-chat.md#turn-5-assistant). Role compatibility and the distinction between saving and contact are editorial clarifications of gaps in the proposal.

## Assumptions to validate with people

The source proposes interviews; it does not contain interview results. Evidence is still needed for these questions:

| Hypothesis | Evidence to seek |
| --- | --- |
| Useful opportunities exist but are hard to discover. | Recent examples of a real unmet need and how people tried to find help. |
| Members will post as well as browse. | What someone would actually publish and what motivates a response. |
| Natural-language discovery is useful. | Reactions to a search box, categories, and a personalized feed. |
| An organization can help distribution. | Interest from an actual organization and a way to gather legitimate listings. |
| Members will trust and contact a listing owner. | Information, privacy choices, and trust signals needed before reaching out. |
| The marketplace can sustain repeat use. | Useful opportunities, response rates, repeat visits, and successful connections in a future pilot. No targets are established. |

## Source issues to avoid carrying into implementation

- The questionnaire's displayed choices differ from explicit submitted answers. Use turns 2 and 4 as the requirement record.
- The extraction example adds “embedded systems” and an individual location preference not supplied in the example statement. See the [corrected interpretation](03-matching-and-personalization.md#extraction-boundaries-and-a-source-correction).
- The mentor example can confuse offering mentorship with seeking a mentor. Shared keywords are insufficient evidence of a useful match.
- Event claims have not been independently checked. The source proposes a Sunday 9:00 AM block while describing an official 9:45 AM build start; resolve that before scheduling.
- The prior chat ends with a reminder offer. No reminder or automation was requested or created in this pass.

## Suggested order for the next planning conversation

Resolve D01–D06 first to establish the tool, audience, scope, and complete journey. Then settle imports, personalization, taxonomy, visibility, and data behavior against the available time. Check current event rules before choosing challenge-specific scope. Record eventual choices here with their dates and reasons.

The [future build prompts](07-future-build-prompts.md) remain reference material until the user asks to begin implementation.
