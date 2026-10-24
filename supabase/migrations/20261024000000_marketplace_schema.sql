-- Muslim Marketplace: connected-mode schema.
--
-- Authorization lives here, not in the app: row-level security limits every
-- read and write to the signed-in member, and state transitions that involve
-- two people (requests, conversations) happen only through the
-- security-definer functions at the end of this file.

-- ---------------------------------------------------------------------------
-- Tables

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 60),
  headline text not null default '' check (char_length(headline) <= 140),
  skills text[] not null default '{}' check (cardinality(skills) <= 30),
  interests text[] not null default '{}' check (cardinality(interests) <= 30),
  offering_summary text not null default '' check (char_length(offering_summary) <= 1000),
  seeking_summary text not null default '' check (char_length(seeking_summary) <= 1000),
  area_id text,
  open_to_remote boolean not null default true,
  -- Self-reported; never implies verification or endorsement.
  community_affiliation text check (char_length(community_affiliation) <= 120),
  -- A link the member chose to share; nothing is imported.
  linkedin_url text check (
    linkedin_url is null
    or linkedin_url ~* '^https://([a-z0-9-]+\.)?linkedin\.com/in/[^/]+'
  ),
  -- Opt-in member directory. Off until the member turns it on.
  directory_visible boolean not null default false,
  is_sample boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Public-facing member fields. Readable by the owner, and by signed-in members only when directory_visible.';

-- Private per-member settings, never readable by others.
create table public.profile_settings (
  id uuid primary key references public.profiles (id) on delete cascade,
  goals jsonb not null default '[]'::jsonb check (jsonb_typeof(goals) = 'array'),
  personalization_enabled boolean not null default true,
  onboarding_complete boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 5 and 90),
  description text not null check (char_length(btrim(description)) between 20 and 2000),
  listing_type text not null check (
    listing_type in ('service', 'job', 'internship', 'mentorship', 'collaboration', 'volunteer', 'business')
  ),
  direction text not null check (direction in ('offer', 'request')),
  category text not null check (
    category in ('education', 'technology', 'engineering', 'business', 'careers', 'creative',
                 'health', 'home', 'food', 'community', 'other')
  ),
  tags text[] not null default '{}' check (cardinality(tags) <= 8),
  area_id text,
  remote_available boolean not null default false,
  compensation_type text check (
    compensation_type in ('paid', 'stipend', 'unpaid', 'volunteer', 'free', 'negotiable')
  ),
  compensation_details text check (char_length(compensation_details) <= 80),
  status text not null default 'active' check (status in ('active', 'paused', 'closed')),
  is_sample boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  -- A business entry is posted by the business: always an offer.
  constraint business_is_offer check (listing_type <> 'business' or direction = 'offer'),
  constraint has_location check (area_id is not null or remote_available)
);

create index listings_status_created_idx on public.listings (status, created_at desc);
create index listings_owner_idx on public.listings (owner_id);

create table public.saved_listings (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  listing_id uuid not null references public.listings (id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table public.connection_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  -- 'listing' requests concern a listing (set null if it is deleted);
  -- 'introduction' requests go to a directory member directly.
  kind text not null check (kind in ('listing', 'introduction')),
  listing_id uuid references public.listings (id) on delete set null,
  listing_title text,
  message text not null check (char_length(btrim(message)) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'withdrawn')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint not_self check (sender_id <> recipient_id),
  constraint listing_kind_has_listing check (kind = 'introduction' or listing_title is not null)
);

-- At most one open request per sender and listing, or per sender and
-- recipient for introductions.
create unique index connection_requests_one_open_per_listing
  on public.connection_requests (sender_id, listing_id)
  where status in ('pending', 'accepted') and kind = 'listing' and listing_id is not null;
create unique index connection_requests_one_open_intro
  on public.connection_requests (sender_id, recipient_id)
  where status in ('pending', 'accepted') and kind = 'introduction';
create index connection_requests_recipient_idx on public.connection_requests (recipient_id, created_at desc);
create index connection_requests_sender_idx on public.connection_requests (sender_id, created_at desc);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.connection_requests (id) on delete cascade,
  participant_a uuid not null references public.profiles (id) on delete cascade,
  participant_b uuid not null references public.profiles (id) on delete cascade,
  listing_id uuid references public.listings (id) on delete set null,
  listing_title text,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  last_message_preview text,
  last_message_sender_id uuid,
  constraint distinct_participants check (participant_a <> participant_b)
);

