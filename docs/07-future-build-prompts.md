# Future build prompts

**Reference only. Do not execute these prompts during the current documentation phase.** The user has explicitly asked for Markdown files and no product coding yet. Start implementation only after the user authorizes coding and the team resolves the intended tool/stack, initial scope, and contact model.

These four staged prompts are adapted from the [prior assistant's guide](00-source-chat.md#turn-5-assistant). They retain its proposed implementation sequence while making the authorization boundary explicit. They are proposals, not evidence that an application exists or that any tests have passed. The source's “flytter” tool name is unresolved; do not silently interpret it as Flutter or another product.

Before later use, replace bracketed choices with agreed decisions. Use one stage at a time and review the result before moving on. In particular, the user's request for platform messaging and LinkedIn import differs from the guide's suggested connection request and manual profile entry; choose deliberately.

## Prompt 1 — Establish the project and scope

```text
Use this prompt only after the user has authorized product coding. If that authorization is absent, remain in documentation mode and stop before implementation.

We are building Muslim Marketplace, a Central Jersey community opportunity marketplace, during a short hackathon.

PRODUCT GOAL
Help Muslims discover useful skills, services, job and internship opportunities, mentors, collaborators, volunteering, and local businesses within their community. People may attend the same masjid without knowing what skills or services others can offer. The core objects are user profiles and actionable marketplace listings.

AGREED DECISIONS
- Intended development tool and framework: [confirmed choice]
- Initial audience and listing categories: [confirmed scope]
- Contact model: [platform messaging, connection request, or other agreed action]
- Profile entry: [manual, optional LinkedIn URL, or approved real integration]
- Persistence/authentication and demo limitations: [confirmed approach]

CORE USER FLOW
1. A user describes their skills, interests, and goals in natural language.
2. The application extracts structured preferences that the user can review and edit.
3. The home page ranks relevant marketplace listings.
4. Each recommendation includes a reason grounded in actual profile and listing data.
5. Users view details, create listings, and complete the agreed save/contact action.

PROPOSED FIRST-VERSION SCOPE
- A clean, responsive marketplace homepage.
- Natural-language search, category/location filters, listing cards, and detail views.
- The agreed subset of services, jobs, internships, mentorship, collaboration, volunteering, and businesses.
- Simple profiles and a create-listing form.
- Matching results with explanations.
- A working save/contact interaction with visible confirmation.
- Clearly labeled fictional Central Jersey sample profiles and listings.

CONSTRAINTS
This is a one-day effort by four people; two are more comfortable using AI coding tools. Prioritize a complete working journey. Inspect the repository before choosing infrastructure. Reuse existing working components when available and do not invent an existing framework if the repository contains only documentation.

Do not scrape LinkedIn or claim that OAuth, messaging, external integrations, partnerships, job openings, or testimonials are real unless they actually are. Use fictional sample content with clear labels. Support desktop and mobile. Keep secrets out of client code and version control.

First summarize the approved scope, actual repository state, and smallest viable implementation plan. Identify unresolved choices. Proceed incrementally only within the user's coding authorization; do not treat this reference file as authorization by itself. Report what was built, verified, and still blocked.
```

## Prompt 2 — Build the interface and marketplace

```text
Use only within an already authorized implementation phase, after the scope and stack have been agreed.

Implement Muslim Marketplace's core interface using the confirmed framework and any established design system.

DESIGN DIRECTION
Create a modern, trustworthy community marketplace with a restrained palette, readable typography, clear hierarchy, consistent spacing, and responsive layouts.

HOMEPAGE
- A clear title and concise statement of the purpose.
- A prominent natural-language search field: "What are you looking for in your community?"
- Useful quick actions, such as "Find a service", "Find a mentor", "Explore jobs", and "Post an opportunity", restricted to the agreed scope.
- A "Recommended for you" section, browsable categories, and location control.
- Listing cards with title, description, category, location, relevant tags, action, and a short evidence-based match explanation.

LISTING MODEL
Use the agreed canonical categories. Distinguish people offering something from people seeking it. A person seeking a mentor needs a mentorship offer; matching keywords alone is insufficient.

FUNCTIONAL REQUIREMENTS
- Search changes displayed results; category and location filters work.
- Cards open the relevant details.
- A valid create-listing submission adds the listing to the agreed data store.
- Saving or the approved contact action changes real application state and confirms success.
- Onboarding/profile editing lets users correct extracted information.
- Empty, loading, validation, and error states are understandable.
- Fictional demo data lets users explore immediately.

Finish the complete agreed core flow before expanding scope. Refine accessibility, spacing, mobile behavior, and error handling. Verify the implemented interactions and report the actual persistence and integration limitations.
```

## Prompt 3 — Implement matching

```text
Use only within the authorized build, after the canonical listing fields and intent semantics have been agreed.

Implement recommendation logic within the confirmed application architecture, separate from UI rendering.

REQUIREMENTS
1. Accept a natural-language request or confirmed structured preferences.
2. If an AI API is configured, extract intent, relevant listing types, skills, interests, keywords, and location preferences.
3. Validate the output. Never invent skills, qualifications, interests, budget, or location. Let users correct their profile. Distinguish explicit statements from inference.
4. Exclude inactive listings and candidates that fail essential constraints. Check offer/request direction and participant roles before scoring.
5. Rank eligible listings using the following proposed starting weights, subject to the team's approval:
   - Intent/listing-type fit: 30%
   - Skills and interests: 25%
   - Description relevance: 25%
   - Geographic suitability: 10%
   - Listing recency: 5%
   - Previously expressed preferences: 5%
6. Return existing listing records with short reasons derived from actual matching signals.
7. For no suitable matches, explain the result and offer ways to broaden the search.

These weights are an initial design proposal, not a trained or validated model. Define how missing signals are handled. Apply hard location constraints when explicit; distinguish remote suitability from local preference.

Use normalized tags/keywords or embeddings already supported by the chosen stack. Avoid adding a large vector database solely for the demo. Provide deterministic fallback behavior when the AI API is missing, fails, or produces invalid output. Browsing and seed-data matching must still work.

For initial personalization, use declared interests and agreed explicit actions such as saves or contact requests. Defer learning from repeated views, accepted jobs, and outcome history until those signals exist and their meaning is defined.

Verify strong and weak matches, a location mismatch, an inactive listing, empty results, invalid AI output, and reversed offer/request roles. Document the ranking method and report only checks actually performed.
```

## Prompt 4 — Finish, verify, and prepare submission materials

```text
Use only after an authorized implementation exists. Confirm current event rules and deadlines before relying on the historical schedule in the project notes.

Perform a quality pass focused on the agreed hackathon scope.

VERIFY THE END-TO-END FLOW
1. Open the application in a fresh session with labeled sample data.
2. Submit a natural-language request.
3. Check relevant listings appear in a sensible order and offer/request roles align.
4. Check each explanation is supported by actual profile and listing fields.
5. Open details and complete the agreed contact/save action with visible confirmation.
6. Create a listing and confirm it appears in the marketplace.
7. If saves and contact are both in scope, verify each separately.
8. Check filters, empty states, form validation, mobile layouts, refresh behavior, loading, and AI failure handling.

Fix broken behavior before adding features. Remove dead controls, misleading labels, duplicate records, and unnecessary setup steps. Record unresolved bugs and the limits of local or mocked state.

README AND SUBMISSION MATERIALS
Document the problem, audience, completed features, matching method, actual stack, environment variables, fresh setup steps, real versus mocked integrations, known limitations, and future improvements. Explain any persistence or authentication restrictions.

Keep secrets on the server or in the platform's secret system. Do not commit credentials. Use clearly labeled fictional data and do not fabricate interviews, endorsements, partnerships, or live opportunities.

Finish with completed functionality, actual verification results, unresolved issues, and the most reliable demonstration sequence. Do not claim a check passed unless it ran. Prepare submission artifacts for review; this prompt does not by itself authorize publishing, submitting, or changing external access.
```
