import hre, { ethers, upgrades } from "hardhat";
import { confirmContinue, Deployments, getImplementationAddress } from "../utils/scripts";
import { getGovernanceSigner, printSigner } from "./utils";
import ProxyAdminAbi from "@openzeppelin/upgrades-core/artifacts/@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol/ProxyAdmin.json";

/**
 * Prepares a governance proposal to upgrade the Allo proxy through the timelock.
 *
 * Workflow:
 *   1. Validate the new implementation against the current proxy storage layout.
 *   2. Deploy the new implementation using prepareUpgrade.
 *   3. Encode `ProxyAdmin.upgradeAndCall(proxy, newImpl, migrationData)`.
 *   4. Submit a multisig transaction to schedule the timelock operation.
 *
 * After enough signers confirm, wait for the timelock delay, then run
 * executeProposal.ts with the returned transaction id.
 *
 * Environment variables:
 *   PROPOSAL_SALT        optional salt for the timelock operation
 *   PROPOSAL_PREDECESSOR optional predecessor operation id
 */
export async function upgradeAlloViaGovernance() {
  const network = await ethers.provider.getNetwork();
  const chainId = Number(network.chainId);

  const signer = await getGovernanceSigner();
  await printSigner(signer);

  const alloDeployments = new Deployments(chainId, "allo");
  const governanceDeployments = new Deployments(chainId, "governance");
  const governance = governanceDeployments.get(chainId);
  const proxyAddress = alloDeployments.getAllo();

  if (!governance || !governance.timelock || !governance.multisig) {
    throw new Error("Governance deployment not found. Run deployGovernance.ts first.");
  }
  if (!proxyAddress || proxyAddress === ethers.ZeroAddress) {
    throw new Error("Allo proxy address not found in deployments");
  }

  console.log(`\nPreparing Allo upgrade proposal on ${hre.network.name} (${chainId})\n`);

  // 1. Validate storage layout with the new implementation.
  console.log("1/4 Validating storage layout...");
  const AlloV2 = await ethers.getContractFactory("Allo", signer);
  await upgrades.validateUpgrade(proxyAddress, AlloV2, { kind: "transparent" });
  console.log("   Storage layout validated");

  // 2. Deploy the new implementation.
  console.log("2/4 Deploying new Allo implementation...");
  const newImplementation = await upgrades.prepareUpgrade(proxyAddress, AlloV2, {
    kind: "transparent",
  });
  if (typeof newImplementation !== "string") {
    throw new Error("prepareUpgrade did not return an address");
  }
  console.log("   New implementation:", newImplementation);

  // 3. Build migration calldata: initializeGoFPatterns() is the post-upgrade reinitializer.
  const migrationData = AlloV2.interface.encodeFunctionData("initializeGoFPatterns");

  // 4. Build ProxyAdmin.upgradeAndCall calldata.
  const proxyAdminAddress = await upgrades.erc1967.getAdminAddress(proxyAddress);
  const proxyAdmin = new ethers.Contract(proxyAdminAddress, ProxyAdminAbi.abi, signer);
  const proxyAdminOwner = await proxyAdmin.owner();

  if (proxyAdminOwner.toLowerCase() !== governance.timelock.toLowerCase()) {
    throw new Error(
      `ProxyAdmin owner is ${proxyAdminOwner}, expected timelock ${governance.timelock}. Run transferOwnershipToGovernance.ts first.`,
    );
  }

  const upgradeData = proxyAdmin.interface.encodeFunctionData("upgradeAndCall", [
    proxyAddress,
    newImplementation,
    migrationData,
  ]);

  // 5. Schedule through the timelock via the multisig.
  const timelock = await ethers.getContractAt("AlloTimelockController", governance.timelock, signer);
  const minDelay = await timelock.getMinDelay();
  const predecessor = (process.env.PROPOSAL_PREDECESSOR || ethers.ZeroHash) as string;
  const salt = (process.env.PROPOSAL_SALT || ethers.hexlify(ethers.randomBytes(32))) as string;

  const scheduleData = timelock.interface.encodeFunctionData("schedule", [
    proxyAdminAddress,
    0n,
    upgradeData,
    predecessor,
    salt,
    minDelay,
  ]);

  const operationId = await timelock.hashOperation(
    proxyAdminAddress,
    0n,
    upgradeData,
    predecessor,
    salt,
  );

  console.log("3/4 Operation ready for scheduling");
  console.log("   ProxyAdmin:", proxyAdminAddress);
  console.log("   Migration data:", migrationData);
  console.log("   Timelock operation id:", operationId);
  console.log("   Min delay:", minDelay.toString(), "seconds");

  await confirmContinue({
    operation: "Schedule Allo upgrade through timelock",
    chainId,
    network: hre.network.name,
    signer: await signer.getAddress(),
    proxy: proxyAddress,
    newImplementation,
    proxyAdmin: proxyAdminAddress,
    migrationFunction: "initializeGoFPatterns",
    timelock: governance.timelock,
    multisig: governance.multisig,
    operationId,
  });

  // 6. Submit the schedule call as a multisig transaction.
  const multisig = await ethers.getContractAt("AlloMultisigWallet", governance.multisig, signer);
  const tx = await multisig.submitTransaction(governance.timelock, 0n, scheduleData);
  await tx.wait();

  const transactionCount = await multisig.transactionCount();
  const transactionId = (transactionCount - 1n).toString();

  console.log("4/4 Multisig transaction submitted");
  console.log("   Transaction id:", transactionId);
  console.log("   Confirm with:", `PROPOSAL_TX_ID=${transactionId} npx hardhat run scripts/governance/confirmProposal.ts --network ${hre.network.name}`);
  console.log("   Execute after timelock delay with:", `PROPOSAL_TX_ID=${transactionId} npx hardhat run scripts/governance/executeProposal.ts --network ${hre.network.name}`);

  // Save the new implementation address in the deployment record for reference.
  const existing = alloDeployments.get(chainId);
  existing.proposedImplementation = newImplementation;
  existing.proposedUpgradeOperationId = operationId;
  alloDeployments.write(existing);
}

if (require.main === module) {
  upgradeAlloViaGovernance().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

// Example:
// GOV_SIGNER_PRIVATE_KEY=0x... \
//   npx hardhat run scripts/governance/upgradeAlloViaGovernance.ts --network sepolia
