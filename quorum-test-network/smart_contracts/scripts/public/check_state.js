const path = require('path');
const fs = require('fs-extra');
const ethers = require('ethers');

const { quorum } = require("../keys.js");
const host = quorum.rpcnode.url;

// Load deployment info
const deploymentPath = path.resolve(__dirname, '../../', 'deployments', 'bridge-v2-deployment.json');

async function main() {
  // Check if deployment exists
  if (!fs.existsSync(deploymentPath)) {
    console.log("No V2 deployment found. Run deploy_bridge_v2.js first.");
    process.exit(1);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentPath));
  const usdcpV2Json = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../', 'contracts', 'USDCpV2.json')));
  const bridgeV2Json = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../', 'contracts', 'PrivateBridgeV2.json')));

  const provider = new ethers.JsonRpcProvider(host);

  // Connect to contracts
  const usdcp = new ethers.Contract(deployment.contracts.USDCpV2, usdcpV2Json.abi, provider);
  const bridge = new ethers.Contract(deployment.contracts.PrivateBridgeV2, bridgeV2Json.abi, provider);

  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║           Private Chain State (Quorum)                     ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log("");

  // Network info
  const blockNumber = await provider.getBlockNumber();
  const network = await provider.getNetwork();
  console.log("┌─ Network ──────────────────────────────────────────────────┐");
  console.log("│  RPC:          ", host);
  console.log("│  Chain ID:     ", network.chainId.toString());
  console.log("│  Block Number: ", blockNumber);
  console.log("└────────────────────────────────────────────────────────────┘");
  console.log("");

  // Contract addresses
  console.log("┌─ Contracts ────────────────────────────────────────────────┐");
  console.log("│  USDCpV2:        ", deployment.contracts.USDCpV2);
  console.log("│  PrivateBridgeV2:", deployment.contracts.PrivateBridgeV2);
  console.log("│  Deployed:       ", deployment.deployedAt);
  console.log("└────────────────────────────────────────────────────────────┘");
  console.log("");

  // USDCp state
  console.log("┌─ USDCpV2 State ────────────────────────────────────────────┐");
  const totalSupply = await usdcp.totalSupply();
  const name = await usdcp.name();
  const symbol = await usdcp.symbol();
  const decimals = await usdcp.decimals();
  const bridge_addr = await usdcp.bridge();
  const owner = await usdcp.owner();
  const paused = await usdcp.paused();

  console.log("│  Name:         ", name);
  console.log("│  Symbol:       ", symbol);
  console.log("│  Decimals:     ", decimals.toString());
  console.log("│  Total Supply: ", ethers.formatUnits(totalSupply, 6), "USDCp");
  console.log("│  Bridge:       ", bridge_addr);
  console.log("│  Owner:        ", owner);
  console.log("│  Paused:       ", paused);
  console.log("└────────────────────────────────────────────────────────────┘");
  console.log("");

  // Bridge state
  console.log("┌─ PrivateBridgeV2 State ────────────────────────────────────┐");
  const bridgeOwner = await bridge.owner();
  const bridgePaused = await bridge.paused();
  const usdcpAddr = await bridge.usdcp();
  const withdrawNonce = await bridge.withdrawNonce();
  const minDeposit = await bridge.minDepositAmount();
  const maxDeposit = await bridge.maxDepositAmount();
  const minWithdraw = await bridge.minWithdrawAmount();
  const maxWithdraw = await bridge.maxWithdrawAmount();

  console.log("│  Owner:          ", bridgeOwner);
  console.log("│  Paused:         ", bridgePaused);
  console.log("│  USDCp:          ", usdcpAddr);
  console.log("│  Withdraw Nonce: ", withdrawNonce.toString());
  console.log("│  Min Deposit:    ", ethers.formatUnits(minDeposit, 6), "USDC");
  console.log("│  Max Deposit:    ", ethers.formatUnits(maxDeposit, 6), "USDC");
  console.log("│  Min Withdraw:   ", ethers.formatUnits(minWithdraw, 6), "USDC");
  console.log("│  Max Withdraw:   ", ethers.formatUnits(maxWithdraw, 6), "USDC");
  console.log("└────────────────────────────────────────────────────────────┘");
  console.log("");

  // Check balances of known accounts
  console.log("┌─ Balances ─────────────────────────────────────────────────┐");
  const operator = deployment.deployer;
  const operatorBalance = await usdcp.balanceOf(operator);
  const operatorEth = await provider.getBalance(operator);

  console.log("│  Operator:", operator);
  console.log("│    USDCp: ", ethers.formatUnits(operatorBalance, 6));
  console.log("│    ETH:   ", ethers.formatEther(operatorEth));

  // Check if operator is registered
  const isOperator = await bridge.operators(operator);
  console.log("│    Is Bridge Operator:", isOperator);
  console.log("└────────────────────────────────────────────────────────────┘");
  console.log("");

  // Optional: Check specific address
  const args = process.argv.slice(2);
  if (args.length > 0) {
    console.log("┌─ Custom Address Check ────────────────────────────────────┐");
    for (const addr of args) {
      if (ethers.isAddress(addr)) {
        const bal = await usdcp.balanceOf(addr);
        const eth = await provider.getBalance(addr);
        console.log("│ ", addr);
        console.log("│    USDCp:", ethers.formatUnits(bal, 6));
        console.log("│    ETH:  ", ethers.formatEther(eth));
      } else {
        console.log("│  Invalid address:", addr);
      }
    }
    console.log("└────────────────────────────────────────────────────────────┘");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
