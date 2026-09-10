create extension if not exists pgcrypto;

create table if not exists public.challenges (
    id uuid primary key,
    title_key text not null,
    subtitle_key text not null,
    prompt_key text not null,
    duration_days integer not null check (duration_days between 1 and 90),
    symbol_name text not null,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

create table if not exists public.challenge_enrollments (
    id uuid primary key default gen_random_uuid(),
    challenge_id uuid not null references public.challenges(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    joined_at timestamptz not null default now(),
    completed_at timestamptz,
    progress double precision not null default 0 check (progress between 0 and 1),
    unique (challenge_id, user_id)
);

alter table public.challenges enable row level security;
alter table public.challenge_enrollments enable row level security;

create policy "Anyone can read active challenges"
on public.challenges for select
using (is_active = true);

create policy "Users can read their enrollments"
on public.challenge_enrollments for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can join challenges"
on public.challenge_enrollments for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update their progress"
on public.challenge_enrollments for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

insert into public.challenges (id, title_key, subtitle_key, prompt_key, duration_days, symbol_name)
values
    ('81ad0d9d-9500-4f15-8d47-9ac7ae75e5a1', 'challenge.focus.title', 'challenge.focus.subtitle', 'challenge.focus.prompt', 7, 'scope'),
    ('d9c25fb6-814e-4b82-a890-b86048804b8c', 'challenge.read.title', 'challenge.read.subtitle', 'challenge.read.prompt', 14, 'book.pages.fill'),
    ('4da13be0-52ce-49db-b9da-f5d68af3ef35', 'challenge.small.title', 'challenge.small.subtitle', 'challenge.small.prompt', 7, 'sparkles')
on conflict (id) do update set
    title_key = excluded.title_key,
    subtitle_key = excluded.subtitle_key,
    prompt_key = excluded.prompt_key,
    duration_days = excluded.duration_days,
    symbol_name = excluded.symbol_name;

create or replace view public.challenge_popularity as
select
    challenge_id,
    count(*) filter (where joined_at >= now() - interval '7 days') as joins_last_7_days,
    count(*) filter (where completed_at >= now() - interval '7 days') as completions_last_7_days,
    count(*) as participant_count,
    count(*) filter (where joined_at >= now() - interval '7 days')
      + 2 * count(*) filter (where completed_at >= now() - interval '7 days') as trending_score
from public.challenge_enrollments
group by challenge_id;
