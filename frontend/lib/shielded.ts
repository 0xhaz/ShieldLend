// Shielded mode utilities — client-side crypto for privacy operations
// Uses Starknet's native Pedersen hash (same as Cairo contracts + Noir circuits)

import { hash, num } from "starknet";

// ---- Types ----

export interface ShieldedNoteLocal {
  commitment: string; // felt252 hex
  amount: string; // raw amount string (e.g. "1.5")
  amountWei: string; // amount in wei as decimal string
  blinding: string; // felt252 hex
  nullifierSecret: string; // felt252 hex
  nullifier: string; // felt252 hex — derived: H(commitment, nullifierSecret)
  noteType: "deposit" | "borrow";
  pool: string; // pool contract address
  leafIndex?: number; // assigned after on-chain insertion
  spent: boolean;
  createdAt: number; // timestamp
}

// ---- Crypto primitives ----

/** Generate a random felt252-range value for blinding factors / secrets */
export function randomFelt(): string {
  const bytes = new Uint8Array(31); // 31 bytes < felt252 max
  crypto.getRandomValues(bytes);
  return num.toHex(num.toBigInt("0x" + Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("")));
}

/** Pedersen commitment: H(amount, blinding) — matches Noir circuit */
export function computeCommitment(amountFelt: string, blinding: string): string {
  return hash.computePedersenHash(amountFelt, blinding);
}

/** Derive nullifier: H(commitment, nullifierSecret) — matches Noir circuit */
export function computeNullifier(commitment: string, nullifierSecret: string): string {
  return hash.computePedersenHash(commitment, nullifierSecret);
}

/** Create a mock proof array that passes the ZkVerifier mock validation.
 *  The mock verifier just checks proof.len() >= 1 and public_inputs count. */
export function createMockProof(): string[] {
  return ["0x1"];
}

// ---- Note management (localStorage) ----

const STORAGE_KEY = "shieldlend_notes";

export function loadNotes(): ShieldedNoteLocal[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export function saveNotes(notes: ShieldedNoteLocal[]): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(notes));
}

export function addNote(note: ShieldedNoteLocal): void {
  const notes = loadNotes();
  notes.push(note);
  saveNotes(notes);
}

export function markNoteSpent(commitment: string): void {
  const notes = loadNotes();
  const note = notes.find((n) => n.commitment === commitment);
  if (note) {
    note.spent = true;
    saveNotes(notes);
  }
}

export function getUnspentNotes(pool?: string, noteType?: "deposit" | "borrow"): ShieldedNoteLocal[] {
  return loadNotes().filter((n) => {
    if (n.spent) return false;
    if (pool && n.pool !== pool) return false;
    if (noteType && n.noteType !== noteType) return false;
    return true;
  });
}

// ---- Shielded deposit helpers ----

/** Build a shielded deposit note + calldata for the contract */
export function prepareShieldedDeposit(
  amount: string,
  amountWei: bigint,
  pool: string,
): {
  note: ShieldedNoteLocal;
  commitment: string;
  encryptedAmount: string;
  proof: string[];
  publicInputs: string[];
} {
  const blinding = randomFelt();
  const nullifierSecret = randomFelt();

  // Amount as felt252 for Pedersen (use the wei value)
  const amountFelt = num.toHex(amountWei);

  const commitment = computeCommitment(amountFelt, blinding);
  const nullifier = computeNullifier(commitment, nullifierSecret);

  // Encrypted amount: for MVP, just XOR with a derived key (simplified)
  // In production this would be ElGamal or ECIES encryption
  const encryptedAmount = num.toHex(amountWei ^ BigInt(blinding));

  const note: ShieldedNoteLocal = {
    commitment,
    amount,
    amountWei: amountWei.toString(),
    blinding,
    nullifierSecret,
    nullifier,
    noteType: "deposit",
    pool,
    spent: false,
    createdAt: Date.now(),
  };

  return {
    note,
    commitment,
    encryptedAmount,
    proof: createMockProof(),
    publicInputs: [commitment], // circuit type 0: 1 public input
  };
}

/** Build a shielded withdraw calldata from an existing deposit note */
export function prepareShieldedWithdraw(
  note: ShieldedNoteLocal,
): {
  nullifier: string;
  changeCommitment: string; // 0 for full withdraw
  merkleRoot: string; // we'll read this from the contract
  proof: string[];
} {
  return {
    nullifier: note.nullifier,
    changeCommitment: "0x0", // full withdraw for MVP
    merkleRoot: "0x0", // will be fetched from CommitmentStore on-chain
    proof: createMockProof(),
  };
}

/** Build a shielded borrow note + calldata */
export function prepareShieldedBorrow(
  borrowAmount: string,
  borrowAmountWei: bigint,
  collateralNote: ShieldedNoteLocal,
  pool: string,
): {
  borrowNote: ShieldedNoteLocal;
  borrowCommitment: string;
  collateralNullifier: string;
  encryptedBorrowAmount: string;
  merkleRoot: string;
  proof: string[];
} {
  const blinding = randomFelt();
  const nullifierSecret = randomFelt();
  const borrowAmountFelt = num.toHex(borrowAmountWei);

  const borrowCommitment = computeCommitment(borrowAmountFelt, blinding);
  const nullifier = computeNullifier(borrowCommitment, nullifierSecret);
  const encryptedBorrowAmount = num.toHex(borrowAmountWei ^ BigInt(blinding));

  const borrowNote: ShieldedNoteLocal = {
    commitment: borrowCommitment,
    amount: borrowAmount,
    amountWei: borrowAmountWei.toString(),
    blinding,
    nullifierSecret,
    nullifier,
    noteType: "borrow",
    pool,
    spent: false,
    createdAt: Date.now(),
  };

  return {
    borrowNote,
    borrowCommitment,
    collateralNullifier: collateralNote.nullifier,
    encryptedBorrowAmount,
    merkleRoot: "0x0", // will be fetched from CommitmentStore
    proof: createMockProof(),
  };
}

/** Build a shielded repay calldata from an existing borrow note */
export function prepareShieldedRepay(
  borrowNote: ShieldedNoteLocal,
): {
  debtNullifier: string;
  newDebtCommitment: string; // 0 for full repay
  proof: string[];
} {
  return {
    debtNullifier: borrowNote.nullifier,
    newDebtCommitment: "0x0", // full repay for MVP
    proof: createMockProof(),
  };
}
