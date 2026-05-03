// KijaniKiosk Payments Service
// Handles payment processing, refunds, and receipt generation.

function processPayment(amount, currency) {
  if (!amount || amount <= 0) throw new Error('Invalid amount');
  if (!currency) throw new Error('Currency required');
  return { status: 'success', amount, currency, ref: `TXN-${Date.now()}` };
}

function processRefund(transactionRef) {
  if (!transactionRef) throw new Error('Transaction reference required');
  return { status: 'refunded', ref: transactionRef };
}

function generateReceipt(transaction) {
  if (!transaction || !transaction.ref) throw new Error('Valid transaction required');
  return { receipt: `RCP-${transaction.ref}`, amount: transaction.amount };
}

module.exports = { processPayment, processRefund, generateReceipt };

# version marker
