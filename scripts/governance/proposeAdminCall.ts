import hre, { ethers } from "hardhat";
import { confirmContinue, Deployments } from "../utils/scripts";
import { getGovernanceSigner, printSigner } from "./utils";

/**
 * Submits a governance proposal to schedule an administrative call through the timelock.
 *
 * The script creates a multisig transaction whose target is the timelock and whose
 * calldata is `timelock.schedule(target, value, data, predecessor, salt, delay)`.
 * Once enough signers confirm, the same transaction id can be executed after the delay.
 *
 * Environment variables:
 *   PROPOSAL_TARGET      address to be called by the timelock
 *   PROPOSAL_VALUE       native value to send (default: 0)
 *   PROPOSAL_DATA        ABI-encoded calldata (hex string, default: 0x)
 *   PROPOSAL_PREDECESSOR previous operation id (default: 0x0000...0000)
 *   PROPOSAL_SALT        salt used to generate the operation id (default: 0x0000...0000)
 *   PROPOSAL_DELAY       timelock delay in seconds (default: timelock minDelay)
 */
export async function proposeAdminCall() {
  const network = await ethers.provider.getNetwork();
  const chainId = Number(network.chainId);

  const signer = await getGovernanceSigner();
  await printSigner(signer);

  const governanceDeployments = new Deployments(chainId, "governance");
  const governance = governanceDeployments.get(chainId);
  if (!governance || !governance.timelock || !governance.multisig) {
    throw new Error("Governance deployment not found. Run deployGovernance.ts first.");
  }

  const target = process.env.PROPOSAL_TARGET;
  if (!target || !ethers.isAddress(target)) {
    throw new Error("PROPOSAL_TARGET must be a valid address");
  }

  const value = process.env.PROPOSAL_VALUE ? BigInt(process.env.PROPOSAL_VALUE) : 0n;
  const data = process.env.PROPOSAL_DATA || "0x";
  const predecessor = (process.env.PROPOSAL_PREDECESSOR || ethers.ZeroHash) as string;
  const salt = (process.env.PROPOSAL_SALT || ethers.ZeroHash) as string;

  const timelock = await ethers.getContractAt("AlloTimelockController", governance.timelock, signer);
  const minDelay = await timelock.getMinDelay();
  const delay = process.env.PROPOSAL_DELAY ? BigInt(process.env.PROPOSAL_DELAY) : minDelay;

  if (delay < minDelay) {
    throw new Error(`PROPOSAL_DELAY (${delay}) is lower than timelock minimum (${minDelay})`);
  }

  const scheduleData = timelock.interface.encodeFunctionData("schedule", [
    target,
    value,
    data,
    predecessor,
    salt,
    delay,
  ]);

  const operationId = await timelock.hashOperation(target, value, data, predecessor, salt);

  console.log(`\nScheduling administrative call on ${hre.network.name} (${chainId})\n`);

  await confirmContinue({
    operation: "Schedule timelock operation via multisig",
    chainId,
    network: hre.network.name,
    signer: await signer.getAddress(),
    timelock: governance.timelock,
    multisig: governance.multisig,
    target,
    value: value.toString(),
    data,
    predecessor,
    salt,
    delay: delay.toString(),
    operationId,
  });

  const multisig = await ethers.getContractAt("AlloMultisigWallet", governance.multisig, signer);
  const tx = await multisig.submitTransaction(governance.timelock, 0n, scheduleData);
  await tx.wait();

  // The transaction id equals the transactionCount after submission minus one.
  const transactionCount = await multisig.transactionCount();
  const transactionId = (transactionCount - 1n).toString();

  console.log("\nMultisig transaction submitted:");
  console.log("   Transaction id:", transactionId);
  console.log("   Timelock operation id:", operationId);
  console.log("   Confirm with:", `PROPOSAL_TX_ID=${transactionId} npx hardhat run scripts/governance/confirmProposal.ts --network ${hre.network.name}`);
  console.log("   Execute after delay with:", `PROPOSAL_TX_ID=${transactionId} npx hardhat run scripts/governance/executeProposal.ts --network ${hre.network.name}`);
}

if (require.main === module) {
  proposeAdminCall().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

// Example:
// PROPOSAL_TARGET=0x... PROPOSAL_DATA=0x... PROPOSAL_DELAY=172800 GOV_SIGNER_PRIVATE_KEY=0x... \
//   npx hardhat run scripts/governance/proposeAdminCall.ts --network sepolia
