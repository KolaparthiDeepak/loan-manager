-- ============================================================================
-- Migration: add bank "charges" to an EXISTING Loan Manager database.
-- Run ONCE in: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Safe to re-run (idempotent). Does not touch loans, disbursements or payments.
-- ============================================================================

create table if not exists public.charges (
  id          uuid primary key default gen_random_uuid(),
  loan_id     uuid not null references public.loans(id) on delete cascade,
  amount      numeric not null check (amount > 0),
  date        date not null,
  description text not null default '',
  created_at  timestamptz not null default now()
);

create index if not exists idx_charges_loan on public.charges(loan_id);

alter table public.charges enable row level security;

-- same ownership rule as payments/disbursements: via the parent loan
drop policy if exists "own charges" on public.charges;
create policy "own charges" on public.charges
  for all
  using (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()));
