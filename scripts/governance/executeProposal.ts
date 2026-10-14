import hre, { ethers } from "hardhat";
import { confirmContinue, Deployments } from "../utils/scripts";
import { getGovernanceSigner, printSigner } from "./utils";

/**
 * Executes a multisig transaction that has reached the confirmation threshold.
 *
 * If the transaction calls the timelock, the underlying timelock operation must
 * be ready (current timestamp >= scheduled timestamp + delay). The script decodes
 * the scheduled operation id so signers can verify readiness before executing.
 *
 * Environment variables:
 *   PROPOSAL_TX_ID  id of the multisig transaction to execute (required)
 */
export async function executeProposal() {
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
  if (!governance || !governance.multisig || !governance.timelock) {
    throw new Error("Governance deployment not found. Run deployGovernance.ts first.");
  }

  const multisig = await ethers.getContractAt("AlloMultisigWallet", governance.multisig, signer);
  const timelock = await ethers.getContractAt("AlloTimelockController", governance.timelock, signer);

  const txn = await multisig.transactions(txId);
  const confirmations = await multisig.getConfirmationCount(txId);

  console.log(`\nExecuting multisig transaction ${txId} on ${hre.network.name} (${chainId})\n`);

  await confirmContinue({
    operation: "Execute multisig transaction",
    chainId,
    network: hre.network.name,
    signer: await signer.getAddress(),
    multisig: governance.multisig,
    timelock: governance.timelock,
    transactionId: txId.toString(),
    target: txn.target,
    value: txn.value.toString(),
    confirmations: confirmations.toString(),
    threshold: governance.threshold,
  });

  if (confirmations < BigInt(governance.threshold)) {
    throw new Error(`Not enough confirmations: ${confirmations} / ${governance.threshold}`);
  }

  // If the target is the timelock, decode the operation id to help the operator verify readiness.
  if (txn.target.toLowerCase() === governance.timelock.toLowerCase()) {
    try {
      const decoded = timelock.interface.parseTransaction({ data: txn.data, value: txn.value });
      if (decoded && decoded.name === "schedule") {
        const [opTarget, opValue, opData, opPredecessor, opSalt, opDelay] = decoded.args;
        const operationId = await timelock.hashOperation(
          opTarget,
          opValue,
          opData,
          opPredecessor,
          opSalt,
        );
        const ready = await timelock.isOperationReady(operationId);
        console.log("Underlying timelock operation id:", operationId);
        console.log("Operation ready:", ready);
        if (!ready) {
          const scheduledAt = (await timelock.getTimestamp(operationId)) - opDelay;
          console.log("Scheduled at:", scheduledAt.toString());
          console.log("Ready after:", (scheduledAt + opDelay).toString());
        }
      } else if (decoded && decoded.name === "execute") {
        const [opTarget, opValue, opData, opPredecessor, opSalt] = decoded.args;
        const operationId = await timelock.hashOperation(
          opTarget,
          opValue,
          opData,
          opPredecessor,
          opSalt,
        );
        console.log("Underlying timelock operation id:", operationId);
        console.log("Operation ready:", await timelock.isOperationReady(operationId));
      }
    } catch {
      // Not a standard timelock call; continue silently.
    }
  }

  const tx = await multisig.executeTransaction(txId, { value: txn.value });
  const receipt = await tx.wait();

  console.log("\nTransaction executed successfully. Hash:", receipt?.hash);
}

if (require.main === module) {
  executeProposal().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

// Example:
// PROPOSAL_TX_ID=0 GOV_SIGNER_PRIVATE_KEY=0x... \
//   npx hardhat run scripts/governance/executeProposal.ts --network sepolia
