import { MerkleTree, sha256Hex } from './merkle.ts';

// Tests for Merkle Tree construction and proof verification
export async function runMerkleTests() {
  console.log('Running Merkle Tree tests...');

  // Test 1: Empty tree
  const emptyTree = await MerkleTree.create([]);
  if (emptyTree.getRoot().length !== 64) {
    throw new Error('Empty tree root should be 64 characters');
  }
  console.log('✓ Empty tree test passed');

  // Test 2: Single leaf
  const leaf1 = await sha256Hex('record_1');
  const singleTree = await MerkleTree.create([leaf1]);
  if (singleTree.getRoot() !== leaf1) {
    throw new Error('Single leaf root should equal leaf');
  }
  console.log('✓ Single leaf tree test passed');

  // Test 3: Multiple leaves (even count)
  const leaves4 = await Promise.all([
    sha256Hex('tx_100_ngn'),
    sha256Hex('tx_200_ngn'),
    sha256Hex('tx_300_ngn'),
    sha256Hex('tx_400_ngn'),
  ]);
  const tree4 = await MerkleTree.create(leaves4);
  const root4 = tree4.getRoot();

  for (let i = 0; i < leaves4.length; i++) {
    const proof = tree4.getProof(i);
    const valid = await MerkleTree.verifyProof(leaves4[i], proof, root4);
    if (!valid) {
      throw new Error(`Proof verification failed for leaf index ${i}`);
    }
  }
  console.log('✓ Even leaves (4) proofs verified successfully');

  // Test 4: Odd count (3 leaves)
  const leaves3 = leaves4.slice(0, 3);
  const tree3 = await MerkleTree.create(leaves3);
  const root3 = tree3.getRoot();

  for (let i = 0; i < leaves3.length; i++) {
    const proof = tree3.getProof(i);
    const valid = await MerkleTree.verifyProof(leaves3[i], proof, root3);
    if (!valid) {
      throw new Error(`Odd proof verification failed for index ${i}`);
    }
  }
  console.log('✓ Odd leaves (3) proofs verified successfully');

  // Test 5: Invalid proof fails
  const tamperedProof = tree4.getProof(0);
  tamperedProof[0].data = 'a'.repeat(64);
  const invalidResult = await MerkleTree.verifyProof(leaves4[0], tamperedProof, root4);
  if (invalidResult) {
    throw new Error('Tampered proof should fail verification');
  }
  console.log('✓ Tampered proof detection passed');

  console.log('All Merkle tests passed cleanly!');
}

// Support executing directly with node/deno
if (typeof Deno !== 'undefined') {
  Deno.test('MerkleTree suite', async () => {
    await runMerkleTests();
  });
}
