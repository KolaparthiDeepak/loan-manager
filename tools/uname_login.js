const URL='https://hqcvkqiuwdbirqyrlrsv.supabase.co';
const DOMAIN='loan.app';
const H={apikey:process.env.ANON,'Content-Type':'application/json'};
const username='deepak', password='LoanApp@123';
(async()=>{
  const email=`${username.toLowerCase()}@${DOMAIN}`;
  const r=await fetch(`${URL}/auth/v1/token?grant_type=password`,{method:'POST',headers:H,body:JSON.stringify({email,password})});
  const j=await r.json();
  console.log(`username "${username}" -> ${email}`);
  console.log('login status:', r.status, '| session:', !!j.access_token);
})().catch(e=>console.error('ERR',e.message));