create index conversations_a_idx on public.conversations (participant_a);
create index conversations_b_idx on public.conversations (participant_b);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  -- Generated by the sending client so retries are idempotent.
  client_id uuid not null,
  created_at timestamptz not null default now(),
  unique (sender_id, client_id)
);

create index messages_conversation_created_idx on public.messages (conversation_id, created_at);

-- Recommendation feedback. Each event_type has one meaning:
--   viewed             opened a listing's details (small, capped influence)
--   saved / unsaved    saved or un-saved a listing
--   contact_requested  sent a connection request about a listing (interest
--                      only; not an application, hire or acceptance)
--   dismissed          chose "show less like this"
-- Facets are snapshotted so preferences remain explainable.
create table public.recommendation_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  listing_id uuid not null,
  event_type text not null check (
    event_type in ('viewed', 'saved', 'unsaved', 'contact_requested', 'dismissed')
  ),
  listing_type text not null,
  category text not null,
  tags text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index recommendation_events_user_idx on public.recommendation_events (user_id, created_at);

-- ---------------------------------------------------------------------------
-- Triggers

create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger profile_settings_updated_at before update on public.profile_settings
  for each row execute function public.set_updated_at();
create trigger listings_updated_at before update on public.listings
  for each row execute function public.set_updated_at();

-- Every new account gets a profile and private settings.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 60));
  insert into public.profile_settings (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Members cannot change identity or sample flags on their own profile.
create function public.protect_profile_fields() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null then
    new.id := old.id;
    new.is_sample := old.is_sample;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

create trigger profiles_protect before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- New listings from members start active and are never samples.
create function public.prepare_new_listing() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null then
    new.owner_id := (select auth.uid());
    new.status := 'active';
    new.is_sample := false;
    new.created_at := now();
    new.closed_at := null;
  end if;
  return new;
end;
$$;

create trigger listings_prepare before insert on public.listings
  for each row execute function public.prepare_new_listing();

-- Valid listing status transitions (mirrors ListingStatus.canTransitionTo):
--   active -> paused | closed, paused -> active | closed; closed is final.
create function public.enforce_listing_rules() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.owner_id := old.owner_id;
  new.is_sample := old.is_sample;
  new.created_at := old.created_at;
  if old.status = 'closed' then
    raise exception 'Closed listings can no longer be changed.'
      using errcode = 'P0001', hint = 'invalid_transition';
  end if;
  if new.status <> old.status then
    if not ((old.status = 'active' and new.status in ('paused', 'closed'))
         or (old.status = 'paused' and new.status in ('active', 'closed'))) then
      raise exception 'That status change is not allowed.'
        using errcode = 'P0001', hint = 'invalid_transition';
    end if;
    if new.status = 'closed' then
      new.closed_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger listings_rules before update on public.listings
  for each row execute function public.enforce_listing_rules();

-- Keep the conversation list ordered and previewed.
create function public.touch_conversation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations
     set last_message_at = new.created_at,
         last_message_preview = left(new.body, 120),
         last_message_sender_id = new.sender_id
   where id = new.conversation_id;
  return new;
end;
$$;

create trigger messages_touch_conversation after insert on public.messages
  for each row execute function public.touch_conversation();

-- ---------------------------------------------------------------------------
-- Helpers

create function public.is_conversation_participant(p_conversation_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversations c
     where c.id = p_conversation_id
       and (select auth.uid()) in (c.participant_a, c.participant_b)
  );
$$;

-- ---------------------------------------------------------------------------
-- Row-level security

alter table public.profiles enable row level security;
alter table public.profile_settings enable row level security;
alter table public.listings enable row level security;
alter table public.saved_listings enable row level security;
alter table public.connection_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.recommendation_events enable row level security;

-- Profiles: your own, or members who opted into the directory.
create policy "profiles_select_own_or_directory" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or directory_visible);
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Settings: owner only.
create policy "settings_select_own" on public.profile_settings
  for select to authenticated using (id = (select auth.uid()));
create policy "settings_update_own" on public.profile_settings
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Listings: active ones, your own, and ones you have a request about.
create policy "listings_select_visible" on public.listings
  for select to authenticated
  using (
    status = 'active'
    or owner_id = (select auth.uid())
    or exists (
      select 1 from public.connection_requests r
       where r.listing_id = listings.id
         and (select auth.uid()) in (r.sender_id, r.recipient_id)
    )
  );
