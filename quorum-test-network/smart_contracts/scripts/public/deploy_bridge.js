const path = require('path');
const fs = require('fs-extra');
const ethers = require('ethers');

// RPCNODE details
const { quorum } = require("../keys.js");
const host = quorum.rpcnode.url;
const accountPrivateKey = quorum.rpcnode.accountPrivateKey;

// Load compiled contracts
const usdcpJsonPath = path.resolve(__dirname, '../../', 'contracts', 'USDCp.json');
const bridgeJsonPath = path.resolve(__dirname, '../../', 'contracts', 'PrivateBridge.json');

const usdcpJson = JSON.parse(fs.readFileSync(usdcpJsonPath));
const bridgeJson = JSON.parse(fs.readFileSync(bridgeJsonPath));

async function deployContract(wallet, abi, bytecode, ...args) {
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  return contract;
}

async function main() {
  const provider = new ethers.JsonRpcProvider(host);
  const wallet = new ethers.Wallet(accountPrivateKey, provider);

  console.log("=".repeat(60));
  console.log("Bridge System Deployment");
  console.log("=".repeat(60));
  console.log("Deployer:", wallet.address);
  console.log("Network:", host);
  console.log("");

  // Step 1: Deploy PrivateBridge first (we'll set USDCp later)
  console.log("[1/3] Deploying PrivateBridge...");
  const bridge = await deployContract(
    wallet,
    bridgeJson.abi,
    bridgeJson.evm.bytecode.object,
    ethers.ZeroAddress // Temporary USDCp address
  );
  const bridgeAddress = await bridge.getAddress();
  console.log("      PrivateBridge deployed at:", bridgeAddress);

  // Step 2: Deploy USDCp with bridge address
  console.log("[2/3] Deploying USDCp...");
  const usdcp = await deployContract(
    wallet,
    usdcpJson.abi,
    usdcpJson.evm.bytecode.object,
    bridgeAddress
  );
  const usdcpAddress = await usdcp.getAddress();
  console.log("      USDCp deployed at:", usdcpAddress);

  // Step 3: Set USDCp address in Bridge
  console.log("[3/3] Configuring Bridge with USDCp address...");
  const tx = await bridge.setUSDCp(usdcpAddress);
  await tx.wait();
  console.log("      Bridge configured!");

  console.log("");
  console.log("=".repeat(60));
  console.log("Deployment Complete!");
  console.log("=".repeat(60));
  console.log("");
  console.log("Contract Addresses:");
  console.log("  USDCp:         ", usdcpAddress);
  console.log("  PrivateBridge: ", bridgeAddress);
  console.log("");
  console.log("Owner/Operator:  ", wallet.address);
  console.log("");

  // Save deployment info
  const deploymentInfo = {
    network: "quorum-private",
    deployedAt: new Date().toISOString(),
    contracts: {
      USDCp: usdcpAddress,
      PrivateBridge: bridgeAddress
    },
    deployer: wallet.address
  };

  const deploymentPath = path.resolve(__dirname, '../../', 'deployments', 'bridge-deployment.json');
  fs.ensureDirSync(path.dirname(deploymentPath));
  fs.writeJsonSync(deploymentPath, deploymentInfo, { spaces: 2 });
  console.log("Deployment info saved to:", deploymentPath);

  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
