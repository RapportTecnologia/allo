import hre, { ethers } from "hardhat";
import { confirmContinue, Deployments } from "../utils/scripts";
import { loadGovernanceConfig } from "./config";
import { getGovernanceSigner, printSigner } from "./utils";

/**
 * Deploys the Allo protocol governance layer:
 *   1. AlloTimelockController (minimum 48h delay)
 *   2. AlloMultisigWallet (M-of-N signers)
 *
 * After deployment the deployer renounces the timelock admin role,
 * leaving the multisig as the sole proposer/executor/canceller.
 */
export async function deployGovernance() {
  const network = await ethers.provider.getNetwork();
  const networkName = hre.network.name;
  const chainId = Number(network.chainId);

  const signer = await getGovernanceSigner();
  await printSigner(signer);

  const { signers, threshold, minDelay } = loadGovernanceConfig();

  const deployments = new Deployments(chainId, "governance");

  console.log(`\nDeploying governance contracts on ${networkName} (${chainId})\n`);

  await confirmContinue({
    contract: "Governance Layer",
    chainId,
    network: networkName,
    signer: await signer.getAddress(),
    signers: signers.join(", "),
    threshold,
    minDelaySeconds: minDelay,
    minDelayHours: (minDelay / 3600).toFixed(2),
  });

  // 1. Deploy timelock with empty proposers/executors; deployer is admin temporarily.
  console.log("1/3 Deploying AlloTimelockController...");
  const TimelockFactory = await ethers.getContractFactory("AlloTimelockController", signer);
  const timelock = await TimelockFactory.deploy(minDelay, [], [], await signer.getAddress());
  await timelock.waitForDeployment();
  const timelockAddress = await timelock.getAddress();
  console.log("   AlloTimelockController deployed to:", timelockAddress);

  // 2. Deploy multisig wallet linked to the timelock.
  console.log("2/3 Deploying AlloMultisigWallet...");
  const MultisigFactory = await ethers.getContractFactory("AlloMultisigWallet", signer);
  const multisig = await MultisigFactory.deploy(signers, threshold, timelockAddress);
  await multisig.waitForDeployment();
  const multisigAddress = await multisig.getAddress();
  console.log("   AlloMultisigWallet deployed to:", multisigAddress);

  // 3. Register the multisig as proposer, executor and canceller, then renounce deployer admin.
  console.log("3/3 Configuring timelock roles...");
  const proposerRole = await timelock.PROPOSER_ROLE();
  const executorRole = await timelock.EXECUTOR_ROLE();
  const cancellerRole = await timelock.CANCELLER_ROLE();
  const adminRole = await timelock.TIMELOCK_ADMIN_ROLE();

  await (await timelock.grantRole(proposerRole, multisigAddress)).wait();
  await (await timelock.grantRole(executorRole, multisigAddress)).wait();
  await (await timelock.grantRole(cancellerRole, multisigAddress)).wait();
  await (await timelock.renounceRole(adminRole, await signer.getAddress())).wait();

  console.log("   Multisig registered as proposer/executor/canceller");
  console.log("   Deployer renounced TIMELOCK_ADMIN_ROLE");

  const objToWrite = {
    name: "Governance",
    chainId,
    network: networkName,
    timelock: timelockAddress,
    multisig: multisigAddress,
    signers,
    threshold,
    minDelay,
    deployer: await signer.getAddress(),
  };
  deployments.write(objToWrite);

  console.log("\nGovernance deployment recorded in scripts/deployments/governance.deployment.json");
  console.log("Timelock:", timelockAddress);
  console.log("Multisig: ", multisigAddress);
}

if (require.main === module) {
  deployGovernance().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

// Example usage:
// GOV_SIGNERS=0x...,0x...,0x... GOV_THRESHOLD=2 GOV_SIGNER_PRIVATE_KEY=0x... \
//   npx hardhat run scripts/governance/deployGovernance.ts --network sepolia