create policy "listings_insert_own" on public.listings
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "listings_update_own" on public.listings
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "listings_delete_own" on public.listings
  for delete to authenticated using (owner_id = (select auth.uid()));

-- Saved listings: owner only, and only listings you can see.
create policy "saved_select_own" on public.saved_listings
  for select to authenticated using (user_id = (select auth.uid()));
create policy "saved_insert_own" on public.saved_listings
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.listings l where l.id = listing_id)
  );
create policy "saved_delete_own" on public.saved_listings
  for delete to authenticated using (user_id = (select auth.uid()));

-- Requests: readable by sender and recipient. No direct writes; use the
-- functions below so roles and transitions are enforced.
create policy "requests_select_participants" on public.connection_requests
  for select to authenticated
  using ((select auth.uid()) in (sender_id, recipient_id));

-- Conversations: participants only. Created by respond_to_connection_request.
create policy "conversations_select_participants" on public.conversations
  for select to authenticated
  using ((select auth.uid()) in (participant_a, participant_b));

-- Messages: participants read and send as themselves. No edits or deletes.
create policy "messages_select_participants" on public.messages
  for select to authenticated
  using (public.is_conversation_participant(conversation_id));
create policy "messages_insert_participants" on public.messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and public.is_conversation_participant(conversation_id)
  );

-- Events: owner only; recording requires personalization to be on.
create policy "events_select_own" on public.recommendation_events
  for select to authenticated using (user_id = (select auth.uid()));
create policy "events_insert_own" on public.recommendation_events
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.profile_settings s
       where s.id = (select auth.uid()) and s.personalization_enabled
    )
  );
create policy "events_delete_own" on public.recommendation_events
  for delete to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Functions for two-party actions

-- Sends a request about an active listing (to its owner) or, with no
-- listing, an introduction to a member who is in the directory.
create function public.send_connection_request(
  p_recipient_id uuid,
  p_listing_id uuid,
  p_message text
) returns public.connection_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := (select auth.uid());
  v_listing public.listings;
  v_recipient public.profiles;
  v_row public.connection_requests;
begin
  if v_me is null then
    raise exception 'Please sign in.' using errcode = 'P0001', hint = 'not_allowed';
  end if;
  if p_recipient_id = v_me then
    raise exception 'You can''t send a request to yourself.' using errcode = 'P0001', hint = 'not_allowed';
  end if;
  select * into v_recipient from public.profiles where id = p_recipient_id;
  if not found then
    raise exception 'We couldn''t find that member.' using errcode = 'P0001', hint = 'not_found';
  end if;
  if p_listing_id is not null then
    select * into v_listing from public.listings where id = p_listing_id;
    if not found then
      raise exception 'We couldn''t find that listing.' using errcode = 'P0001', hint = 'not_found';
    end if;
    if v_listing.status <> 'active' then
      raise exception 'This listing is no longer accepting requests.'
        using errcode = 'P0001', hint = 'invalid_transition';
    end if;
    if v_listing.owner_id <> p_recipient_id then
      raise exception 'Requests about a listing go to its owner.' using errcode = 'P0001', hint = 'not_allowed';
    end if;
  elsif not v_recipient.directory_visible then
    raise exception 'This member is not accepting introductions.' using errcode = 'P0001', hint = 'not_allowed';
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 1 and 1000 then
    raise exception 'Add a short message (up to 1,000 characters).' using errcode = 'P0001', hint = 'validation';
  end if;

  begin
    insert into public.connection_requests (sender_id, recipient_id, kind, listing_id, listing_title, message)
    values (
      v_me,
      p_recipient_id,
      case when p_listing_id is null then 'introduction' else 'listing' end,
      p_listing_id,
      v_listing.title,
      btrim(p_message)
    )
    returning * into v_row;
  exception when unique_violation then
    raise exception 'You already have an open request for this.' using errcode = 'P0001', hint = 'conflict';
  end;
  return v_row;
end;
$$;

-- Recipient accepts or declines a pending request. Accepting opens the
-- private conversation. Returns the request and the conversation id.
create function public.respond_to_connection_request(p_request_id uuid, p_accept boolean)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := (select auth.uid());
  v_req public.connection_requests;
  v_conversation_id uuid;
