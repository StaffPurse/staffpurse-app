/**
 * Exponential Backoff Retry Utility for Soroban RPC Calls
 */

export interface RetryOptions {
  maxRetries?: number;
  initialDelayMs?: number;
  maxDelayMs?: number;
  backoffFactor?: number;
}

export async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {},
  operationName = 'operation'
): Promise<T> {
  const maxRetries = options.maxRetries ?? 3;
  const initialDelay = options.initialDelayMs ?? 1000;
  const maxDelay = options.maxDelayMs ?? 10000;
  const factor = options.backoffFactor ?? 2;

  let attempt = 0;
  let delay = initialDelay;

  while (attempt <= maxRetries) {
    try {
      return await fn();
    } catch (err) {
      attempt++;
      if (attempt > maxRetries) {
        console.error(`[Retry] ${operationName} permanently failed after ${maxRetries} retries:`, err);
        throw err;
      }

      // Add 20% random jitter to avoid thundering herds
      const jitter = delay * 0.2 * (Math.random() * 2 - 1);
      const sleepTime = Math.min(delay + jitter, maxDelay);

      console.warn(`[Retry] ${operationName} failed (attempt ${attempt}/${maxRetries}). Retrying in ${Math.round(sleepTime)}ms... Error:`, err);
      await new Promise((resolve) => setTimeout(resolve, sleepTime));

      delay *= factor;
    }
  }

  throw new Error(`[Retry] ${operationName} exceeded retry limit.`);
}
