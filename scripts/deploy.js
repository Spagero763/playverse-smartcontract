const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

  const PlayverseStake = await ethers.getContractFactory("PlayverseStake");
  const contract = await PlayverseStake.deploy();
  await contract.waitForDeployment();

  console.log("PlayverseStake deployed to:", await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
