const KEY = process.env.SB_KEY;
const URL = 'https://hqcvkqiuwdbirqyrlrsv.supabase.co';
(async () => {
  // 1) Auth admin: list users (proves service/secret key validity)
  const r = await fetch(`${URL}/auth/v1/admin/users?per_page=1`, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  });
  console.log('auth admin status:', r.status);
  const body = await r.text();
  console.log('auth body (first 300):', body.slice(0, 300));
  // 2) REST: probe whether a "loans" table already exists
  const r2 = await fetch(`${URL}/rest/v1/loans?select=id&limit=1`, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  });
  console.log('rest loans status:', r2.status);
  console.log('rest body (first 200):', (await r2.text()).slice(0, 200));
})().catch(e => console.error('ERR', e.message));
