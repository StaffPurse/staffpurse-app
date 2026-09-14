import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { Keypair, TransactionBuilder, Networks, SorobanRpc, Contract, nativeToScVal } from "npm:@stellar/stellar-sdk@11.2.1";
import { MerkleTree } from "npm:merkletreejs";
import SHA256 from "npm:crypto-js/sha256.js";
import { Buffer } from "node:buffer";

const STELLAR_NETWORK_PASSPHRASE = Networks.TESTNET;
const RPC_URL = "https://soroban-testnet.stellar.org";

serve(async (req) => {
  try {
    // 1. Initialize Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get date to anchor (default to yesterday if running via cron)
    let batchDateStr = new URL(req.url).searchParams.get('date');
    if (!batchDateStr) {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      batchDateStr = yesterday.toISOString().split('T')[0].replace(/-/g, ''); // e.g. 20260913
    } else {
      batchDateStr = batchDateStr.replace(/-/g, '');
    }

    console.log(`Starting anchor process for batch date: ${batchDateStr}`);

    // 2. Fetch transactions for the given date
    // (Assuming the occurred_at matches the date logically)
    const { data: txs, error } = await supabase
      .from('transaction_cache')
      .select('id, bmoni_transaction_id')
      .is('batch_date', null) // Only fetch unanchored
      .limit(1000); 

    if (error) throw error;
    
    if (!txs || txs.length === 0) {
      return new Response(JSON.stringify({ message: "No transactions to anchor." }), { status: 200 });
    }

    // 3. Compute Merkle Root using merkletreejs
    // We hash the internal bmoni_transaction_id (or could hash the whole record)
    const leaves = txs.map(tx => SHA256(tx.bmoni_transaction_id));
    const tree = new MerkleTree(leaves, SHA256);
    const rootHashHex = tree.getRoot().toString('hex');
    
    console.log(`Calculated Root: ${rootHashHex} for ${txs.length} transactions`);

    // 4. Anchor on Stellar via Soroban
    const secretKey = Deno.env.get('STELLAR_SERVICE_SECRET_KEY');
    const contractId = Deno.env.get('ANCHOR_CONTRACT_ID');
    
    if (!secretKey || !contractId) {
      throw new Error("Missing Stellar credentials in environment");
    }

    const adminKeypair = Keypair.fromSecret(secretKey);
    const server = new SorobanRpc.Server(RPC_URL);
    
    const account = await server.getAccount(adminKeypair.publicKey());
    const contract = new Contract(contractId);
    
    // Build invocation
    const batchDateSymbol = nativeToScVal(batchDateStr, { type: 'symbol' });
    const rootBytes = nativeToScVal(Buffer.from(rootHashHex, 'hex'));
    
    const operation = contract.call('anchor_root', batchDateSymbol, rootBytes);
    
    let transaction = new TransactionBuilder(account, {
      fee: "1000",
      networkPassphrase: STELLAR_NETWORK_PASSPHRASE,
    })
      .addOperation(operation)
      .setTimeout(30)
      .build();
      
    transaction.sign(adminKeypair);
    
    // Simulate & Submit
    const simulated = await server.simulateTransaction(transaction);
    if (!SorobanRpc.Api.isSimulationSuccess(simulated)) {
      throw new Error(`Simulation failed: ${JSON.stringify(simulated)}`);
    }
    
    transaction = SorobanRpc.assembleTransaction(transaction, simulated).build();
    transaction.sign(adminKeypair);
    
    console.log("Submitting to Stellar network...");
    const sendResponse = await server.sendTransaction(transaction);
    
    if (sendResponse.status !== 'PENDING') {
      throw new Error(`Submit failed: ${JSON.stringify(sendResponse)}`);
    }

    // Await confirmation
    let txStatus = await server.getTransaction(sendResponse.hash);
    while (txStatus.status === 'NOT_FOUND') {
      await new Promise(resolve => setTimeout(resolve, 2000));
      txStatus = await server.getTransaction(sendResponse.hash);
    }
    
    if (txStatus.status !== 'SUCCESS') {
      throw new Error(`Transaction failed on chain: ${JSON.stringify(txStatus)}`);
    }

    const anchorTxHash = sendResponse.hash;
    console.log(`Successfully anchored! Tx Hash: ${anchorTxHash}`);

    // 5. Save the result in DB
    const { error: batchInsertError } = await supabase
      .from('anchored_batches')
      .insert({
        batch_date: batchDateStr,
        root_hash: rootHashHex,
        stellar_transaction_hash: anchorTxHash,
        total_records: txs.length
      });
      
    if (batchInsertError) throw batchInsertError;

    // 6. Update individual transactions with their Merkle proofs
    const updatePromises = txs.map((tx, index) => {
      const leaf = leaves[index];
      const proof = tree.getProof(leaf).map(p => ({
        position: p.position,
        data: p.data.toString('hex')
      }));
      
      return supabase
        .from('transaction_cache')
        .update({
          batch_date: batchDateStr,
          merkle_proof: proof
        })
        .eq('id', tx.id);
    });

    await Promise.all(updatePromises);
    
    console.log("Successfully updated transaction proofs in the database.");

    return new Response(JSON.stringify({ 
      success: true, 
      batchDate: batchDateStr,
      root: rootHashHex,
      txHash: anchorTxHash,
      recordsAnchored: txs.length
    }), { headers: { "Content-Type": "application/json" } });

  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
