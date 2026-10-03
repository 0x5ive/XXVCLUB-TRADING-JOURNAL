-- XXV CLUB Trading Journal
-- Phase 1: Supabase database + Row Level Security
-- Run this entire file once in the Supabase SQL Editor.

create extension if not exists pgcrypto;

-- -----------------------------
-- Profiles
-- -----------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------
-- Trading accounts
-- -----------------------------
create table if not exists public.trading_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_name text not null,
  initial_balance numeric(14,2) not null default 0,
  currency text not null default 'USD',
  risk_per_trade numeric(14,2) not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

-- -----------------------------
-- Trades
-- -----------------------------
create table if not exists public.trades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid,
  trade_date date not null,
  trade_time time,
  symbol text not null,
  direction text not null check (direction in ('BUY', 'SELL')),
  setup text,
  entry_price numeric(20,8),
  stop_loss numeric(20,8),
  take_profit numeric(20,8),
  exit_price numeric(20,8),
  risk_r numeric(10,2) not null default 0,
  result_r numeric(10,2) not null default 0,
  profit_loss numeric(14,2),
  session text,
  notes text,
  emotion text,
  mistake text,
  screenshot_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trades_account_owner_fk
    foreign key (account_id, user_id)
    references public.trading_accounts(id, user_id)
    on delete set null
);

-- -----------------------------
-- Daily / journal notes
-- -----------------------------
create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  pre_market_plan text,
  market_bias text,
  execution_notes text,
  post_market_review text,
  lessons text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, entry_date)
);

-- -----------------------------
-- Helpful indexes
-- -----------------------------
create index if not exists trading_accounts_user_id_idx
  on public.trading_accounts(user_id);

create index if not exists trades_user_date_idx
  on public.trades(user_id, trade_date desc);

create index if not exists trades_account_date_idx
  on public.trades(account_id, trade_date desc);

create index if not exists journal_entries_user_date_idx
  on public.journal_entries(user_id, entry_date desc);

-- -----------------------------
-- updated_at trigger
-- -----------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trading_accounts_set_updated_at on public.trading_accounts;
create trigger trading_accounts_set_updated_at
before update on public.trading_accounts
for each row execute function public.set_updated_at();

drop trigger if exists trades_set_updated_at on public.trades;
create trigger trades_set_updated_at
before update on public.trades
for each row execute function public.set_updated_at();

drop trigger if exists journal_entries_set_updated_at on public.journal_entries;
create trigger journal_entries_set_updated_at
before update on public.journal_entries
for each row execute function public.set_updated_at();

-- -----------------------------
-- Automatically create profile after signup
-- -----------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(coalesce(new.email, ''), '@', 1)
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- -----------------------------
-- Row Level Security
-- -----------------------------
alter table public.profiles enable row level security;
alter table public.trading_accounts enable row level security;
alter table public.trades enable row level security;
alter table public.journal_entries enable row level security;

-- Profiles: users can only access their own profile.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
on public.profiles for delete
to authenticated
using (id = auth.uid());

-- Trading accounts: users can only access their own accounts.
drop policy if exists "accounts_select_own" on public.trading_accounts;
create policy "accounts_select_own"
on public.trading_accounts for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "accounts_insert_own" on public.trading_accounts;
create policy "accounts_insert_own"
on public.trading_accounts for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "accounts_update_own" on public.trading_accounts;
create policy "accounts_update_own"
on public.trading_accounts for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "accounts_delete_own" on public.trading_accounts;
create policy "accounts_delete_own"
on public.trading_accounts for delete
to authenticated
using (user_id = auth.uid());

-- Trades: users can only access their own trades.
drop policy if exists "trades_select_own" on public.trades;
create policy "trades_select_own"
on public.trades for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "trades_insert_own" on public.trades;
create policy "trades_insert_own"
on public.trades for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "trades_update_own" on public.trades;
create policy "trades_update_own"
on public.trades for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "trades_delete_own" on public.trades;
create policy "trades_delete_own"
on public.trades for delete
to authenticated
using (user_id = auth.uid());

-- Journal entries: users can only access their own entries.
drop policy if exists "journal_entries_select_own" on public.journal_entries;
create policy "journal_entries_select_own"
on public.journal_entries for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "journal_entries_insert_own" on public.journal_entries;
create policy "journal_entries_insert_own"
on public.journal_entries for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "journal_entries_update_own" on public.journal_entries;
create policy "journal_entries_update_own"
on public.journal_entries for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "journal_entries_delete_own" on public.journal_entries;
create policy "journal_entries_delete_own"
on public.journal_entries for delete
to authenticated
using (user_id = auth.uid());

-- -----------------------------
-- Least-privilege grants
-- -----------------------------
revoke all on public.profiles from anon;
revoke all on public.trading_accounts from anon;
revoke all on public.trades from anon;
revoke all on public.journal_entries from anon;

revoke all on public.profiles from authenticated;
revoke all on public.trading_accounts from authenticated;
revoke all on public.trades from authenticated;
revoke all on public.journal_entries from authenticated;

grant select, insert, update, delete
on public.profiles to authenticated;

grant select, insert, update, delete
on public.trading_accounts to authenticated;

grant select, insert, update, delete
on public.trades to authenticated;

grant select, insert, update, delete
on public.journal_entries to authenticated;
