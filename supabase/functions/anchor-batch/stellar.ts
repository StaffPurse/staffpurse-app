import * as StellarSdk from "npm:@stellar/stellar-sdk";

export async function submitAnchorRoot(merkleRoot: string): Promise<string> {
  const secretKey = Deno.env.get("SOROBAN_SERVICE_SECRET_KEY");
  if (!secretKey) {
    throw new Error("SOROBAN_SERVICE_SECRET_KEY is missing");
  }

  const contractId = Deno.env.get("SOROBAN_CONTRACT_ID");
  if (!contractId) {
    throw new Error("SOROBAN_CONTRACT_ID is missing");
  }

  const network = Deno.env.get("STELLAR_NETWORK") || "TESTNET";
  const rpcUrl = Deno.env.get("SOROBAN_RPC_URL") || "https://soroban-testnet.stellar.org";

  const server = new StellarSdk.rpc.Server(rpcUrl);
  const keypair = StellarSdk.Keypair.fromSecret(secretKey);

  const sourceAccount = await server.getAccount(keypair.publicKey());

  const contract = new StellarSdk.Contract(contractId);
  
  // Convert merkleRoot to ScVal
  const merkleRootScVal = StellarSdk.nativeToScVal(merkleRoot, { type: "string" });

  const tx = new StellarSdk.TransactionBuilder(sourceAccount, {
    fee: StellarSdk.BASE_FEE,
    networkPassphrase: network === "PUBLIC" ? StellarSdk.Networks.PUBLIC : StellarSdk.Networks.TESTNET,
  })
    .addOperation(contract.call("anchor_root", merkleRootScVal))
    .setTimeout(30)
    .build();

  // Simulate to populate footprint
  const preparedTx = await server.prepareTransaction(tx);

  // Sign transaction
  preparedTx.sign(keypair);

  // Submit to network
  const response = await server.sendTransaction(preparedTx);
  if (response.status === "ERROR") {
    throw new Error(`Transaction failed: ${JSON.stringify(response)}`);
  }

  return response.hash;
}
