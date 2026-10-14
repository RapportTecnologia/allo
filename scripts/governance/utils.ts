import { ethers } from "hardhat";
import type { Signer } from "ethers";

const PRIVATE_KEY_PREFIX = "0x";

/**
 * Returns a signer for governance scripts.
 * Priority:
 *   1. GOV_SIGNER_PRIVATE_KEY env var
 *   2. DEPLOYER_PRIVATE_KEY env var
 *   3. first Hardhat signer (local/testnet only)
 *
 * NEVER log the private key.
 */
export async function getGovernanceSigner(): Promise<Signer> {
  const privateKey = process.env.GOV_SIGNER_PRIVATE_KEY || process.env.DEPLOYER_PRIVATE_KEY;

  if (privateKey) {
    const normalized = privateKey.startsWith(PRIVATE_KEY_PREFIX)
      ? privateKey
      : `${PRIVATE_KEY_PREFIX}${privateKey}`;

    if (normalized.length !== 66) {
      throw new Error(
        "GOV_SIGNER_PRIVATE_KEY or DEPLOYER_PRIVATE_KEY has an invalid length",
      );
    }

    return new ethers.Wallet(normalized, ethers.provider);
  }

  const signers = await ethers.getSigners();
  if (signers.length === 0) {
    throw new Error(
      "No signer available. Set GOV_SIGNER_PRIVATE_KEY or DEPLOYER_PRIVATE_KEY in .env",
    );
  }

  return signers[0];
}

/**
 * Prints the signer address without exposing the private key.
 */
export async function printSigner(signer: Signer): Promise<void> {
  const address = await signer.getAddress();
  const balance = await ethers.provider.getBalance(address);
  console.log("Using signer:", address);
  console.log("Signer balance:", ethers.formatEther(balance));
}
