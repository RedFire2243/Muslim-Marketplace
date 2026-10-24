# Hackathon plan

**Status:** Planning reference only. No product has been built, no interviews have been conducted, and no product tests have been run in this documentation pass. This plan summarizes recommendations from the [shared-chat guide](00-source-chat.md#turn-5-assistant); it is not an approved build schedule.

## Team and constraints

The user described a one-day effort with four people, two of whom have more experience prompting AI coding tools. They want a simple experience with little barrier to entry and startup potential. See the [user's answers](00-source-chat.md#turn-2-user).

Suggested responsibilities from the guide:

| Role | Ownership when implementation is authorized |
| --- | --- |
| Technical lead | Scope, application integration, architecture, and a consistently working demo |
| AI and matching | Parsing, ranking, evidence-based explanations, fallback behavior, and matching checks |
| Product and experience | Onboarding, listing categories, screens, mobile usability, and sample content |
| Validation and pitch | User interviews, documented feedback, journey checks, submission materials, and rehearsal |

Assign one integration owner and clear file boundaries. The two people using AI coding tools should coordinate scope and interfaces rather than independently generate competing versions of the application. These are proposed roles, not named assignments.

## Event information to verify

The following are **unverified claims made by the prior assistant**, retained so the team knows what to check. This documentation pass has not verified the event website. Consult the [official rules](https://mc2-hackathon-2026.up.railway.app/rules) and [official prizes](https://mc2-hackathon-2026.up.railway.app/prizes) before relying on any item.

| Topic | Claim in the shared chat |
| --- | --- |
| Submission deadline | Sunday, October 25, 2026, at 1:00 PM Eastern |
| Team size | One to four people |
| Submission | Public repository and working product presented in person |
| Development timing | Product development must start at the event; AI tools, public APIs, libraries, and templates are allowed |
| Judging | Technicality, originality, practicality, aesthetics, and wow factor |
| Suggested award fit | Most Likely to Become a Venture; the assistant described accelerator support including funding, workspace, mentorship, and a later demo day |
| Other award claims | Best User Insight values evidence and changes based on interviews; Best Use of GitHub considers README quality and development history |
| Schedule | Saturday 4:00 PM checkpoint; Sunday 9:45 AM build session, 1:00 PM submission close, 2:00 PM demos |
| Presentation | Ten-minute slot, approximately five minutes presenting and three minutes answering questions |

**Schedule inconsistency:** The guide reports a Sunday 9:45 AM session start but proposes a 9:00 AM build block. Confirm access and the actual schedule before assigning clock times. Use the phase order below until the event timing is confirmed. The guide's proposed 12:30 PM internal cutoff was a suggestion, not an event rule.

### Masjid App Challenge decision

The prior assistant described an opt-in challenge for the Muslim Center of Greater Princeton (MCGP), involving prayer times, events, announcements, RSVPs, room or desk bookings, and configuration that supports additional organizations. It said mock data was permitted and general entries were considered for open awards.

The marketplace alone was described as insufficient for that challenge. The assistant suggested adding an MCGP community page and participation action, but that suggestion **does not establish compliance with the full challenge**. Verify the complete requirements and choose whether to enter before expanding scope. No MCGP partnership, endorsement, or challenge eligibility is established here.

## Proposed execution phases

All phases are future work, dependent on coding authorization and resolved stack, category, and contact decisions. The proposed P0 scope is described in [MVP and user flows](02-mvp-and-user-flows.md).

| Phase | Intended result | Exit condition |
| --- | --- | --- |
| 1. Freeze the demo scope | One audience/story, canonical categories, offer/request meaning, contact action, stack, and fictional content plan | Team can describe the entire journey and what is intentionally deferred |
| 2. Complete the P0 journey | Profile/onboarding → feed/search → listing details → meaningful action; create-listing flow | A fresh session can complete the selected journey without dead controls |
| 3. Improve relevance | Parse requests, filter candidates, rank, and explain matches | Strong matches outrank weaker ones; explanations refer to actual records |
| 4. Stabilize | Forms, filters, responsive layout, failure handling, and demo state | The acceptance checks below have recorded results and blocking bugs are fixed |
| 5. Prepare the submission | README, repository, project story, screenshots, integration disclosures, and device rehearsal | A teammate can follow the setup and reproduce the demo |

Attempt P1 personalization or community affiliation only after the full P0 path works. Defer full LinkedIn integration, payments, a social graph, trained recommendation models, extensive chat infrastructure, and automated onboarding of every masjid unless the team explicitly changes scope.

## Future acceptance checks

These are checks to perform later; none is marked passed.

- [ ] A fresh session loads clearly labeled fictional profiles and listings.
- [ ] Natural-language input changes the results, and category/location filters work.
- [ ] Inactive and ineligible listings are excluded; offer/request roles are compatible.
- [ ] Strong, weak, location-mismatched, and empty-result examples behave sensibly.
- [ ] Each recommendation explanation is supported by the user's confirmed preferences and listing fields.
- [ ] A listing opens the correct details; creating a listing updates the marketplace.
- [ ] The approved save/contact action changes state and gives visible confirmation.
- [ ] Forms validate input; mobile layouts, refresh behavior, loading, and error states work.
- [ ] An unavailable or invalid AI response leaves browsing and fallback matching usable.
- [ ] The README distinguishes live integrations, mock behavior, persistence limits, and known issues.

The source alternates between “save or contact” as the minimum action and demonstrating both. Choose the actual commitment before building and report its completion accurately.

## Validation before polish

The guide recommends speaking with three to five people who know the local community. Use these questions as an interview guide, not as findings:

1. When have you needed a service, mentor, job connection, or professional contact that someone in the community might provide?
2. How did you find that person, and what made it difficult?
3. Which would you use: a searchable directory, a personalized feed, or natural-language search? Why?
4. What would make you trust a listing or feel comfortable contacting its owner?

Record the person's context, the actual need, current workaround, trust concern, and any product change prompted by their answer. Ask permission before attributing a quote. If one category is clearly more urgent, narrow the demo around it. No interview results or testimonials are supplied by the source chat.

## Five-minute demo outline

Use one fictional student who wants a robotics mentor and an engineering internship in Central Jersey. Prepare listings that actually offer those outcomes, rather than treating a request for a volunteer mentor as an offer of mentorship.

| Segment | Time | What to demonstrate |
| --- | --- | --- |
| Problem | 30 seconds | People share a masjid community but often cannot discover one another's useful services and opportunities |
| Natural-language request | 45 seconds | The student describes their background and needs |
| Matching | 90 seconds | Ranked listings, grounded explanations, and a clear relevant-versus-less-relevant comparison |
| Concrete next step | 60 seconds | The approved contact/save action or a new listing, with visible state change |
| Growth hypothesis | 45 seconds | How participating communities could supply useful listings and bring in members |
| Buffer | 30 seconds | Transitions and technical issues |

Show only behavior that has actually been implemented. State whether AI parsing is live, which content is fictional, and whether the action is a local prototype or a persistent multi-user workflow.

## Startup hypotheses to test

| Hypothesis from the guide | Evidence to seek |
| --- | --- |
| Local needs and useful skills are hard to discover | Recent examples and existing workarounds from interviews |
| A marketplace will attract both posters and responders | Willingness to post legitimate opportunities and respond to relevant listings |
| A focused community can supply enough useful content | A small participating group's ability to maintain fresh listings |
| Explainable recommendations improve discovery | Users finding a relevant listing and understanding why it appeared |
| Masjids and organizations can become distribution channels | Actual interest in a pilot, without implying a partnership in advance |
| Free core use can later support paid organization tools or labeled promotions | Demand and willingness to pay after useful marketplace activity exists |

Organization pages, verification, administration, advanced recommendations, subscriptions, and featured listings are future possibilities. The guide identified marketplace liquidity—enough useful listings and enough people acting on them—as the central business uncertainty. No revenue model or demand has been validated.
