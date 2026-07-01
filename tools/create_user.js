// Create a username/password account reliably via the Supabase Admin API
// (bypasses email validation + confirmation + rate limits).
// Usage:
//   node --experimental-fetch create_user.js <username> <password>
// Example:
//   node --experimental-fetch create_user.js deepak MyPass123
const fs = require('fs'), path = require('path');
for (const line of fs.readFileSync(path.join(__dirname, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
  if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
}
const { SB_URL, SB_SECRET } = process.env;
const DOMAIN = 'loan.app'; // must match AppConfig.authEmailDomain

const [username, password] = process.argv.slice(2);
if (!username || !password) {
  console.error('Usage: node --experimental-fetch create_user.js <username> <password>');
  process.exit(1);
}
const email = `${username.trim().toLowerCase()}@${DOMAIN}`;
const H = { apikey: SB_SECRET, Authorization: `Bearer ${SB_SECRET}`, 'Content-Type': 'application/json' };

(async () => {
  // already exists?
  const list = await (await fetch(`${SB_URL}/auth/v1/admin/users?per_page=200`, { headers: H })).json();
  const existing = (list.users || []).find((u) => u.email === email);
  if (existing) {
    // update password so it's known
    await fetch(`${SB_URL}/auth/v1/admin/users/${existing.id}`, {
      method: 'PUT', headers: H, body: JSON.stringify({ password }),
    });
    console.log(`updated existing user '${username}' (${email})`);
    return;
  }
  const res = await fetch(`${SB_URL}/auth/v1/admin/users`, {
    method: 'POST', headers: H,
    body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { username } }),
  });
  const body = await res.text();
  if (!res.ok) { console.error('FAILED:', res.status, body.slice(0, 300)); process.exit(1); }
  console.log(`created user '${username}' -> login with username "${username}"`);
})().catch((e) => { console.error('ERR', e.message); process.exit(1); });
