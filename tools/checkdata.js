const URL='https://hqcvkqiuwdbirqyrlrsv.supabase.co';
const H={apikey:process.env.SECRET,Authorization:`Bearer ${process.env.SECRET}`};
(async()=>{
  const loans=await (await fetch(`${URL}/rest/v1/loans?select=id,loan_name`,{headers:H})).json();
  console.log('loans:', loans.length, loans.map(l=>l.loan_name).join(', '));
  const pays=await (await fetch(`${URL}/rest/v1/payments?select=amount,date,payment_type,created_at&order=created_at`,{headers:H})).json();
  console.log('payments:', pays.length);
  pays.forEach((p,i)=>console.log(`  ${i+1}. ${p.payment_type} ${p.amount} ${p.date} (created ${p.created_at.slice(0,19)})`));
})().catch(e=>console.error('ERR',e.message));
