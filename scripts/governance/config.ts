// Centralized governance configuration loader.
//
// Environment variables used by governance scripts:
//   GOV_SIGNERS          comma-separated list of multisig signer addresses
//   GOV_THRESHOLD        M-of-N threshold (required)
//   GOV_MIN_DELAY        timelock delay in seconds (default: 172800 = 48h)
//   GOV_SIGNER_PRIVATE_KEY  private key for the signer executing the script
//                         falls back to DEPLOYER_PRIVATE_KEY, otherwise uses
//                         the first Hardhat account (local/testnet only).
//
// IMPORTANT: never commit private keys. Keep them in .env only.

import { ethers } from "hardhat";

export interface GovernanceConfig {
  signers: string[];
  threshold: number;
  minDelay: number;
}

function parseAddressList(value: string | undefined, label: string): string[] {
  if (!value) return [];
  const addresses = value
    .split(",")
    .map((a) => a.trim())
    .filter(Boolean);

  for (const addr of addresses) {
    if (!ethers.isAddress(addr)) {
      throw new Error(`Invalid ${label} address: ${addr}`);
    }
  }
  return addresses;
}

export function loadGovernanceConfig(): GovernanceConfig {
  const signers = parseAddressList(process.env.GOV_SIGNERS, "GOV_SIGNERS");
  const threshold = process.env.GOV_THRESHOLD ? parseInt(process.env.GOV_THRESHOLD, 10) : 0;
  const minDelay = process.env.GOV_MIN_DELAY ? parseInt(process.env.GOV_MIN_DELAY, 10) : 172800;

  if (signers.length === 0) {
    throw new Error(
      "GOV_SIGNERS is required. Example: GOV_SIGNERS=0x...,0x... npx hardhat run ...",
    );
  }
  if (threshold <= 0 || threshold > signers.length) {
    throw new Error(
      `GOV_THRESHOLD must be between 1 and ${signers.length}. Got: ${threshold}`,
    );
  }
  if (minDelay < 172800) {
    throw new Error(
      `GOV_MIN_DELAY must be at least 172800 seconds (48h). Got: ${minDelay}`,
    );
  }

  return { signers, threshold, minDelay };
}

export async function loadSignerAccounts(): Promise<string[]> {
  const signers = await ethers.getSigners();
  return signers.map((s) => s.address);
}
