// One-time migration: local db.json -> Supabase.
// Run AFTER applying supabase/schema.sql in the dashboard.
//   node --experimental-fetch migrate.js
// Idempotent: re-running won't duplicate (it wipes the owner's loans first).
const fs = require('fs');
const path = require('path');

// ---- load .env (tiny parser, no dependency) --------------------------------
for (const line of fs.readFileSync(path.join(__dirname, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
  if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
}
const { SB_URL, SB_SECRET, OWNER_EMAIL, OWNER_PASSWORD } = process.env;
const H = { apikey: SB_SECRET, Authorization: `Bearer ${SB_SECRET}`, 'Content-Type': 'application/json' };

const api = async (method, pathname, body, extraHeaders = {}) => {
  const res = await fetch(`${SB_URL}${pathname}`, {
    method, headers: { ...H, ...extraHeaders }, body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  if (!res.ok) throw new Error(`${method} ${pathname} -> ${res.status}: ${text.slice(0, 400)}`);
  return json;
};

const round2 = (v) => Math.round(Number(v));

async function ensureOwner() {
  // Find existing user by email; create if missing.
  const list = await api('GET', `/auth/v1/admin/users?per_page=200`);
  const existing = (list.users || []).find((u) => u.email === OWNER_EMAIL);
  if (existing) { console.log('owner exists:', existing.id); return existing.id; }
  const created = await api('POST', '/auth/v1/admin/users', {
    email: OWNER_EMAIL, password: OWNER_PASSWORD, email_confirm: true,
  });
  console.log('owner created:', created.id);
  return created.id;
}

async function wipeOwnerLoans(userId) {
  // Cascade deletes disbursements/payments via FK on delete cascade.
  await api('DELETE', `/rest/v1/loans?user_id=eq.${userId}`, null, { Prefer: 'return=minimal' });
}

async function main() {
  const db = JSON.parse(fs.readFileSync(path.join(__dirname, 'db.json'), 'utf8'));
  const userId = await ensureOwner();
  await wipeOwnerLoans(userId);

  // The local db.json had userId 1 = "deepak" who owns the loans. We map ALL
  // loans to the single owner account (this is a personal app).
  let loanCount = 0, disbCount = 0, payCount = 0;
  for (const loan of db.loans) {
    const [inserted] = await api('POST', '/rest/v1/loans', {
      user_id: userId,
      loan_name: loan.loanName,
      sanctioned_amount: Number(loan.sanctionedAmount ?? loan.principal),
      rate: Number(loan.rate),
      years: Number(loan.years),
      start_date: loan.startDate,
      emi_day: Number(loan.emiDay) || 5,
      monthly_emi: Number(loan.monthlyEmi),
    }, { Prefer: 'return=representation' });
    const loanId = inserted.id;
    loanCount++;

    const disb = (loan.disbursements || []).map((d) => ({
      loan_id: loanId, amount: round2(d.amount), date: d.date,
    }));
    if (disb.length) { await api('POST', '/rest/v1/disbursements', disb, { Prefer: 'return=minimal' }); disbCount += disb.length; }

    const pays = (loan.emiPayments || []).map((p) => ({
      loan_id: loanId, amount: round2(p.amount), date: p.date,
      source_month: p.sourceMonth ?? null, payment_type: p.paymentType,
    }));
    if (pays.length) { await api('POST', '/rest/v1/payments', pays, { Prefer: 'return=minimal' }); payCount += pays.length; }
    console.log(`  loan "${loan.loanName}" -> ${loanId} (${disb.length} disb, ${pays.length} pays)`);
  }
  console.log(`\nDONE: ${loanCount} loans, ${disbCount} disbursements, ${payCount} payments migrated.`);
  console.log(`Login with: ${OWNER_EMAIL} / ${OWNER_PASSWORD}`);
}

main().catch((e) => { console.error('MIGRATION FAILED:', e.message); process.exit(1); });
