// Fetch loans from Supabase and write them in db.json shape, so golden.js can
// run the engine on the migrated data and confirm round-trip fidelity.
const fs = require('fs'), path = require('path');
for (const line of fs.readFileSync(path.join(__dirname, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
  if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
}
const { SB_URL, SB_SECRET } = process.env;
const H = { apikey: SB_SECRET, Authorization: `Bearer ${SB_SECRET}` };
(async () => {
  const rows = await (await fetch(
    `${SB_URL}/rest/v1/loans?select=*,disbursements(*),payments(*)`,
    { headers: H }
  )).json();
  const loans = rows.map((r) => ({
    loanName: r.loan_name,
    sanctionedAmount: Number(r.sanctioned_amount),
    principal: Number(r.sanctioned_amount),
    rate: Number(r.rate),
    years: Number(r.years),
    startDate: r.start_date,
    emiDay: Number(r.emi_day),
    monthlyEmi: Number(r.monthly_emi),
    disbursements: r.disbursements.map((d) => ({
      id: d.id, amount: Number(d.amount), date: d.date,
    })),
    emiPayments: r.payments.map((p) => ({
      id: p.id, amount: Number(p.amount), date: p.date,
      sourceMonth: p.source_month, paymentType: p.payment_type,
    })),
  }));
  fs.writeFileSync(path.join(__dirname, 'sb_dump.json'), JSON.stringify({ loans }, null, 2));
  console.log('dumped', loans.length, 'loan(s) from Supabase');
})().catch((e) => { console.error('ERR', e.message); process.exit(1); });
