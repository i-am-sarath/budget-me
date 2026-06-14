-- ============================================================================
-- Budget Me — Cloud Groups (shared spending) schema
-- Run this in your Supabase project:  SQL Editor → New query → paste → Run.
-- Safe to re-run: every object uses IF NOT EXISTS / CREATE OR REPLACE.
-- ============================================================================

-- ── Profiles (per-user flags, incl. complimentary Pro) ──────────────────────
-- One row per auth user. `is_pro` lets you comp Pro to friends/testers WITHOUT
-- a payment: open Table editor → profiles → find the row by email → set
-- is_pro = true. The app reads this in CloudService.fetchIsProFlag() and treats
-- the user as Pro. `email` is denormalised here purely so you can find people
-- by email in the dashboard.
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  is_pro     boolean not null default false,
  pro_note   text,                                 -- optional: why granted
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Users may READ only their own profile. There are deliberately NO insert/
-- update/delete policies, so a user can never set their own is_pro — only the
-- service role (the Supabase dashboard) can write it.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select using (id = auth.uid());

-- Auto-create a profile row whenever a new user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for any users that already exist (safe to re-run).
insert into public.profiles (id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- ── Tables ──────────────────────────────────────────────────────────────────

-- A shared group (e.g. "Flat 2B"). settle_up toggles the "who owes whom" math.
create table if not exists public.groups (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  emoji         text not null default '👥',
  color_value   bigint not null default 4284955319,
  currency_code text not null default 'USD',
  settle_up     boolean not null default true,
  invite_code   text not null unique,
  created_by    uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now()
);

-- Membership. display_name is denormalised so the UI never needs auth.users.
create table if not exists public.group_members (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  display_name text not null default 'Member',
  role         text not null default 'member',          -- 'owner' | 'member'
  joined_at    timestamptz not null default now(),
  unique (group_id, user_id)
);

-- A shared expense. payer_id = who actually paid.
create table if not exists public.group_expenses (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups(id) on delete cascade,
  payer_id   uuid not null references auth.users(id) on delete cascade,
  amount     numeric(14,2) not null check (amount > 0),
  category   text not null default 'General',
  note       text not null default '',
  spent_at   date not null default current_date,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Per-member share of an expense (drives settle-up balances).
-- For an equal split we insert one row per member; custom splits are supported
-- by varying share_amount.
create table if not exists public.group_expense_splits (
  id           uuid primary key default gen_random_uuid(),
  expense_id   uuid not null references public.group_expenses(id) on delete cascade,
  group_id     uuid not null references public.groups(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  share_amount numeric(14,2) not null default 0
);

create index if not exists idx_group_members_group on public.group_members(group_id);
create index if not exists idx_group_members_user  on public.group_members(user_id);
create index if not exists idx_group_expenses_group on public.group_expenses(group_id);
create index if not exists idx_group_splits_group   on public.group_expense_splits(group_id);

-- ── Helper: is the current user a member of a group? ────────────────────────
-- SECURITY DEFINER so it bypasses RLS and avoids recursive policy evaluation
-- when group_members policies need to check membership.
create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

-- ── Row Level Security ──────────────────────────────────────────────────────
alter table public.groups                enable row level security;
alter table public.group_members         enable row level security;
alter table public.group_expenses        enable row level security;
alter table public.group_expense_splits  enable row level security;

-- groups: members can read; any authed user can create; owner can update/delete.
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups
  for select using (is_group_member(id) or created_by = auth.uid());

drop policy if exists groups_insert on public.groups;
create policy groups_insert on public.groups
  for insert with check (created_by = auth.uid());

drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups
  for update using (created_by = auth.uid());

drop policy if exists groups_delete on public.groups;
create policy groups_delete on public.groups
  for delete using (created_by = auth.uid());

-- group_members: members can read the roster; a user may remove their own row.
-- Inserts are tightly scoped: a user may only add THEMSELVES and only to a group
-- they CREATED (the owner row written at group creation). Joining an existing
-- group must go through join_group(code) below — which verifies the invite code
-- — so simply knowing a group's UUID is not enough to join and read its data.
drop policy if exists members_select on public.group_members;
create policy members_select on public.group_members
  for select using (is_group_member(group_id) or user_id = auth.uid());

drop policy if exists members_insert on public.group_members;
create policy members_insert on public.group_members
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.groups g
      where g.id = group_id and g.created_by = auth.uid()
    )
  );

drop policy if exists members_delete on public.group_members;
create policy members_delete on public.group_members
  for delete using (user_id = auth.uid());

-- Join an existing group by invite code. SECURITY DEFINER so it can look up the
-- group (which the joiner can't yet SELECT under RLS) and insert the membership
-- row, but it ONLY ever adds auth.uid() and ONLY when the code is valid — so a
-- guessed/leaked group UUID can't be used to join. Returns the joined group row.
create or replace function public.join_group(p_code text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
begin
  select * into g from public.groups where invite_code = upper(trim(p_code));
  if g.id is null then
    raise exception 'invalid_invite_code' using errcode = 'no_data_found';
  end if;
  insert into public.group_members (group_id, user_id, display_name, role)
  values (g.id, auth.uid(),
          coalesce(nullif(auth.jwt() ->> 'email', ''), 'Member'), 'member')
  on conflict (group_id, user_id) do nothing;
  return g;
end;
$$;

revoke all on function public.join_group(text) from public;
grant execute on function public.join_group(text) to authenticated;

-- group_expenses: only members can read/write; deletes by creator only.
drop policy if exists expenses_select on public.group_expenses;
create policy expenses_select on public.group_expenses
  for select using (is_group_member(group_id));

drop policy if exists expenses_insert on public.group_expenses;
create policy expenses_insert on public.group_expenses
  for insert with check (is_group_member(group_id) and created_by = auth.uid());

drop policy if exists expenses_delete on public.group_expenses;
create policy expenses_delete on public.group_expenses
  for delete using (created_by = auth.uid());

-- splits: members can read; inserts allowed for members of the group.
drop policy if exists splits_select on public.group_expense_splits;
create policy splits_select on public.group_expense_splits
  for select using (is_group_member(group_id));

drop policy if exists splits_insert on public.group_expense_splits;
create policy splits_insert on public.group_expense_splits
  for insert with check (is_group_member(group_id));

drop policy if exists splits_delete on public.group_expense_splits;
create policy splits_delete on public.group_expense_splits
  for delete using (is_group_member(group_id));

-- ── Account deletion (Google Play policy) ──────────────────────────────────
-- Lets a signed-in user delete their own account from inside the app. Deleting
-- the auth.users row cascades to every group / member / expense / split row via
-- the `on delete cascade` foreign keys above.
-- SECURITY DEFINER so it runs with the function owner's rights (the anon role
-- can't touch auth.users directly). It only ever deletes auth.uid(), so a user
-- can never delete anyone else.
create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_user() from public;
grant execute on function public.delete_user() to authenticated;

-- ── Realtime ────────────────────────────────────────────────────────────────
-- Lets every member's phone see new expenses live. Wrapped so it's safe to
-- re-run: a table can only be added to a publication once, and a plain
-- `alter publication … add table` errors if it's already a member.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'group_expenses'
  ) then
    alter publication supabase_realtime add table public.group_expenses;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'group_members'
  ) then
    alter publication supabase_realtime add table public.group_members;
  end if;
end $$;
