# Muslim Marketplace — product brief

Status: planning notes from the shared chat, prepared October 24, 2026. This project is currently documentation only. No product implementation or technology stack has been approved in this pass.

## The problem the team described

People attend the same masjid without learning what others do, what services they offer, or what help they need. Useful skills, work, and opportunities exist nearby but are difficult to discover. The team wants a simple way to surface relevant listings on a home page, based on a person's skills, interests, and goals. [Source: user answers](00-source-chat.md#turn-2-user).

The intended product centers on actual services, tasks people need done, and people seeking work. Profiles support discovery, while listings give members something concrete to act on.

## Requirements stated by the team

| Topic | Stated intent |
| --- | --- |
| Initial geography | Central Jersey, with an ambition to reach the masjids in that area |
| Community | Muslims broadly |
| Audience | Students, professionals, business owners, entrepreneurs, mentors and mentees, job seekers, founders, investors, community organizations, and other community members |
| Opportunities | Services, jobs, internships, mentorship, professional contacts, collaborators, clients, business partners, local businesses, and shared interests |
| Onboarding | Describe skills, interests, and needs in natural language |
| Discovery | Hybrid matching and a ranked list with explanations |
| Personalization | Recommendations should eventually improve from viewed and accepted opportunities |
| Profile sources | LinkedIn import plus manual profiles |
| Privacy | Opt-in directory |
| Contact | Platform messaging |
| Product experience | Simple setup and a low barrier to entry |
| Hackathon goal | Startup potential |
| Team constraints | One day, four people, two more experienced with AI coding tools |

These are statements from the source discussion, not evidence that any capability exists. [Sources: user answers](00-source-chat.md#turn-2-user), [expanded request](00-source-chat.md#turn-4-user).

The team wrote “flytter” as the intended development tool. Its meaning remains unresolved; these notes do not assume Flutter or any other framework.

## Working product definition

The prior assistant recommended a **local Muslim community opportunity marketplace**: members publish things they offer and things they need, and discover relevant services, work, mentorship, and collaboration opportunities.

Suggested positioning from that response: **“Discover the skills, services, and opportunities within your Muslim community.”**

The proposed core experience is:

1. Describe your skills, interests, and needs.
2. Review the preferences extracted from your description.
3. See relevant local listings and reasons for the matches.
4. Open a listing and take a useful next step.

This is the prior assistant's recommended direction, pending the team's decisions about scope. [Source: full guide, sections 2–3](00-source-chat.md#turn-5-assistant).

## Six possible directions from the chat

| Direction | What a member does | Main value | Scope implication |
| --- | --- | --- | --- |
| A. Local opportunity marketplace | Posts and discovers offers and needs | Broad practical utility across services and professional opportunities | Recommended foundation |
| B. Ask the Muslim community | Describes a goal in one search box | A clear natural-language discovery experience | Can be the search interface within A |
| C. Skills and services exchange | Offers or requests tutoring, design, bookkeeping, repairs, and similar help | A concrete local use case | Could start with offers and requests; paid, free, volunteer, or barter arrangements were suggested |
| D. Career and mentorship network | Finds internships, projects, mentors, and early-career opportunities | A focused audience and outcome | Narrows the initial market toward students and professionals |
| E. Masjid community hub | Uses an organization's opportunity board, announcements, events, or volunteering information | Distribution through existing communities | Adds organizational features and a separate challenge-fit decision |
| F. Personalized opportunity discovery | Gets a feed adjusted to stated interests and interactions | Repeat use and more relevant discovery | Start with simple signals; advanced behavior modeling was proposed for later |

The prior assistant recommended **A + B + a small part of F**, with services and career opportunities as categories. E was conditional on a deliberate choice to pursue the Masjid App Challenge. None of these alternatives has been selected by the team in the captured chat. [Source: full guide, section 4](00-source-chat.md#turn-5-assistant).

## Why the proposed direction could matter

- A member can find useful help or work already available in their community.
- A provider can make an offer discoverable beyond the people they personally know.
- A student or job seeker can discover relevant professional opportunities.
- A participating organization could help members share opportunities through an existing local network.

These are product hypotheses to validate with actual users. The source contains no completed interviews, confirmed partnerships, active listings, or evidence of adoption.

## Initial launch hypothesis

The team wants Central Jersey coverage. The prior assistant suggested beginning with a small number of participating communities to create enough useful supply and responses, then expanding. This is a proposed rollout strategy, not a confirmed list of partner masjids.

The key business uncertainty is whether enough people will post useful listings and act on them. Suggested future possibilities include organization tools, verified business profiles, mentorship pathways, and clearly labeled featured listings. No pricing or revenue model was chosen. [Source: full guide, sections 8–9 and 14](00-source-chat.md#turn-5-assistant).

## Decisions still needed

- Select the first audience and strongest demonstration use case from the broad list above.
- Choose the initial participating communities and whether listing affiliation is optional.
- Resolve the difference between platform messaging requested by the team and the simpler connection request proposed for the demo.
- Decide whether real LinkedIn import is essential or can wait behind manual profiles and an optional URL.
- Confirm what “flytter” means before choosing any technology.
- Choose the hackathon award or challenge target before adding organization hub features.

See [MVP and user flows](02-mvp-and-user-flows.md) for the proposed first version. The [source chat](00-source-chat.md) remains the record of what was actually discussed.
