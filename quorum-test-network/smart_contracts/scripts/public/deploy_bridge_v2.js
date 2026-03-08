const path = require('path');
const fs = require('fs-extra');
const ethers = require('ethers');

// RPCNODE details
const { quorum } = require("../keys.js");
const host = quorum.rpcnode.url;
const accountPrivateKey = quorum.rpcnode.accountPrivateKey;

// Load compiled contracts
const usdcpV2JsonPath = path.resolve(__dirname, '../../', 'contracts', 'USDCpV2.json');
const bridgeV2JsonPath = path.resolve(__dirname, '../../', 'contracts', 'PrivateBridgeV2.json');

const usdcpV2Json = JSON.parse(fs.readFileSync(usdcpV2JsonPath));
const bridgeV2Json = JSON.parse(fs.readFileSync(bridgeV2JsonPath));

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
  console.log("Bridge V2 System Deployment");
  console.log("=".repeat(60));
  console.log("Deployer:", wallet.address);
  console.log("Network:", host);
  console.log("");

  // V2 contracts require non-zero addresses in constructor
  // Strategy: Deploy USDCpV2 with deployer as temp bridge, then deploy Bridge, then update

  // Step 1: Deploy USDCpV2 with deployer as temporary bridge
  console.log("[1/4] Deploying USDCpV2 (with deployer as temp bridge)...");
  const usdcp = await deployContract(
    wallet,
    usdcpV2Json.abi,
    usdcpV2Json.evm.bytecode.object,
    wallet.address // Deployer as temporary bridge
  );
  const usdcpAddress = await usdcp.getAddress();
  console.log("      USDCpV2 deployed at:", usdcpAddress);

  // Step 2: Deploy PrivateBridgeV2 with USDCp address
  console.log("[2/4] Deploying PrivateBridgeV2...");
  const bridge = await deployContract(
    wallet,
    bridgeV2Json.abi,
    bridgeV2Json.evm.bytecode.object,
    usdcpAddress
  );
  const bridgeAddress = await bridge.getAddress();
  console.log("      PrivateBridgeV2 deployed at:", bridgeAddress);

  // Step 3: Update USDCpV2's bridge address
  console.log("[3/4] Setting correct bridge address in USDCpV2...");
  const tx1 = await usdcp.setBridge(bridgeAddress);
  await tx1.wait();
  console.log("      USDCpV2 bridge updated!");

  // Step 4: Verify configuration
  console.log("[4/4] Verifying configuration...");
  const actualBridge = await usdcp.bridge();
  const actualUsdcp = await bridge.usdcp();
  console.log("      USDCpV2.bridge:", actualBridge);
  console.log("      Bridge.usdcp:", actualUsdcp);

  console.log("");
  console.log("=".repeat(60));
  console.log("Deployment Complete!");
  console.log("=".repeat(60));
  console.log("");
  console.log("Contract Addresses:");
  console.log("  USDCpV2:         ", usdcpAddress);
  console.log("  PrivateBridgeV2: ", bridgeAddress);
  console.log("");
  console.log("Owner/Operator:  ", wallet.address);
  console.log("");

  // Save deployment info
  const deploymentInfo = {
    network: "quorum-private",
    version: "v2",
    deployedAt: new Date().toISOString(),
    contracts: {
      USDCpV2: usdcpAddress,
      PrivateBridgeV2: bridgeAddress
    },
    deployer: wallet.address
  };

  const deploymentPath = path.resolve(__dirname, '../../', 'deployments', 'bridge-v2-deployment.json');
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
