-- ============================================================================
-- Migration: penal charges for delayed EMIs, for an EXISTING database.
-- Run ONCE in: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Safe to re-run (idempotent). Does not touch existing data.
-- ============================================================================

create table if not exists public.penalties (
  id             uuid primary key default gen_random_uuid(),
  loan_id        uuid not null references public.loans(id) on delete cascade,
  delay_start    date not null,           -- EMI due date (first day overdue)
  delay_end      date not null,           -- day the EMI was finally paid
  levied_date    date not null,           -- day the bank posted the charge
  overdue_amount numeric not null,
  rate           numeric not null,        -- penal % p.a. (Union Bank: 2)
  gst_rate       numeric not null default 18,
  amount         numeric not null check (amount > 0),   -- booked, penalty + GST
  disputed       boolean not null default false,
  note           text not null default '',
  created_at     timestamptz not null default now()
);

create index if not exists idx_penalties_loan on public.penalties(loan_id);

alter table public.penalties enable row level security;

drop policy if exists "own penalties" on public.penalties;
create policy "own penalties" on public.penalties
  for all
  using (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()));
