import hre, { ethers, upgrades } from "hardhat";
import {
  Deployments,
  confirmContinue,
  getImplementationAddress,
  verifyContract
} from "../../utils/scripts";

export async function upgradeAllo() {
  const network = await ethers.provider.getNetwork();
  const networkName = await hre.network.name;
  let account;
  let accountAddress;
  const chainId = Number(network.chainId);

  account = (await ethers.getSigners())[0];
  accountAddress = await account.getAddress();
  const balance = await ethers.provider.getBalance(accountAddress);

  const deployments = new Deployments(chainId, "allo");
  const proxyAddress = deployments.getAllo();

  console.log(`This script upgrades the Allo contract on ${networkName}`);

  await confirmContinue({
    contract: "Upgrading Allo",
    chainId: network.chainId,
    network: network.name,
    account: accountAddress,
    balance: ethers.formatEther(balance),
    proxy: proxyAddress,
    migration: "initializeGoFPatterns",
  });

  if (balance === 0n) {
    throw new Error("Upgrade account has no native balance for transaction fees");
  }

  console.log("Validating Allo storage layout...");

  const AlloV2 = await ethers.getContractFactory("Allo", account);
  await upgrades.validateUpgrade(proxyAddress, AlloV2, {
    kind: "transparent",
  });

  console.log("Upgrading Allo and executing migration atomically...");

  const instance = await upgrades.upgradeProxy(proxyAddress, AlloV2, {
    call: "initializeGoFPatterns",
    kind: "transparent",
  });

  await instance.waitForDeployment();

  const implementation = await getImplementationAddress(
    instance.target as string
  );

  const objectToWrite = deployments.get(chainId);
  objectToWrite.implementation = implementation;
  deployments.write(objectToWrite);

  await verifyContract(implementation, []);

  console.log("Allo Proxy Upgraded at:", instance.target);
  console.log("Allo implementation updated to:", implementation);
}

upgradeAllo().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// Note: Deploy script to run in terminal:
// npx hardhat run scripts/core/upgrades/upgradeAllo.ts --network sepolia