const fs = require('fs'), path = require('path');
for (const line of fs.readFileSync(path.join(__dirname,'.env'),'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/); if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
}
const { SB_URL, SB_SECRET, OWNER_EMAIL, OWNER_PASSWORD } = process.env;
const H = { apikey: SB_SECRET, Authorization: `Bearer ${SB_SECRET}`, 'Content-Type': 'application/json' };
(async () => {
  const list = await (await fetch(`${SB_URL}/auth/v1/admin/users?per_page=200`, { headers: H })).json();
  const existing = (list.users||[]).find(u => u.email === OWNER_EMAIL);
  if (existing) { console.log('owner already exists:', existing.id, existing.email); return; }
  const res = await fetch(`${SB_URL}/auth/v1/admin/users`, { method:'POST', headers:H, body: JSON.stringify({ email: OWNER_EMAIL, password: OWNER_PASSWORD, email_confirm: true }) });
  const body = await res.text();
  console.log('create status:', res.status); console.log(body.slice(0,300));
})().catch(e => console.error('ERR', e.message));
