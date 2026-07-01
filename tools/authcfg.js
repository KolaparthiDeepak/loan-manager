const URL='https://hqcvkqiuwdbirqyrlrsv.supabase.co';
const REF='hqcvkqiuwdbirqyrlrsv';
(async()=>{
  // current gotrue settings (public)
  const s=await fetch(`${URL}/auth/v1/settings`,{headers:{apikey:process.env.ANON}});
  const j=await s.json();
  console.log('mailer_autoconfirm:', j.mailer_autoconfirm, '| disable_signup:', j.disable_signup);
  // try management API with the SECRET key (expect 401 unless it is a mgmt token)
  const m=await fetch(`https://api.supabase.com/v1/projects/${REF}/config/auth`,{headers:{Authorization:`Bearer ${process.env.SECRET}`}});
  console.log('mgmt API status with secret key:', m.status, '(200 = I can toggle it; 401 = you must use dashboard)');
})().catch(e=>console.error('ERR',e.message));
