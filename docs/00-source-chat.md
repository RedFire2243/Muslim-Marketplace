# Source chat archive

Source: [Hackathon Idea Questions — shared ChatGPT conversation](https://chatgpt.com/share/6add0613-c25c-83ea-ab37-69e98f53d563)  
Captured: October 24, 2026 (America/New_York)  
Method: Read the shared conversation in the browser, expand both long user messages, and capture the rendered message text and visible document structure.

## How to read this archive

This archive contains the five turns visible in the shared link, in order. It does not reconstruct any earlier conversation. The short assistant response in turn 3 visibly ends mid-sentence; it is preserved as displayed.

Message wording, examples, proposals, and mistakes are retained. Headings, lists, tables, and code blocks are restored to Markdown from the rendered structure, with heading depth and spacing normalized. Interface labels such as “Show more,” “Writing,” and “Sources” are omitted; citation labels remain as displayed because their source popovers were not resolved. This is a browser transcription, not an official ChatGPT data export.

The opening questionnaire is an interactive form. Its displayed controls/default selections are not a reliable record of the submitted answers. The explicit user messages in turns 2 and 4 establish the team's stated requirements.

The prior assistant's claims about event rules, deadlines, prizes, and judging have **not been independently verified in this documentation pass**. Its implementation prompts and reminder offer are archived text, not instructions to execute now. This project is currently documentation only.

The source extraction example includes “embedded systems” even though the example user did not state it. The source also uses a “mentor needed” listing in a way that can confuse seeking mentorship with offering it. The derived matching notes flag both issues; the archive leaves the original wording intact.

## Turn index

1. [Assistant: discovery questionnaire](#turn-1-assistant)
2. [User: submitted answers and constraints](#turn-2-user)
3. [Assistant: partial direction recommendation](#turn-3-assistant)
4. [User: request for an expanded guide](#turn-4-user)
5. [Assistant: full guide and future coding prompts](#turn-5-assistant)

---

## Turn 1: Assistant

The main question is what problem the Muslim Marketplace solves. It could become a professional networking platform for Muslims in Central Jersey, an AI-powered introduction service, a community business directory, or a combination of these.

For a hackathon, I'd focus on identifying one compelling use case first, then build the smallest demo that proves it works.

Answer these questions in your own words. You can skip any you're unsure about.

### 1. Who is this for?

1. Who should use the platform?

College students

Professionals

Business owners and entrepreneurs

People seeking mentors

Job seekers

Investors and founders

Community organizations and nonprofits

Anyone in the Muslim community

2. What geographic scope do you envision?

Central Jersey initially, then expand

All of New Jersey

Nationwide from the start

3. Who counts as part of the community?

Muslims broadly, regardless of background

Muslim professionals and organizations

Local masjid and university networks first

### 2. What problem are you solving?

4. What should someone be able to accomplish?

Select all that apply.

Finding mentors

Finding professional connections

Finding internships or jobs

Finding cofounders or project teammates

Finding clients or business partners

Discovering Muslim-owned businesses

Finding people with shared interests or goals

Getting introductions through mutual connections

5. What is currently difficult about making these connections?

### 3. How should the matching work?

6. What would a user enter?

A natural-language description of what they need

Filters such as industry, skills, location, and experience

Both a written description and filters

7. How should people be matched?

AI understands the request and matches it to profile information

Conventional filtering and a scoring algorithm

AI matching combined with filters and a ranking system

8. What should the results look like?

A ranked list with reasons each person is a good match

Suggested people plus a way to request an introduction

Suggested people plus mutual connections who can introduce them

All of the above

### 4. What data and trust model will you use?

9. Where will profiles come from?

LinkedIn import plus manual profile creation

Users create their own profiles

Participating masjids, universities, and organizations provide profiles

Public professional information, with an appropriate permission and data-use model

LinkedIn integration has technical and platform-policy constraints, so the exact import method will matter for the hackathon implementation.

10. Who can see someone's profile?

Only people who explicitly opt into the directory

Anyone can search profiles

Only verified community members

11. How should users contact matches?

Request to connect, subject to acceptance

Show contact details or professional links

Request an introduction through a mutual contact

Message through the platform

### 5. What will make the hackathon demo compelling?

12. What matters most to the judges?

A working AI-powered matching experience

A clear problem and meaningful community impact

A polished interface and end-to-end user experience

Technical depth and an interesting matching algorithm

A product that could grow into a real business or nonprofit

13. What resources do you have?

Small team, limited time, and little existing infrastructure

Team members comfortable with frontend and backend development

Team members experienced with AI APIs and databases

Access to an existing network of local Muslim professionals or organizations

14. Any other constraints or existing ideas?

You can submit your answers below; unanswered questions are fine.

Submit answers

My initial recommendation is to make the core experience “Describe the connection you need; discover the best people in your community.” The directory supplies the data, while matching and useful explanations provide the distinctive feature. The questions above should help determine whether the primary use case is mentorship, careers, entrepreneurship, or broader community networking before we expand the concept.


---

## Turn 2: User

Help define the Muslim Marketplace hackathon idea based on these answers. Do not fully expand the concept yet; identify the strongest direction and unresolved decisions.

Target users: Students, Professionals, College students, Business owners and entrepreneurs, People seeking mentors, Job seekers, Investors and founders, Community organizations and nonprofits, Anyone in the Muslim community

Geography: Central Jersey initially

Community scope: Muslims broadly

Use cases: Finding mentors, Finding professional connections, Finding internships or jobs, Finding cofounders or project teammates, Finding clients or business partners, Discovering Muslim-owned businesses, Finding people with shared interests or goals, Getting introductions through mutual connections

Current problem: there are many people that go to a masjid, however they dont meet each and other and learn about each others professions, we want to make a platform with services listed that could deliver it to a home page or something  because it matches with that persons skills and interests, which are all asked through natural language processing at the beginning of sign up, and based on waht jobs are accepted and viewed it those skillsa and themes and features and opportunities could be recommended more to them, like a real algorithm.

Input: Natural-language description

Matching: Hybrid matching

Results: Ranked matches with explanations

Profile sources: LinkedIn import plus manual profiles

Privacy: Opt-in directory

Contact: Platform messaging

Hackathon priority: Startup potential

Resources: Small team, limited time

Other context: We have limited time one day, we have 4 people, but only 2 people have experience using ai and promptinf for code, we are going to use flytter, this is the info for  judging. we want it to be easy for start to finish, we want to start with central jersey all the masjids there, and very simple setup so little barrier to entry. its like al ist of different skills, services, not a linkedin network but actual services and things that people want done and people looking for jobs.

 https://mc2-hackathon-2026.up.railway.app/prizes

https://mc2-hackathon-2026.up.railway.app/rules


---

## Turn 3: Assistant

Your strongest direction is a Muslim community opportunity marketplace: a platform that helps Muslims in Central Jersey discover useful services, professional opportunities, and people within their local masjid network.

The key insight is that people who attend the same masjid may have complementary skills and needs but have

---

## Turn 4: User

Use the following to expand into a full guide and multiple ideas that are possible to implement. parts of this statement or definition of our idea will help prompt ai or llms to build code. do this to the best of your ability and add anything you thing necessary. Help define the Muslim Marketplace hackathon idea based on these answers. Do not fully expand the concept yet; identify the strongest direction and unresolved decisions.

Target users: Students, Professionals, College students, Business owners and entrepreneurs, People seeking mentors, Job seekers, Investors and founders, Community organizations and nonprofits, Anyone in the Muslim community

Geography: Central Jersey initially

Community scope: Muslims broadly

Use cases: Finding mentors, Finding professional connections, Finding internships or jobs, Finding cofounders or project teammates, Finding clients or business partners, Discovering Muslim-owned businesses, Finding people with shared interests or goals, Getting introductions through mutual connections

Current problem: there are many people that go to a masjid, however they dont meet each and other and learn about each others professions, we want to make a platform with services listed that could deliver it to a home page or something  because it matches with that persons skills and interests, which are all asked through natural language processing at the beginning of sign up, and based on waht jobs are accepted and viewed it those skillsa and themes and features and opportunities could be recommended more to them, like a real algorithm.

Input: Natural-language description

Matching: Hybrid matching

Results: Ranked matches with explanations

Profile sources: LinkedIn import plus manual profiles

Privacy: Opt-in directory

Contact: Platform messaging

Hackathon priority: Startup potential

Resources: Small team, limited time

Other context: We have limited time one day, we have 4 people, but only 2 people have experience using ai and promptinf for code, we are going to use flytter, this is the info for  judging. we want it to be easy for start to finish, we want to start with central jersey all the masjids there, and very simple setup so little barrier to entry. its like al ist of different skills, services, not a linkedin network but actual services and things that people want done and people looking for jobs.

 https://mc2-hackathon-2026.up.railway.app/prizes

https://mc2-hackathon-2026.up.railway.app/rules


---

## Turn 5: Assistant

### 1. Hackathon strategy and judging

I checked the official MC² Hackathon rules and prizes. Your concept is a natural fit for the Most Likely to Become a Venture award, and it may also fit the Masjid App Challenge, which asks teams to build something a masjid community would use every week. The Masjid App Challenge is an opt-in award. Every submission is automatically considered for the open awards. 
MC² Summit Hackathon

Important constraints from the official rules:

- Deadline: Sunday, October 25, 2026, at 1:00 PM Eastern.
- Team size: One to four people; your four-person team fits the limit.
- Working product: Every team must present a working product in person.
- Public repository: Required for submission.
- Development: Work must start at the event, although AI tools, public APIs, libraries, and templates are allowed. 
  MC² Summit Hackathon

The venture award includes an MC² Accelerator opportunity, with funding, workspace, a mentor, and a follow-up demo day. 
MC² Summit Hackathon

That means I would optimize for three things: a convincing real-world problem, a working end-to-end demonstration, and evidence that the product could become useful to actual masjid communities.

### 2. Define the product before building it
#### Recommended concept

Muslim Marketplace — Discover the skills, services, and opportunities within your Muslim community.

Muslim Marketplace is a local, community-oriented platform that connects Muslims with people who can help them, services they can use, work they can offer, and opportunities relevant to their goals.

People at the same masjid or in nearby Muslim communities often do not know what one another do professionally. A masjid attendee might be a web developer, accountant, tutor, contractor, business owner, or recruiter. Another attendee might need precisely that person's skills but have no way to discover them.

Muslim Marketplace makes those connections discoverable through a searchable directory, user-posted opportunities, and personalized recommendations.

The platform starts in Central Jersey, with the long-term possibility of expanding through participating masjids and community organizations.

#### The most important distinction

This should be a marketplace of needs, skills, services, and opportunities, rather than simply a directory of people's professional biographies.

| A conventional professional network | Muslim Marketplace |
| --- | --- |
| Primarily describes who you are | Emphasizes what you can offer and what you need |
| Focuses on professional history and connections | Focuses on actionable services, jobs, and opportunities |
| Relies heavily on users searching for people | Recommends relevant opportunities to users |
| Often encourages networking in general | Helps users identify a specific next action |
| Can feel like another social network | Should feel like a useful community resource |

Profiles remain important, but they support the marketplace rather than define the product.

### 3. The recommended MVP: an opportunity feed powered by matching

I would build one coherent product with three connected features, rather than trying to implement every use case independently.

1. A personalized community feed

A home page displaying relevant services, jobs, internships, mentorship offers, requests for help, and collaboration opportunities. Users can browse categories or search in plain English.

2. Natural-language matching

A user writes, “I'm an engineering student looking for a summer internship or someone who can mentor me in robotics.” The application identifies the relevant needs and returns the best available listings, with an explanation of each match.

3. An actionable connection

Each listing has a meaningful next step: view details, save it, offer a service, or request contact from the person who posted it.

These features form one complete flow:

User describes their skills, goals, and needs

AI extracts structured interests and requirements

Matching ranks relevant community listings

Personalized feed with explanations

User takes action to make a real connection

The marketplace listing is the most important object in this design. A person might be an accountant by profession, offer tax-preparation services, need a website for their business, and seek a part-time assistant. The platform should represent those different activities separately instead of forcing everything into one professional bio.

#### What must work by the demo

| Priority | Feature | Minimum implementation |
| --- | --- | --- |
| P0 | Marketplace home | A polished, responsive page with opportunity cards |
| P0 | Listings | Display services, jobs, requests, and mentorship opportunities |
| P0 | Search | Natural-language input plus category and location filters |
| P0 | AI matching | Rank real listing records and explain the matches |
| P0 | User profiles | Short profile with skills, interests, location, and needs |
| P0 | Create listing | Post an offer or request through a form |
| P0 | Connection action | Save a listing or submit an inquiry |
| P1 | Personalization | Use selected interests and saved opportunities to adjust ranking |
| P1 | Community affiliation | Let users optionally select a participating masjid or organization |
| P2 | LinkedIn integration | Defer real OAuth integration; offer manual entry or a profile URL |

P0 features are the definition of done. P1 is worth attempting only after the complete P0 flow works. P2 should not block the submission.

For a one-day build, the best trade-off is a working matching algorithm over well-designed sample data, not a sophisticated interface over nonfunctional buttons.

### 4. Several directions you could implement

All of the following fit the broader concept. They can also become separate modules later.

Idea A — The local opportunity marketplace

Recommended MVP

Members publish things they offer and things they need. Others discover services, job opportunities, mentors, collaborators, and local businesses. AI helps prioritize what each member should see.

Why build it: It solves the broadest part of your stated problem, demonstrates tangible utility, and can grow into a venture.

Idea B — Ask the Muslim community

A single search box asks, “What are you trying to accomplish?” The system interprets the request and recommends people, services, and opportunities.

Why build it: This creates the clearest live AI demonstration. It works particularly well as the central search experience inside Idea A.

Idea C — Skills and services exchange

One member offers graphic design; another offers tutoring; someone else needs bookkeeping or home repairs. Listings can include paid services, free assistance, volunteering, or barter.

Why build it: It gives the marketplace an immediate, practical purpose. You can start with only “I offer” and “I need” listing types.

Idea D — Muslim career and mentorship network

Students discover professionals in their intended fields, request mentorship, and find internships, projects, and entry-level opportunities.

Why build it: It has a clear user group and a clear outcome. The disadvantage is that it narrows the platform's initial audience.

Idea E — A masjid community hub

Each participating organization has a community page with local opportunities, service listings, announcements, events, and volunteering needs.

Why build it: It creates a distribution channel through existing communities and allows the product to grow organization by organization. It also provides a possible route into the Masjid App Challenge described below.

Idea F — Personalized opportunity discovery

The system learns from a member's stated interests, saved listings, and explicit interactions to tailor their feed over time.

Why build it: It supports repeat usage and differentiation. For the initial demo, use straightforward feedback signals rather than training a recommendation model from scratch.

My recommendation: Combine A, B, and a small piece of F. Make E a lightweight organizational feature only if it helps you enter the Masjid App Challenge. Add career opportunities and services as listing categories rather than separate products.

#### The Masjid App Challenge decision

The official challenge specifically describes an app for the Muslim Center of Greater Princeton (MCGP), including prayer times, events, announcements, RSVPs, and room or desk bookings, with mock data permitted and organizations configured so the app can expand without code changes. 
MC² Summit Hackathon

Your current concept does not fully satisfy that challenge as written. To make a credible entry, you would need an MCGP community home page with at least an announcements or events feed and a usable participation action, alongside the marketplace. Otherwise, treat the marketplace as a general venture submission, which is eligible for the open awards without entering a pitched challenge.

### 5. The AI should do real work, but stay predictable

The AI is a product feature, not a decoration. The ideal implementation uses AI to understand the user's request and conventional code to rank the marketplace listings.

I recommend a four-stage matching pipeline.

#### Stage 1: Understand the user

During onboarding, ask a few short, conversational questions:

- What skills, knowledge, or services can you offer?
- What opportunities, services, or connections are you looking for?
- What fields or activities interest you?
- What area of Central Jersey should we prioritize?

Allow users to answer in plain English. For example:

I'm a Rutgers student studying engineering. I know some Python and enjoy robotics. I'm looking for engineering internships, project teammates, and professionals willing to mentor students.

An AI model could convert this into a structured representation:

```json
{
  "skills": ["Python", "engineering"],
  "interests": ["robotics", "embedded systems"],
  "seeking": [
    "engineering internships",
    "project teammates",
    "mentorship"
  ],
  "offering": [],
  "location_preference": "Central Jersey"
}
```

The AI should extract information, not invent qualifications. Users should be able to edit the resulting profile before using it.

#### Stage 2: Understand each listing

Every listing should have standardized fields, even if the person writes its description in natural language.

For example:

Listing: Volunteer robotics mentor needed

Description: A local youth group needs a volunteer to help middle-school students learn basic robotics and Python.

Structured attributes: Mentorship, volunteering, robotics, Python, education, Central Jersey.

This can be handled with a short form supplemented by AI-assisted categorization. For the hackathon, manually entering several well-designed sample listings is sufficient to demonstrate it.

#### Stage 3: Rank the most relevant listings

Use a hybrid algorithm: structured filters and scoring, supported by AI-based intent extraction.

A simple initial scoring model could be:

| Matching factor | Weight |
| --- | --- |
| Match between the user's goal and listing type | 30% |
| Relevant skills and interests | 25% |
| Relevance of the listing's description to the request | 25% |
| Geographic suitability | 10% |
| Recency of the listing | 5% |
| Previously expressed preferences | 5% |
| Total | 100% |

These are initial design weights, not empirically validated values. Tune them using test cases and feedback.

The system should first exclude inactive or clearly ineligible listings, then rank the remaining candidates. Location can be treated as a preference rather than a strict filter when the user is open to remote opportunities.

For a one-day implementation, description relevance can be approximated with normalized keywords and tags, or with embeddings if your chosen platform already supports them. Do not build a complicated vector-search infrastructure unless the simpler version is already finished.

#### Stage 4: Explain each recommendation

Every match should include a short, evidence-based explanation.

For example:

Why this matches: You are interested in robotics, and this mentor offers experience in robotics education. The opportunity is in your preferred area and is open to volunteers.

Explanations must use information actually present in the profile and listing. If no suitable listings exist, the system should say so and let the user broaden their search.

#### What about learning from user behavior?

Your personalization idea is valuable, but implement it in stages.

For the hackathon: Explicitly stated interests, saved listings, and contact requests.

These signals are relatively easy to store and interpret.

For a later version: Recommendations that adapt to repeated clicks, completed connections, successful hires, and other outcomes.

These require enough usage data to distinguish genuine interest from accidental clicks.

Do not train a recommendation model from scratch. At launch, there will be very little behavioral data. A combination of declared preferences, structured metadata, and transparent ranking is more appropriate.

### 6. Data structure for the application

A clear data model will help your coding agent create consistent features instead of repeatedly inventing different representations of the same information.

For a real multi-user product, these are the core entities.

#### User profile
```text
Profile
- id
- display_name
- short_bio
- skills[]
- interests[]
- offering_summary
- seeking_summary
- city_or_area
- preferred_categories[]
- community_affiliations[]
- linkedin_url (optional)
- visibility
- created_at
```
#### Marketplace listing
```text
Listing
- id
- owner_id
- title
- description
- listing_type
- direction
- category
- tags[]
- location
- remote_available
- compensation_type (optional)
- status
- created_at
```

Suggested listing_type values:

service, job, internship, mentorship, collaboration, volunteer, business.

Use direction to distinguish an offer from a request. A job posting and someone seeking a job are different kinds of intent and should not be treated as identical records.

#### Connection request
```text
ConnectionRequest
- id
- sender_id
- recipient_id
- listing_id
- message
- status
- created_at
```

Statuses can be pending, accepted, or declined.

For the hackathon, these three entities are enough to demonstrate the central product. Saved listings can be a small additional table or collection. Detailed organization administration, payment systems, verification workflows, and extensive messaging infrastructure can wait.

Demo data: Create fictional profiles and listings across a handful of Central Jersey locations. Label them as sample data and do not fabricate actual masjid partnerships, real job openings, or endorsements from real community members.

For production, require explicit opt-in to profile visibility, give users control over their displayed information, and provide a way to remove a listing or profile.

LinkedIn is best treated as an optional profile reference at first. A pasted URL or a user-entered summary is much easier to support in one day than a genuine LinkedIn OAuth integration. Do not scrape profiles or imply that an integration exists when it does not.

### 7. Copy-ready prompts for your AI coding tool

I could not confidently identify which development tool you mean by “Flytter,” so the prompts below are framework- and platform-neutral. They are designed to work as staged instructions in the coding agent you use.

Do not paste all of them at once. Have the tool build and verify one stage before proceeding to the next.

#### Prompt 1 — Establish the project and scope

We are building Muslim Marketplace, a Central Jersey community opportunity marketplace, during a short hackathon.

PRODUCT GOAL

Help Muslims discover useful skills, services, job and internship opportunities, mentors, collaborators, volunteer opportunities, and local businesses within their community. Many people attend the same masjid but do not know what skills or services others can offer. We want to make these opportunities discoverable and actionable.

This is a marketplace, not a conventional professional social network. Its core objects are user profiles and marketplace listings.

CORE USER FLOW

1. A user enters a short natural-language description of their skills, interests, and goals.
2. The application extracts structured preferences.
3. The home page displays relevant marketplace listings in ranked order.
4. Each recommendation includes a short explanation grounded in actual profile and listing data.
5. Users can view a listing, save it, create their own listing, or submit a connection request.

SCOPE

The first version must provide:

- A clean, responsive marketplace homepage.
- Search using natural language.
- Listing cards and detail views.
- Categories for services, jobs, internships, mentorship, collaboration, volunteering, and businesses.
- User profiles and a simple create-listing form.
- Matching results with explanations.
- A working save or connection-request interaction.
- Fictional sample profiles and listings relevant to Central Jersey.

CONSTRAINTS

- This is a one-day build by a team of four, with two members more comfortable using AI coding tools.
- Prioritize a working end-to-end demonstration over feature quantity.
- Use the existing project framework and available backend capabilities wherever possible.
- Do not introduce unnecessary infrastructure or rewrite a working application.
- Do not scrape LinkedIn or claim that OAuth, live messaging, or external integrations work unless they have actually been implemented.
- Use clearly labeled fictional sample data.
- Avoid dead buttons, invented businesses, fake partnerships, and fabricated testimonials.
- Make the application usable on both desktop and mobile.

Before implementing, inspect the existing project, identify the current framework and available data services, and propose the smallest viable implementation plan. Then begin implementing incrementally. Keep existing working features intact and report any blockers clearly.

#### Prompt 2 — Build the UI and marketplace

Implement the core Muslim Marketplace interface using the existing project and design system.

DESIGN DIRECTION

Create a polished, modern, trustworthy community marketplace. Use a restrained color palette, strong typography, clear hierarchy, consistent spacing, and responsive layouts. The interface should feel like a usable local service and opportunity platform rather than a social media feed.

HOMEPAGE

Include:

- A clear title and concise statement of the product's purpose.
- A prominent natural-language search field with a prompt such as "What are you looking for in your community?"
- Quick actions for "Find a service", "Find a mentor", "Explore jobs", and "Post an opportunity".
- A personalized "Recommended for you" section.
- Browsable categories and a location control.
- Listing cards with title, description, category, location, relevant tags, and a clear action.
- A brief explanation of why each recommended listing matches the user.

LISTING TYPES

Support services, jobs, internships, mentorship, collaboration, volunteering, and businesses. Distinguish people offering something from people seeking something.

FUNCTIONAL REQUIREMENTS

- Search must change the displayed results.
- Category and location filters must work.
- Listing cards must open relevant details.
- Users must be able to submit the create-listing form.
- Saving or requesting contact must produce a real state change and visible confirmation.
- Provide a simple onboarding/profile-editing experience.
- Include a useful empty state when no listings match.
- Include demo data so the interface works immediately without requiring a new user to create content.

Do not build every possible feature. Finish the complete core flow first, then refine spacing, responsive behavior, accessibility, loading states, and error messages. Test each interaction after implementation.

#### Prompt 3 — Implement matching

Implement the recommendation engine for Muslim Marketplace within the existing application architecture.

REQUIREMENTS

1. Accept a user's natural-language request or structured profile preferences.
2. If an AI API is available and configured, use it to convert free text into structured fields such as intent, listing types, relevant skills, interests, keywords, and location preference.
3. Validate the extracted structure and never invent a user's skills, qualifications, budget, or location.
4. Filter out inactive listings and listings that fail essential user constraints.
5. Rank eligible listings with a transparent hybrid scoring algorithm using:
   - Intent/listing-type fit: 30%
   - Skills and interests: 25%
   - Description relevance: 25%
   - Geographic suitability: 10%
   - Listing recency: 5%
   - Previously expressed preferences: 5%
6. Return ranked listing records and a short reason for each recommendation.
7. Explanations must be derived from actual fields and matching signals, not unsupported claims.
8. If no suitable match exists, explain this and offer broader search options.

For a hackathon-scale implementation, use structured tag overlap and text relevance or existing embedding capabilities; do not introduce a large vector database solely for this feature. Provide a deterministic fallback if the AI API is unavailable or returns invalid output. The app must still produce valid results with the included seed data.

Keep scoring logic separate from UI rendering. Add test cases for a strong match, a weak match, a location mismatch, an inactive listing, and an empty result set. Document the ranking method so the team can explain it during judging.

#### Prompt 4 — Finish, test, and prepare the submission

Perform a full quality pass on Muslim Marketplace, focusing on hackathon readiness.

TEST THE END-TO-END FLOW

1. Open the application with sample data.
2. Submit a natural-language request.
3. Verify that relevant listings appear in a sensible order.
4. Verify that each match explanation is supported by actual listing data.
5. Open a listing and submit a connection request.
6. Create a listing and verify that it appears in the marketplace.
7. Save a listing and verify the saved state.
8. Test filters, empty states, form validation, mobile layouts, refresh behavior, and API failure handling.

FIX BROKEN BEHAVIOR before adding more features. Identify and remove dead controls, misleading labels, duplicate records, console errors, and unnecessary setup steps.

REPOSITORY AND DOCUMENTATION

Create or update a README explaining:

- The problem and intended users.
- The product's core features.
- How the matching algorithm works.
- The technology stack and architecture.
- How to configure required environment variables.
- How to run the application from a fresh setup.
- Which integrations are real and which are mocked.
- Known limitations and future improvements.

Keep API keys on the server or in the platform's secret-management system; do not expose them in client code or commit them to GitHub. Use clearly marked fictional demo data.

Finish with a concise list of completed functionality, unresolved bugs, and the most reliable end-to-end demonstration sequence. Do not claim a test passed unless you actually ran it.

### 8. The application architecture I would use

Keep the architecture as small as possible.

Frontend

Onboarding · Marketplace feed · Search · Listing details · Profile

Application logic

Search parsing · Filters · Ranking · Recommendation explanations

Data and AI

Profiles · Listings · Connection requests · Optional LLM API

Use the database and deployment capabilities your existing builder makes easiest to configure. A managed backend is preferable if your team can connect it quickly; otherwise, use seeded data and a local demo state as a temporary fallback.

For a public startup, the application will eventually need persistent server-side storage, authentication, access controls, and protected messaging. Do not represent a browser-only prototype as a production-ready multi-user service.

A few implementation choices matter:

- Keep listing data separate from profiles. One person can have multiple offers and needs.
- Keep matching logic separate from the interface. This makes the algorithm testable and easier to improve.
- Use one canonical set of categories and tags. Otherwise, different components will use inconsistent names for equivalent opportunities.
- Use a reliable fallback. A failed AI API call must not blank the homepage or prevent browsing.
- Avoid building authentication from scratch. Use your builder's existing auth capabilities only if they are quick to integrate; otherwise, keep the demo experience simple and restrict sensitive actions appropriately.

#### A possible future extension

The long-term advantage could be a community recommendation system that connects local supply and demand. When someone posts that they need a tutor, the service could identify relevant tutors; when a business posts an internship, the system could show it to students interested in that field.

Over time, successful introductions and user feedback could improve relevance. That is a more defensible product direction than adding an AI chatbot to a static directory.

### 9. How the product could grow beyond the hackathon

You do not have to commit to a single revenue model now. The startup hypothesis is that local communities need better ways to share opportunities, while masjids and community organizations can become trusted distribution channels.

| Potential future feature | Value |
| --- | --- |
| Organization-specific pages | Each participating masjid can maintain a community opportunity board |
| Verified business profiles | Greater trust in service providers and employers |
| More sophisticated recommendations | Better relevance as profiles and listing data grow |
| Career and mentorship pathways | Helps students and early-career professionals access guidance |
| Community administration | Allows organizations to moderate listings and manage announcements |
| Organization subscriptions | A possible revenue source for administrative tools |
| Featured business listings | A possible revenue source, provided paid placement is clearly labeled |

I would begin with a free core experience. Paid organization tools or clearly labeled promotions could be tested later, but charging users before the marketplace has enough useful listings would make adoption harder.

Your most difficult long-term problem is likely to be marketplace liquidity: having enough useful listings and enough people responding to them. AI can improve discovery, but it cannot manufacture genuine opportunities or trustworthy connections. Starting with a small number of participating communities and seeding the platform with useful, legitimate listings is more realistic than launching everywhere in Central Jersey at once.

### 10. What the four-person team should do

The official judging rubric assesses technicality, originality, practicality, aesthetics, and wow factor. The strongest build demonstrates these together: a working application, an identifiable need, a clear user experience, and one memorable technical feature. 
East Windsor, NJ

I would divide responsibilities as follows.

Person 1 — Technical lead

Owns the main application, architecture, integration, and final decisions. Keeps the scope fixed and ensures that the team always has a working build.

Person 2 — AI and matching

Implements natural-language parsing, ranking, explanations, and fallback behavior. Tests the matching logic against realistic requests.

Person 3 — Product and user experience

Refines the screens, listing categories, onboarding, mobile interface, and sample listings. Can build designs or separate components without interfering with the core application.

Person 4 — Validation, testing, and pitch

Talks to prospective users, records their feedback, builds realistic demo data, tests the complete user journey, prepares the README and submission, and rehearses the pitch.

Since two people have more experience with AI coding tools, avoid having all four independently prompt the same application. That tends to create conflicting changes and duplicate components. Give each person a defined task and let one technical lead control integration.

#### Validate the idea before polishing it

The official Best User Insight award explicitly values evidence from real people and concrete changes made in response to their feedback. 
MC² Summit Hackathon

Ask three to five attendees at the hackathon or people who know the local Muslim community:

1. When have you needed a service, mentor, job connection, or professional contact that you suspected someone in the community could provide?
2. How did you find that person, and what made it difficult?
3. Would you be more likely to use a searchable directory, a personalized feed, or a natural-language search?
4. What would make you trust a listing or feel comfortable contacting its owner?

Take notes. If their answers reveal that one category—for example, local services or student internships—is far more urgent than the others, prioritize that category in the demo. Record what you learned and what you changed; do not invent interview results for the pitch.

### 11. A realistic schedule for the remaining build time

The published schedule has a Saturday checkpoint at 4:00 PM, a Sunday build session beginning at 9:45 AM, submissions closing at 1:00 PM, and live demos starting at 2:00 PM. Each team's demo slot is ten minutes, with about five minutes for the presentation and three minutes for questions. 
MC² Summit Hackathon

#### Today

Saturday

Now to 4:00 PM — Freeze the design

Agree on the MVP, prepare the listing data model, create the key screen, and define how matching will work. Get a complete end-to-end path started before the checkpoint.

4:00–4:30 PM — Demonstrate progress

Show the working part, identify blockers, and decide what must be completed first tomorrow. Avoid starting a major additional feature.

#### Sunday

9 AM

9:00–10:30 AM — Complete the core flow

Finish the feed, listing details, search, basic ranking, and connection action.

10:30–11:15 AM — Improve matching

Test several different requests, tune the rankings, and ensure the explanations reflect actual listing data.

11:15 AM–12:00 PM — Stabilize

Test the app on a fresh session, verify forms and filters, fix the highest-impact bugs, and confirm the demo data is ready.

12:00–12:30 PM — Prepare the submission

Finish the README, screenshots, project story, repository, and demo sequence.

By 12:30 PM — Internal cutoff

Aim to have the submission ready 30 minutes before the published 1:00 PM deadline.

#### Demo

Sunday

1:00 PM — Submission closes

1:15 PM — Rehearse

Test the exact device, data, and flow you will use, and prepare concise answers about the algorithm, user privacy, and business model.

2:00 PM — Working-product demos

Show the working product rather than relying on slides.

### 12. The five-minute demonstration

Build the demo around one user story rather than presenting every feature.

1

Introduce the problem — 30 seconds

People attend the same masjids but often do not know which services, skills, jobs, and professional opportunities exist within their community.

2

Enter a natural-language request — 45 seconds

Demonstrate a fictional student describing their background and asking for a robotics mentor and an engineering internship in Central Jersey.

3

Show AI-assisted matching — 90 seconds

Show the ranked listings, explain why the top recommendations were selected, and contrast a highly relevant match with a less relevant one.

4

Complete a transaction-like action — 60 seconds

Open a listing, submit a connection request, or post a new opportunity and demonstrate the updated state.

5

Explain why it can grow — 45 seconds

Explain how participating masjids and organizations could create useful local listings, bring in members, and make the opportunity feed more relevant.

Keep the remaining time for transitions or technical questions. The presentation must reflect what the application actually does today.

The single most important visual moment is the transition from a vague human request to a ranked set of useful opportunities with clear reasons for each match. That is the feature most likely to make the product immediately understandable.

#### Prepare the repository as part of the product

The hackathon's Best Use of GitHub award specifically looks for a useful README, a meaningful commit history, branches or pull requests, issue tracking, and optionally automated testing or deployment. 
MC² Summit Hackathon

Create a public repository, make regular commits as the application takes shape, document how to run it from a fresh setup, and avoid committing API keys. With four teammates, a small task board and a clear division of files are enough; complicated engineering process is unnecessary.

### 13. Decisions to lock before you continue coding

These are the remaining decisions that will materially affect the build.

| Decision | My recommendation |
| --- | --- |
| Initial market | Members and attendees of participating Central Jersey masjids |
| Primary value | Discover a relevant service or opportunity that you did not know existed |
| Initial use cases | Local services and professional opportunities, including jobs and mentorship |
| Content model | Separate user profiles from individual offers and requests |
| Onboarding | Short, conversational profile setup that users can edit |
| Recommendation engine | Structured AI extraction plus explainable scoring |
| Contact model | A connection-request action with a clear confirmation |
| LinkedIn | Manual profile entry or optional URL; real integration later |
| Community trust | Opt-in listings, profile visibility controls, reporting and moderation as the product matures |
| Expansion | Add participating masjids and organization-specific pages over time |

One particularly important question is whether each listing should belong to a particular masjid. I recommend making affiliation optional and separate from the user's profile visibility. That allows the platform to serve the wider Central Jersey Muslim community without requiring every person to belong to a specific organization.

Also decide how the platform distinguishes verified organizations from unverified users. For the prototype, display fictional demo listings clearly. For real deployment, introduce an appropriate verification process before advertising listings as verified.

### 14. What I would not build this weekend

Do not spend your limited time on real LinkedIn OAuth, a complex social graph, sophisticated recommendation-model training, payments, native mobile apps, extensive chat infrastructure, or automated onboarding of every masjid.

Those are plausible future features. None is necessary to prove the central idea.

The most important unknown is not whether you can implement AI matching; it is whether a sufficiently useful local marketplace can attract both people posting opportunities and people acting on them. Use your interviews to test that hypothesis.

Your product should be able to demonstrate three things clearly:

1. A user has a genuine need or something useful to offer.
2. The marketplace discovers relevant listings that the user would otherwise have missed.
3. The user can take a concrete step toward making the connection.

That is the version I would build first. It preserves the larger vision of a Muslim community marketplace while giving your team a realistic, demonstrable product within the hackathon constraints.

Would you like a ChatGPT reminder tomorrow morning to check the final build, repository, and submission before the 1:00 PM deadline?

If you want, I can:

- Expand on priority feature plan for the hackathon
- Outline AI matching approach in detail
- Suggest a stepwise development roadmap for the team

---

