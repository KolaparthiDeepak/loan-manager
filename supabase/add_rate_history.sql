-- ============================================================================
-- Migration: rate-change HISTORY with effective dates, for an EXISTING database.
-- Run ONCE in: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Safe to re-run (idempotent). Does not touch existing loans/payments/etc.
-- ============================================================================

create table if not exists public.rate_changes (
  id              uuid primary key default gen_random_uuid(),
  loan_id         uuid not null references public.loans(id) on delete cascade,
  effective_date  date not null,
  old_rate        numeric not null,
  new_rate        numeric not null,
  old_emi         numeric not null,
  new_emi         numeric not null,
  old_years       numeric not null,
  new_years       numeric not null,
  adjustment_type text not null check (adjustment_type in ('KEEP_EMI','KEEP_TENURE')),
  created_at      timestamptz not null default now()
);

create index if not exists idx_rate_changes_loan on public.rate_changes(loan_id);

alter table public.rate_changes enable row level security;

drop policy if exists "own rate_changes" on public.rate_changes;
create policy "own rate_changes" on public.rate_changes
  for all
  using (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()));
