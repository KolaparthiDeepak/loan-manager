const round2 = (v) => Math.round(Number(v));
const calculateEMI = (p, r, y) => { const t=y*12, mr=r/1200; return (p*mr*Math.pow(1+mr,t))/(Math.pow(1+mr,t)-1); };
const getEmiSchedule = (principal, rate, years) => {
  const mr=rate/1200, tenure=years*12, emi=calculateEMI(principal,rate,years);
  const s=[]; let bal=principal;
  for (let i=0;i<tenure;i++){ const interest=round2(bal*mr); const pp=round2(Math.min(bal,emi-interest)); bal=round2(Math.max(0,bal-pp)); s.push({month:i+1,emi:round2(emi),principal:pp,interest,balance:bal}); }
  return s;
};
const s = getEmiSchedule(9000000, 7.3, 15);
const tot = s.reduce((a,r)=>a+r.interest,0);
console.log('len', s.length);
console.log('m1', JSON.stringify(s[0]));
console.log('m180', JSON.stringify(s[179]));
console.log('totalInterest', tot);
