import hre, { ethers, upgrades } from "hardhat";
import { confirmContinue, Deployments } from "../utils/scripts";
import { getGovernanceSigner, printSigner } from "./utils";
import ProxyAdminAbi from "@openzeppelin/upgrades-core/artifacts/@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol/ProxyAdmin.json";

/**
 * Transfers ownership of the Allo protocol contracts to the timelock:
 *   - Allo.owner() -> timelock
 *   - Registry.ALLO_OWNER -> timelock
 *   - Transparent proxy admin -> timelock
 *
 * This script must be executed by the current deployer/owner EOA.
 * After execution, no single EOA can change protocol parameters or upgrade
 * the proxies without going through the multisig + 48h timelock.
 */
export async function transferOwnershipToGovernance() {
  const network = await ethers.provider.getNetwork();
  const networkName = hre.network.name;
  const chainId = Number(network.chainId);

  const signer = await getGovernanceSigner();
  await printSigner(signer);

  const governanceDeployments = new Deployments(chainId, "governance");
  const alloDeployments = new Deployments(chainId, "allo");
  const registryDeployments = new Deployments(chainId, "registry");
  const governance = governanceDeployments.get(chainId);
  if (!governance || !governance.timelock) {
    throw new Error("Governance deployment not found. Run deployGovernance.ts first.");
  }
  const timelockAddress = governance.timelock;

  const alloAddress = alloDeployments.getAllo();
  const registryAddress = registryDeployments.getRegistry();
  if (!ethers.isAddress(alloAddress) || alloAddress === ethers.ZeroAddress) {
    throw new Error("Allo proxy address not found in deployments");
  }
  if (!ethers.isAddress(registryAddress) || registryAddress === ethers.ZeroAddress) {
    throw new Error("Registry proxy address not found in deployments");
  }

  const allo = await ethers.getContractAt("Allo", alloAddress, signer);
  const registry = await ethers.getContractAt("Registry", registryAddress, signer);

  const currentAlloOwner = await allo.owner();
  const currentRegistryOwner = await registry.hasRole(
    await registry.ALLO_OWNER(),
    await signer.getAddress(),
  );

  console.log(`\nTransferring ownership to governance timelock on ${networkName} (${chainId})\n`);

  await confirmContinue({
    operation: "Transfer protocol ownership to timelock",
    chainId,
    network: networkName,
    signer: await signer.getAddress(),
    timelock: timelockAddress,
    alloProxy: alloAddress,
    registryProxy: registryAddress,
    currentAlloOwner,
    signerHasRegistryOwner: currentRegistryOwner,
  });

  // 1. Transfer Allo ownership to timelock.
  console.log("1/3 Transferring Allo ownership to timelock...");
  await (await allo.transferOwnership(timelockAddress)).wait();
  if ((await allo.owner()) !== timelockAddress) {
    throw new Error("Allo ownership transfer failed");
  }
  console.log("   Allo owner() is now timelock:", await allo.owner());

  // 2. Transfer Registry ALLO_OWNER to timelock.
  console.log("2/3 Transferring Registry ALLO_OWNER to timelock...");
  await (await registry.transferAlloOwner(timelockAddress)).wait();
  const timelockHasRole = await registry.hasRole(await registry.ALLO_OWNER(), timelockAddress);
  if (!timelockHasRole) {
    throw new Error("Registry ALLO_OWNER transfer failed");
  }
  const signerStillHasRole = await registry.hasRole(await registry.ALLO_OWNER(), await signer.getAddress());
  if (signerStillHasRole) {
    throw new Error("Old Registry ALLO_OWNER role was not revoked");
  }
  console.log("   Registry ALLO_OWNER transferred to timelock");

  // 3. Transfer transparent proxy admin ownership to timelock.
  console.log("3/3 Transferring proxy admin ownership to timelock...");
  const alloProxyAdminAddress = await upgrades.erc1967.getAdminAddress(alloAddress);
  const registryProxyAdminAddress = await upgrades.erc1967.getAdminAddress(registryAddress);

  const proxyAdmin = new ethers.Contract(
    alloProxyAdminAddress,
    ProxyAdminAbi.abi,
    signer,
  );

  const currentProxyAdminOwner = await proxyAdmin.owner();
  console.log("   Current proxy admin:", alloProxyAdminAddress);
  console.log("   Current proxy admin owner:", currentProxyAdminOwner);

  if (currentProxyAdminOwner.toLowerCase() !== (await signer.getAddress()).toLowerCase()) {
    throw new Error("Signer is not the current proxy admin owner");
  }

  await (await proxyAdmin.transferOwnership(timelockAddress)).wait();
  if ((await proxyAdmin.owner()).toLowerCase() !== timelockAddress.toLowerCase()) {
    throw new Error("Proxy admin ownership transfer failed");
  }
  console.log("   Proxy admin owner is now timelock:", await proxyAdmin.owner());

  console.log("\nOwnership transfer complete. The protocol is now governed by:");
  console.log("   Timelock:", timelockAddress);
  console.log("   Multisig:", governance.multisig);
  console.log("   Threshold:", governance.threshold, "of", governance.signers.length);
}

if (require.main === module) {
  transferOwnershipToGovernance().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

// Example usage:
// GOV_SIGNER_PRIVATE_KEY=0x... npx hardhat run scripts/governance/transferOwnershipToGovernance.ts --network sepolia
