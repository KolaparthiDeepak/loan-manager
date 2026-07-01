const URL='https://hqcvkqiuwdbirqyrlrsv.supabase.co';
const AH={apikey:process.env.ANON,'Content-Type':'application/json'};
const SH={apikey:process.env.SECRET,Authorization:`Bearer ${process.env.SECRET}`,'Content-Type':'application/json'};
const domains=['example.com','loanmanager.app','users.loanmanager.app','app.local','loanmgr.io','username.dev','gmail.com','proton.me','mailinator.com'];
(async()=>{
  const created=[];
  for (const d of domains){
    const email=`probe_${Date.now()%100000}_x@${d}`;
    const r=await fetch(`${URL}/auth/v1/signup`,{method:'POST',headers:AH,body:JSON.stringify({email,password:'Test1234'})});
    const j=await r.json();
    const ok=r.status===200;
    console.log(`${ok?'PASS':'FAIL'}  @${d}  ${ok?'':'-> '+(j.msg||j.error_code||JSON.stringify(j)).slice(0,60)}`);
    if (ok && j.id) created.push(j.id);
  }
  // cleanup created probe users
  for (const id of created){ await fetch(`${URL}/auth/v1/admin/users/${id}`,{method:'DELETE',headers:SH}); }
  console.log('cleaned up', created.length, 'probe users');
})().catch(e=>console.error('ERR',e.message));
