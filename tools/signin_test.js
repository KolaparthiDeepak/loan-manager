const URL='https://hqcvkqiuwdbirqyrlrsv.supabase.co';
const H={apikey:process.env.ANON,'Content-Type':'application/json'};
(async()=>{
  const r=await fetch(`${URL}/auth/v1/token?grant_type=password`,{method:'POST',headers:H,body:JSON.stringify({email:'deepak@loan.app',password:'LoanApp@123'})});
  const j=await r.json();
  console.log('signin status:', r.status);
  console.log('has access_token:', !!j.access_token, '| user:', j.user?.email, '| confirmed:', !!j.user?.email_confirmed_at);
  if (j.access_token) {
    // fetch loans as this user (RLS) to confirm dashboard would have data
    const l=await fetch(`${URL}/rest/v1/loans?select=loan_name,disbursements(count),payments(count)`,{headers:{apikey:process.env.ANON,Authorization:`Bearer ${j.access_token}`}});
    console.log('loans (RLS as user):', await l.text());
  } else { console.log('error:', JSON.stringify(j).slice(0,300)); }
})().catch(e=>console.error('ERR',e.message));