begin
  select * into v_req from public.connection_requests where id = p_request_id for update;
  if not found or v_me is null or v_me not in (v_req.sender_id, v_req.recipient_id) then
    raise exception 'We couldn''t find that request.' using errcode = 'P0001', hint = 'not_found';
  end if;
  if v_req.recipient_id <> v_me then
    raise exception 'Only the person who received this request can respond.'
      using errcode = 'P0001', hint = 'not_allowed';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'This request has already been answered.' using errcode = 'P0001', hint = 'invalid_transition';
  end if;

  update public.connection_requests
     set status = case when p_accept then 'accepted' else 'declined' end,
         responded_at = now()
   where id = p_request_id
   returning * into v_req;

  if p_accept then
    insert into public.conversations (request_id, participant_a, participant_b, listing_id, listing_title)
    values (v_req.id, v_req.sender_id, v_req.recipient_id, v_req.listing_id, v_req.listing_title)
    returning id into v_conversation_id;
  end if;

  return jsonb_build_object('request', to_jsonb(v_req), 'conversation_id', v_conversation_id);
end;
$$;

-- Sender withdraws a pending request.
create function public.withdraw_connection_request(p_request_id uuid)
returns public.connection_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := (select auth.uid());
  v_req public.connection_requests;
begin
  select * into v_req from public.connection_requests where id = p_request_id for update;
  if not found or v_me is null or v_me not in (v_req.sender_id, v_req.recipient_id) then
    raise exception 'We couldn''t find that request.' using errcode = 'P0001', hint = 'not_found';
  end if;
  if v_req.sender_id <> v_me or v_req.status <> 'pending' then
    raise exception 'Only pending requests you sent can be withdrawn.'
      using errcode = 'P0001', hint = 'invalid_transition';
  end if;
  update public.connection_requests
     set status = 'withdrawn', responded_at = now()
   where id = p_request_id
   returning * into v_req;
  return v_req;
end;
$$;

-- Names for listing owners, request counterparts and directory members;
-- directory details only for members who opted in.
create function public.get_member_cards(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  is_sample boolean,
  directory_visible boolean,
  headline text,
  skills text[],
  interests text[],
  offering_summary text,
  seeking_summary text,
  area_id text,
  community_affiliation text,
  linkedin_url text
)
language sql stable security definer set search_path = '' as $$
  select p.id,
         p.display_name,
         p.is_sample,
         p.directory_visible,
         case when p.directory_visible then p.headline end,
         case when p.directory_visible then p.skills end,
         case when p.directory_visible then p.interests end,
         case when p.directory_visible then p.offering_summary end,
         case when p.directory_visible then p.seeking_summary end,
         case when p.directory_visible then p.area_id end,
         case when p.directory_visible then p.community_affiliation end,
         case when p.directory_visible then p.linkedin_url end
    from public.profiles p
   where p.id = any (p_ids)
     and (select auth.uid()) is not null
     and (
       p.id = (select auth.uid())
       or p.directory_visible
       or exists (select 1 from public.listings l where l.owner_id = p.id and l.status = 'active')
       or exists (
         select 1 from public.connection_requests r
          where (r.sender_id = (select auth.uid()) and r.recipient_id = p.id)
             or (r.recipient_id = (select auth.uid()) and r.sender_id = p.id)
       )
     );
$$;

-- Only signed-in members may call these.
revoke execute on function public.send_connection_request(uuid, uuid, text) from public, anon;
revoke execute on function public.respond_to_connection_request(uuid, boolean) from public, anon;
revoke execute on function public.withdraw_connection_request(uuid) from public, anon;
revoke execute on function public.get_member_cards(uuid[]) from public, anon;
revoke execute on function public.is_conversation_participant(uuid) from public, anon;
grant execute on function public.send_connection_request(uuid, uuid, text) to authenticated;
grant execute on function public.respond_to_connection_request(uuid, boolean) to authenticated;
grant execute on function public.withdraw_connection_request(uuid) to authenticated;
grant execute on function public.get_member_cards(uuid[]) to authenticated;
grant execute on function public.is_conversation_participant(uuid) to authenticated;

-- Internal trigger functions are not callable through the API.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.touch_conversation() from public, anon, authenticated;

-- Anonymous visitors get nothing.
revoke all on all tables in schema public from anon;

-- ---------------------------------------------------------------------------
-- Realtime: deliver row changes (still filtered by RLS) for live inboxes.

alter publication supabase_realtime add table
  public.messages,
  public.connection_requests,
  public.conversations,
  public.listings;
