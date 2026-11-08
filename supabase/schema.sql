-- ============================================================================
-- Loan EMI Tracker (mobile) â€” Supabase schema
-- Run this ONCE in: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Safe to re-run (idempotent): drops/recreates policies, uses IF NOT EXISTS.
-- ============================================================================

-- ---- Tables ----------------------------------------------------------------
create table if not exists public.loans (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  loan_name         text not null,
  sanctioned_amount numeric not null,
  rate              numeric not null,          -- annual %, floating
  years             numeric not null,
  start_date        date not null,
  emi_day           int  not null default 5,   -- 1..28
  monthly_emi       numeric not null,
  created_at        timestamptz not null default now()
);

create table if not exists public.disbursements (
  id         uuid primary key default gen_random_uuid(),
  loan_id    uuid not null references public.loans(id) on delete cascade,
  amount     numeric not null,
  date       date not null,
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  loan_id      uuid not null references public.loans(id) on delete cascade,
  amount       numeric not null,
  date         date not null,
  source_month int,
  payment_type text not null check (payment_type in ('EMI_PAYMENT','PREPAYMENT')),
  created_at   timestamptz not null default now()
);

-- Bank charges/fees levied during the tenure; capitalised into principal.
create table if not exists public.charges (
  id          uuid primary key default gen_random_uuid(),
  loan_id     uuid not null references public.loans(id) on delete cascade,
  amount      numeric not null check (amount > 0),
  date        date not null,
  description text not null default '',
  created_at  timestamptz not null default now()
);

create index if not exists idx_charges_loan      on public.charges(loan_id);
create index if not exists idx_loans_user        on public.loans(user_id);
create index if not exists idx_disb_loan         on public.disbursements(loan_id);
create index if not exists idx_pay_loan          on public.payments(loan_id);

-- ---- Row Level Security ----------------------------------------------------
alter table public.loans         enable row level security;
alter table public.disbursements enable row level security;
alter table public.payments      enable row level security;
alter table public.charges       enable row level security;

-- loans: a user can only see/modify their own rows
drop policy if exists "own loans" on public.loans;
create policy "own loans" on public.loans
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- disbursements: access allowed only if the parent loan belongs to the user
drop policy if exists "own disbursements" on public.disbursements;
create policy "own disbursements" on public.disbursements
  for all
  using (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()));

-- payments: same ownership rule via the parent loan
drop policy if exists "own payments" on public.payments;
create policy "own payments" on public.payments
  for all
  using (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()));

-- charges: same ownership rule via the parent loan
drop policy if exists "own charges" on public.charges;
create policy "own charges" on public.charges
  for all
  using (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()))
  with check (exists (select 1 from public.loans l where l.id = loan_id and l.user_id = auth.uid()));

-- rate_changes: floating-rate history with effective dates
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

-- penalties: penal charges for delayed EMIs
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

