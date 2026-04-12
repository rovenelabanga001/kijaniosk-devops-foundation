const { processPayment, processRefund, generateReceipt } = require('../src/index');

describe('processPayment', () => {
  test('returns success for valid payment', () => {
    const result = processPayment(100, 'KES');
    expect(result.status).toBe('success');
    expect(result.amount).toBe(100);
    expect(result.currency).toBe('KES');
    expect(result.ref).toMatch(/^TXN-/);
  });

  test('throws on invalid amount', () => {
    expect(() => processPayment(0, 'KES')).toThrow('Invalid amount');
  });

  test('throws when currency is missing', () => {
    expect(() => processPayment(50, '')).toThrow('Currency required');
  });
});

describe('processRefund', () => {
  test('returns refunded status for valid ref', () => {
    const result = processRefund('TXN-001');
    expect(result.status).toBe('refunded');
    expect(result.ref).toBe('TXN-001');
  });

  test('throws when transaction ref is missing', () => {
    expect(() => processRefund('')).toThrow('Transaction reference required');
  });
});

describe('generateReceipt', () => {
  test('generates receipt for valid transaction', () => {
    const txn = { ref: 'TXN-001', amount: 200 };
    const result = generateReceipt(txn);
    expect(result.receipt).toMatch(/^RCP-/);
    expect(result.amount).toBe(200);
  });

  test('throws for invalid transaction', () => {
    expect(() => generateReceipt(null)).toThrow('Valid transaction required');
  });

  
});