const URL='https://hqcvkqiuwdbirqyrlrsv.supabase.co';
const ANON=process.env.ANON;
const H={apikey:ANON,'Content-Type':'application/json'};
(async()=>{
  for (const email of ['newuser1@gmail.com','someone@loan.app']) {
    const r=await fetch(`${URL}/auth/v1/signup`,{method:'POST',headers:H,body:JSON.stringify({email,password:'Test1234'})});
    console.log(`\n[${email}] status=${r.status}`);
    console.log((await r.text()).slice(0,400));
  }
})().catch(e=>console.error('ERR',e.message));
