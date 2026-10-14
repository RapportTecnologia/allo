import hre, { ethers } from "hardhat";
import { confirmContinue, Deployments } from "../utils/scripts";
import { getGovernanceSigner, printSigner } from "./utils";

/**
 * Confirms a pending multisig transaction.
 *
 * Environment variables:
 *   PROPOSAL_TX_ID  id of the multisig transaction to confirm (required)
 */
export async function confirmProposal() {
  const network = await ethers.provider.getNetwork();
  const chainId = Number(network.chainId);

  const signer = await getGovernanceSigner();
  await printSigner(signer);

  const txId = process.env.PROPOSAL_TX_ID ? BigInt(process.env.PROPOSAL_TX_ID) : undefined;
  if (txId === undefined || txId < 0n) {
    throw new Error("PROPOSAL_TX_ID must be a non-negative integer");
  }

  const governanceDeployments = new Deployments(chainId, "governance");
  const governance = governanceDeployments.get(chainId);
  if (!governance || !governance.multisig) {
    throw new Error("Governance deployment not found. Run deployGovernance.ts first.");
  }

  const multisig = await ethers.getContractAt("AlloMultisigWallet", governance.multisig, signer);
  const txn = await multisig.transactions(txId);
  const confirmations = await multisig.getConfirmationCount(txId);

  console.log(`\nConfirming multisig transaction ${txId} on ${hre.network.name} (${chainId})\n`);

  await confirmContinue({
    operation: "Confirm multisig transaction",
    chainId,
    network: hre.network.name,
    signer: await signer.getAddress(),
    multisig: governance.multisig,
    transactionId: txId.toString(),
    target: txn.target,
    value: txn.value.toString(),
    confirmations: confirmations.toString(),
    threshold: governance.threshold,
  });

  const tx = await multisig.confirmTransaction(txId);
  await tx.wait();

  const newConfirmations = await multisig.getConfirmationCount(txId);
  console.log("\nTransaction confirmed. Current confirmations:", newConfirmations.toString(), "/", governance.threshold);

  if (newConfirmations >= BigInt(governance.threshold)) {
    console.log("Threshold reached. Execute after the timelock delay with:");
    console.log(`   PROPOSAL_TX_ID=${txId} npx hardhat run scripts/governance/executeProposal.ts --network ${hre.network.name}`);
  }
}

if (require.main === module) {
  confirmProposal().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

// Example:
// PROPOSAL_TX_ID=0 GOV_SIGNER_PRIVATE_KEY=0x... \
//   npx hardhat run scripts/governance/confirmProposal.ts --network sepolia
