const URL='https://hqcvkqiuwdbirqyrlrsv.supabase.co';
const AH={apikey:process.env.ANON,'Content-Type':'application/json'};
(async()=>{
  for (const d of ['loan.app','loanmanager.app','example.com','loanmgr.app']){
    const r=await fetch(`${URL}/auth/v1/signup`,{method:'POST',headers:AH,body:JSON.stringify({email:`zz_${Date.now()%100000}@${d}`,password:'Test1234'})});
    const j=await r.json();
    console.log(`@${d.padEnd(18)} status=${r.status} -> ${(j.error_code||j.code||j.msg||'ok').toString().slice(0,40)}`);
  }
})().catch(e=>console.error('ERR',e.message));
