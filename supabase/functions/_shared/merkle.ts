/**
 * Merkle Tree Utility for StaffPurse Daily Batch Anchoring
 *
 * Implements standard binary SHA-256 Merkle tree generation,
 * proof construction, and proof verification.
 */

export interface MerkleProofStep {
  position: 'left' | 'right';
  data: string; // hex string of sibling hash
}

export type MerkleProof = MerkleProofStep[];

/**
 * Computes SHA-256 hash of a Uint8Array or hex string, returning a lowercase hex string.
 */
export async function sha256Hex(input: Uint8Array | string): Promise<string> {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  const hashBuffer = await crypto.subtle.digest('SHA-256', bytes);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Combines two hex hashes and hashes the concatenated bytes: SHA-256(left + right)
 */
export async function combineHashes(leftHex: string, rightHex: string): Promise<string> {
  const leftBytes = hexToUint8Array(leftHex);
  const rightBytes = hexToUint8Array(rightHex);
  const combined = new Uint8Array(leftBytes.length + rightBytes.length);
  combined.set(leftBytes, 0);
  combined.set(rightBytes, leftBytes.length);
  return await sha256Hex(combined);
}

function hexToUint8Array(hex: string): Uint8Array {
  const clean = hex.startsWith('0x') ? hex.slice(2) : hex;
  const length = clean.length / 2;
  const uint8 = new Uint8Array(length);
  for (let i = 0; i < length; i++) {
    uint8[i] = parseInt(clean.substring(i * 2, i * 2 + 2), 16);
  }
  return uint8;
}

export class MerkleTree {
  private leaves: string[];
  private layers: string[][];

  private constructor(leaves: string[], layers: string[][]) {
    this.leaves = leaves;
    this.layers = layers;
  }

  /**
   * Builds a Merkle Tree from an array of 32-byte hex leaf hashes.
   */
  public static async create(leaves: string[]): Promise<MerkleTree> {
    if (!leaves || leaves.length === 0) {
      // Empty tree: root is 32 bytes of zeros
      const emptyRoot = '0'.repeat(64);
      return new MerkleTree([], [[emptyRoot]]);
    }

    const cleanLeaves = leaves.map((l) => (l.startsWith('0x') ? l.slice(2).toLowerCase() : l.toLowerCase()));
    const layers: string[][] = [cleanLeaves];

    let currentLayer = cleanLeaves;
    while (currentLayer.length > 1) {
      const nextLayer: string[] = [];
      for (let i = 0; i < currentLayer.length; i += 2) {
        const left = currentLayer[i];
        // If odd number of nodes, duplicate the last node
        const right = i + 1 < currentLayer.length ? currentLayer[i + 1] : left;
        const combined = await combineHashes(left, right);
        nextLayer.push(combined);
      }
      layers.push(nextLayer);
      currentLayer = nextLayer;
    }

    return new MerkleTree(cleanLeaves, layers);
  }

  /**
   * Returns the root hash of the tree as a 64-character hex string.
   */
  public getRoot(): string {
    return this.layers[this.layers.length - 1][0];
  }

  /**
   * Generates a cryptographic Merkle proof for a leaf at the given index.
   */
  public getProof(leafIndex: number): MerkleProof {
    if (leafIndex < 0 || leafIndex >= this.leaves.length) {
      throw new Error(`Leaf index ${leafIndex} out of bounds (0..${this.leaves.length - 1})`);
    }

    const proof: MerkleProof = [];
    let currentIndex = leafIndex;

    for (let layerIndex = 0; layerIndex < this.layers.length - 1; layerIndex++) {
      const layer = this.layers[layerIndex];
      const isRightChild = currentIndex % 2 === 1;
      const siblingIndex = isRightChild ? currentIndex - 1 : currentIndex + 1;

      // Sibling is either the paired node or duplicated if last odd node
      const siblingHash =
        siblingIndex < layer.length ? layer[siblingIndex] : layer[currentIndex];

      proof.push({
        position: isRightChild ? 'left' : 'right',
        data: siblingHash,
      });

      currentIndex = Math.floor(currentIndex / 2);
    }

    return proof;
  }

  /**
   * Verifies a Merkle proof against a root hash.
   */
  public static async verifyProof(
    leaf: string,
    proof: MerkleProof,
    root: string
  ): Promise<boolean> {
    let currentHash = leaf.startsWith('0x') ? leaf.slice(2).toLowerCase() : leaf.toLowerCase();
    const cleanRoot = root.startsWith('0x') ? root.slice(2).toLowerCase() : root.toLowerCase();

    for (const step of proof) {
      const sibling = step.data.startsWith('0x') ? step.data.slice(2).toLowerCase() : step.data.toLowerCase();
      if (step.position === 'left') {
        currentHash = await combineHashes(sibling, currentHash);
      } else {
        currentHash = await combineHashes(currentHash, sibling);
      }
    }

    return currentHash === cleanRoot;
  }
}
