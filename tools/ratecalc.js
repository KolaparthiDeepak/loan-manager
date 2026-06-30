const round2 = (v) => Math.round(Number(v));
const calculateEMI = (principal, rate, years) => {
  const p=+principal, r=+rate, tenure=+years*12;
  if (tenure<=0) return 0; if (r===0) return p/tenure;
  const mr=r/(12*100); return (p*mr*Math.pow(1+mr,tenure))/(Math.pow(1+mr,tenure)-1);
};
// scenario inputs (Home Loan, as of 2026-06-30)
const outstanding=8031059, oldEmi=82412, sanctioned=9000000, years=15;
for (const newRateInput of [8.0, 6.5]) {
  const newRate = round2(newRateInput*100)/100;
  const mr = newRate/(12*100);
  // KEEP_TENURE
  const keepTenureEmi = round2(calculateEMI(sanctioned, newRate, years));
  // KEEP_EMI
  let keepEmiYears = null, err=null;
  if (oldEmi <= outstanding*mr) err='EMI too low';
  else {
    const n = Math.ceil(-Math.log(1-(outstanding*mr)/oldEmi)/Math.log(1+mr));
    keepEmiYears = Math.ceil(n/12*10)/10;
  }
  console.log(`newRate=${newRate}  KEEP_TENURE newEmi=${keepTenureEmi}  KEEP_EMI newYears=${keepEmiYears} ${err||''}`);
}
