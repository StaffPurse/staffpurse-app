/**
 * Dead Letter Queue (DLQ) Logging Helper
 *
 * Records permanently failed Soroban RPC submissions to the dead_letter table in Supabase.
 */

export interface DeadLetterEntry {
  batchDate: string;
  rootHash: string;
  recordCount: number;
  errorMessage: string;
  errorStack?: string;
  payload?: Record<string, unknown>;
  retryAttempts: number;
}

export async function logDeadLetter(
  supabaseClient: any,
  entry: DeadLetterEntry
): Promise<void> {
  try {
    const { error } = await supabaseClient.from('dead_letter').insert({
      batch_date: entry.batchDate,
      root_hash: entry.rootHash,
      record_count: entry.recordCount,
      error_message: entry.errorMessage,
      error_stack: entry.errorStack,
      payload: entry.payload ?? {},
      retry_attempts: entry.retryAttempts,
      created_at: new Date().toISOString(),
    });

    if (error) {
      console.error('[DLQ] Failed to persist entry to dead_letter table:', error);
    } else {
      console.log(`[DLQ] Successfully recorded failed batch ${entry.batchDate} to dead_letter queue.`);
    }
  } catch (dbErr) {
    console.error('[DLQ] Exception writing to dead_letter table:', dbErr);
  }
}
