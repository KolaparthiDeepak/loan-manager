// Golden-number generator: runs the EXACT engine from the web app's
// server/routes/loans.js against the real loan in db.json, so the Dart port
// can be verified to produce identical numbers. Functions copied verbatim.
const fs = require('fs');
const path = require('path');

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const round2 = (value) => Math.round(Number(value)); // NB: rounds to whole rupees
const toDateString = (value) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const yyyy = date.getUTCFullYear();
  const mm = String(date.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(date.getUTCDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};
const parseDate = (value) => {
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) return null;
  return date;
};
const dayDiff = (fromDate, toDate) => {
  const diff = Math.floor((toDate.getTime() - fromDate.getTime()) / MS_PER_DAY);
  return Math.max(0, diff);
};
const calculateEMI = (principal, rate, years) => {
  const p = Number(principal); const r = Number(rate); const y = Number(years);
  const tenure = y * 12;
  if (tenure <= 0) return 0;
  if (r === 0) return p / tenure;
  const monthlyRate = r / (12 * 100);
  return (p * monthlyRate * Math.pow(1 + monthlyRate, tenure)) / (Math.pow(1 + monthlyRate, tenure) - 1);
};
const getNextDueDate = (emiDay, fromDateInput) => {
  const fromDate = new Date(`${fromDateInput}T00:00:00.000Z`);
  const year = fromDate.getUTCFullYear(); const month = fromDate.getUTCMonth();
  let due = new Date(Date.UTC(year, month, emiDay));
  if (fromDate.getUTCDate() > emiDay) due = new Date(Date.UTC(year, month + 1, emiDay));
  return toDateString(due);
};
const buildTimeline = (loan, untilDateInput) => {
  const startDateStr = loan.startDate || toDateString(new Date());
  const startDate = parseDate(startDateStr);
  const annualRate = Number(loan.rate) / 100;
  const disbursementEvents = (loan.disbursements || []).map((d) => ({
    id: `dis-${d.id}`, type: 'DISBURSEMENT', date: d.date, amount: Number(d.amount || 0),
  }));
  const paymentEvents = (loan.emiPayments || []).map((p) => ({
    id: `pay-${p.id}`, type: p.paymentType === 'PREPAYMENT' ? 'PREPAYMENT' : 'EMI_PAYMENT',
    date: p.date, amount: Number(p.amount || 0), sourceMonth: p.sourceMonth || null,
  }));
  const events = [...disbursementEvents, ...paymentEvents]
    .filter((e) => e.date && e.amount > 0)
    .sort((a, b) => {
      if (a.date < b.date) return -1; if (a.date > b.date) return 1;
      if (a.type === b.type) return 0; return a.type === 'DISBURSEMENT' ? -1 : 1;
    });
  const timeline = [];
  let outstandingPrincipal = 0, accruedInterest = 0, totalDisbursed = 0,
      totalInterestPaid = 0, totalPrincipalPaid = 0, cursorDate = startDate;
  events.forEach((event) => {
    const eventDate = parseDate(event.date); if (!eventDate) return;
    const days = dayDiff(cursorDate, eventDate);
    const periodInterest = round2(outstandingPrincipal * annualRate * (days / 365));
    accruedInterest = round2(accruedInterest + periodInterest);
    let interestPaid = 0, principalPaid = 0;
    if (event.type === 'DISBURSEMENT') {
      outstandingPrincipal = round2(outstandingPrincipal + event.amount);
      totalDisbursed = round2(totalDisbursed + event.amount);
      timeline.push({ date: event.date, eventType: event.type, amount: round2(event.amount), days, periodInterest, outstandingPrincipal, accruedInterest });
    } else if (event.type === 'PREPAYMENT') {
      if (periodInterest > 0) timeline.push({ date: event.date, eventType: 'ACCRUAL', days, periodInterest, outstandingPrincipal, accruedInterest });
      principalPaid = round2(Math.min(outstandingPrincipal, event.amount));
      outstandingPrincipal = round2(Math.max(0, outstandingPrincipal - principalPaid));
      totalPrincipalPaid = round2(totalPrincipalPaid + principalPaid);
      timeline.push({ date: event.date, eventType: 'PREPAYMENT', amount: round2(event.amount), days: 0, periodInterest: 0, principalPaid, outstandingPrincipal, accruedInterest });
    } else {
      interestPaid = round2(Math.min(event.amount, accruedInterest));
      principalPaid = round2(Math.min(outstandingPrincipal, Math.max(0, event.amount - interestPaid)));
      accruedInterest = round2(Math.max(0, accruedInterest - interestPaid));
      outstandingPrincipal = round2(Math.max(0, outstandingPrincipal - principalPaid));
      totalInterestPaid = round2(totalInterestPaid + interestPaid);
      totalPrincipalPaid = round2(totalPrincipalPaid + principalPaid);
      timeline.push({ date: event.date, eventType: event.type, amount: round2(event.amount), days, periodInterest, interestPaid, principalPaid, outstandingPrincipal, accruedInterest });
    }
    cursorDate = eventDate;
  });
  const untilDateStr = toDateString(untilDateInput || new Date());
  const untilDate = parseDate(untilDateStr);
  if (untilDate && cursorDate && untilDate.getTime() > cursorDate.getTime()) {
    const days = dayDiff(cursorDate, untilDate);
    const periodInterest = round2(outstandingPrincipal * annualRate * (days / 365));
    accruedInterest = round2(accruedInterest + periodInterest);
    timeline.push({ date: untilDateStr, eventType: 'ACCRUAL', days, periodInterest, outstandingPrincipal, accruedInterest });
  }
  const sanctionedAmount = Number(loan.sanctionedAmount || 0);
  const undisbursedAmount = round2(Math.max(0, sanctionedAmount - totalDisbursed));
  const asOfDate = timeline.length ? timeline[timeline.length - 1].date : startDateStr;
  const totalPrepayments = (loan.emiPayments || []).filter((p) => p.paymentType === 'PREPAYMENT').reduce((s, p) => s + Number(p.amount || 0), 0);
  const tenure = Number(loan.years) * 12;
  const monthlyEmi = round2(loan.monthlyEmi || 0);
  const monthlyRate = Number(loan.rate) / (12 * 100);
  const loanPrincipal = Number(sanctionedAmount || loan.principal || totalDisbursed);
  const prepaymentsByMonth = {}; let emiCount = 0;
  const allPayments = (loan.emiPayments || []).slice().sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  allPayments.forEach((p) => {
    if (p.paymentType === 'EMI_PAYMENT') emiCount++;
    else if (p.paymentType === 'PREPAYMENT') { const m = emiCount + 1; prepaymentsByMonth[m] = (prepaymentsByMonth[m] || 0) + Number(p.amount || 0); }
  });
  const simulateLoan = (principal, emi, rate, maxMonths, prepayments = {}) => {
    let balance = principal, totalInterest = 0, month = 1;
    while (balance > 0.01 && month <= maxMonths + 100) {
      const interest = balance * rate; let principalPaid = emi - interest;
      const prepay = prepayments[month] || 0;
      let closing = balance - principalPaid - prepay;
      if (closing < 0) { principalPaid += closing; closing = 0; }
      totalInterest += interest; balance = closing; month++;
    }
    return { totalInterest: round2(totalInterest), months: month - 1 };
  };
  const withoutPrepay = simulateLoan(loanPrincipal, monthlyEmi, monthlyRate, tenure, {});
  const originalTotalInterest = withoutPrepay.totalInterest;
  const withPrepay = simulateLoan(loanPrincipal, monthlyEmi, monthlyRate, tenure, prepaymentsByMonth);
  const interestSaved = round2(Math.max(0, originalTotalInterest - withPrepay.totalInterest));
  const monthsSaved = withoutPrepay.months - withPrepay.months;
  return { asOfDate, monthlyEmi, nextDueDate: getNextDueDate(loan.emiDay || 5, asOfDate), sanctionedAmount, totalDisbursed, undisbursedAmount, totalInterestPaid, totalPrincipalPaid, outstandingPrincipal, accruedInterest, totalOutstanding: round2(outstandingPrincipal + accruedInterest), totalPrepayments: round2(totalPrepayments), interestSaved, originalTotalInterest, monthsSaved, timelineRows: timeline.length };
};

const dbFile = process.argv[2] || 'db.json';
const db = JSON.parse(fs.readFileSync(path.join(__dirname, dbFile)));
const loan = db.loans[0];
// Use a FIXED untilDate so the golden numbers are reproducible (not "today").
const result = buildTimeline(loan, '2026-06-30');
console.log(JSON.stringify(result, null, 2));
