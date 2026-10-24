# Proposed MVP and user flows

Status: proposed scope distilled from the prior assistant's guide. The team has not yet approved this feature boundary. The current task is documentation only; no screens, services, integrations, or product code have been built.

The team's stated requirements are recorded in the [product brief](01-product-brief.md). The main source for the proposal below is [turn 5, sections 3, 5–8, and 14](00-source-chat.md#turn-5-assistant).

## The proposed demonstration

A member describes what they can offer and what they need. The marketplace interprets the description, ranks eligible listings, explains the recommendations, and lets the member take a concrete action.

For example, a fictional engineering student asks for a robotics mentor and an internship in Central Jersey. The results should distinguish a mentor offering help from a group seeking a volunteer mentor: shared keywords alone do not make those the same opportunity.

## Proposed scope priorities

The P0/P1/P2 labels below come from the prior assistant's recommendation. They are planning priorities, not completed work.

| Priority | Feature | Proposed minimum behavior |
| --- | --- | --- |
| P0 | Marketplace home | Responsive page displaying opportunity cards |
| P0 | Listings | Offers and requests for services, jobs, internships, mentorship, and related opportunities |
| P0 | Natural-language search | A written request changes the results; category and location filters also work |
| P0 | Matching and explanations | Rank actual listing records and give reasons supported by their fields |
| P0 | Short profile | Skills, interests, location, and needs; allow editing |
| P0 | Create listing | A form creates an offer or request that appears in the marketplace |
| P0 | Connection action | A save or inquiry action produces a state change and visible confirmation |
| P1 | Personalization | Use declared interests and saved opportunities to adjust ranking |
| P1 | Community affiliation | Optional selection of a participating masjid or organization |
| P2 | LinkedIn integration | Defer real import/OAuth; proposed substitute is manual entry or an optional URL |

The prior guide also called for fictional demo data, useful empty states, accessible controls, error handling, and a fallback when AI is unavailable. These support the full demonstration flow.

### Scope tensions to resolve

- **Messaging:** the team requested platform messaging. The guide proposed a simpler connection request for the hackathon and deferred extensive chat infrastructure. The team must choose what the first version promises.
- **Personalization:** the team described learning from viewed and accepted jobs. The guide placed simple preference feedback after the core flow, with more behavioral learning later. Basic ranking by onboarding answers still belongs to the proposed core flow.
- **Connection action:** the priority table allows save *or* inquiry, but the guide's later quality pass expects both saving and a connection request. Choose a minimum before implementation; saving alone does not establish contact.
- **LinkedIn:** import was a user preference; manual entry or a URL was an assistant-proposed reduction.
- **Coverage:** the team envisioned all Central Jersey masjids; the guide suggested a smaller initial set of participating communities. No partners were confirmed.

## Journey 1: onboarding and profile review

1. A new member receives a short explanation of the marketplace and visibility choices.
2. They describe what they offer, what they seek, their interests, and preferred area in plain language.
3. The proposed parser extracts structured preferences.
4. The member reviews and edits the extracted information.
5. The home page shows relevant listings.

The team explicitly wanted natural-language onboarding and simple setup. Review and editing were recommended by the prior assistant. The precise questions, sign-in requirement, and visibility audience remain open.

Proposed acceptance criteria:

- A member can correct extracted information before relying on it.
- The system does not add unsupported skills, qualifications, budget, or location.
- The opt-in choice is explicit; its exact visibility policy is still to be defined.
- A parsing failure has a clear fallback so browsing remains possible.

## Journey 2: discover an opportunity

1. Enter a request such as “I'm looking for a robotics mentor and an engineering internship in Central Jersey.”
2. Apply category and location preferences if needed.
3. Review ranked listings with category, location, relevant tags, and a short explanation.
4. Open a listing to inspect its full details and available action.
5. Broaden the search if no suitable listing exists.

Proposed acceptance criteria:

- Changing the request or filters changes the displayed results appropriately.
- Inactive or ineligible listings do not appear as suitable recommendations.
- Results respect the difference between offering and seeking help.
- Explanations refer to actual listing and profile data.
- An empty result state is useful and does not invent an opportunity.

## Journey 3: post an offer or request

1. Choose whether the listing offers something or requests something.
2. Enter a title, description, category, location, and relevant details.
3. Review and submit the listing.
4. Receive confirmation and see it in the marketplace.

Proposed categories from the guide: services, jobs, internships, mentorship, collaboration, volunteering, and businesses. Categories describe the opportunity; direction distinguishes an offer from a request.

Proposed acceptance criteria:

- Required fields are validated with clear feedback.
- A listing belongs to its owner and remains separate from their profile.
- Posting updates the displayed marketplace state.
- Persistence and refresh behavior are tested and described honestly when implementation begins.

## Journey 4: act on a match

1. Open a relevant listing.
2. Save it or request contact, according to the chosen scope.
3. Receive an explicit confirmation.
4. If connection requests are selected, provide a way to see their status and define how the recipient responds.

The guide proposed pending, accepted, and declined connection request states. That is a proposed contact model. It does not satisfy the team's request for live platform messaging by itself.

Proposed acceptance criteria:

- The action produces an observable state change.
- The interface clearly describes whether contact was requested, a listing was saved, or a message was actually sent.
- Demo interactions and real multi-user functionality are identified accurately.

## Proposed screen inventory

| Screen or view | Purpose |
| --- | --- |
| Welcome and short onboarding | Collect the member's goals and preferences |
| Profile review and editing | Correct extracted information and manage displayed information |
| Marketplace home and results | Browse, search, filter, and understand recommendations |
| Listing details | Assess a specific offer or need and take action |
| Create listing | Publish an offer or request |
| Saved items or request confirmation/status | Show the result of the chosen connection action |

This is a screen planning aid, not an approved design system or implementation plan. The framework, backend, AI provider, authentication, and deployment method remain unselected. The source's “flytter” reference needs clarification.

## Deferred features proposed in the guide

- Real LinkedIn OAuth/import and profile scraping.
- A social graph and mutual introduction paths.
- Recommendation model training or extensive vector infrastructure.
- Payments and marketplace checkout.
- Native mobile applications.
- Extensive messaging infrastructure.
- Automated onboarding of all masjids.
- Full organization administration, verification, and moderation workflows.

Some deferred items represent reductions from the team's original ambitions. They must be agreed before implementation; this document does not silently remove them from the longer-term vision.

## What would make a future MVP ready to demonstrate

The following is a proposed review checklist for the later build phase, not a claim of completed testing:

- A fresh session can complete onboarding, get useful results, inspect a listing, and take the selected action.
- The create-listing form changes the marketplace state.
- Search, filters, explanations, empty results, and AI failure behavior work.
- Mobile and desktop layouts support the same core flow.
- Fictional profiles and listings are clearly labeled; no partnership or verification is implied without evidence.
- The team can explain which data persists and which integrations are real or mocked.
- The demonstration shows a need, a relevant discovery, and a concrete step toward a connection.
