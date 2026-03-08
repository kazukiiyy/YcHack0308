const path = require('path');
const fs = require('fs-extra');
const ethers = require('ethers');

// RPCNODE details
const { quorum } = require("../keys.js");
const host = quorum.rpcnode.url;
const wsHost = quorum.rpcnode.wsUrl;
const accountPrivateKey = quorum.rpcnode.accountPrivateKey;

// Load deployment info
const deploymentPath = path.resolve(__dirname, '../../', 'deployments', 'bridge-v2-deployment.json');
const deployment = JSON.parse(fs.readFileSync(deploymentPath));

// Load contract ABIs
const usdcpV2Json = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../', 'contracts', 'USDCpV2.json')));
const bridgeV2Json = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../', 'contracts', 'PrivateBridgeV2.json')));

async function main() {
  // HTTP provider for transactions
  const httpProvider = new ethers.JsonRpcProvider(host);
  const operatorWallet = new ethers.Wallet(accountPrivateKey, httpProvider);

  // WebSocket provider for events
  const wsProvider = new ethers.WebSocketProvider(wsHost);

  // Create a test user wallet
  const userWallet = ethers.Wallet.createRandom().connect(httpProvider);
  const userAddress = userWallet.address;

  console.log("=".repeat(60));
  console.log("Bridge V2 Test with Event Listener");
  console.log("=".repeat(60));
  console.log("HTTP RPC:", host);
  console.log("WebSocket:", wsHost);
  console.log("Operator:", operatorWallet.address);
  console.log("Test User:", userAddress);
  console.log("");
  console.log("Contracts:");
  console.log("  USDCpV2:", deployment.contracts.USDCpV2);
  console.log("  PrivateBridgeV2:", deployment.contracts.PrivateBridgeV2);
  console.log("");

  // Connect to contracts (HTTP for tx)
  const usdcp = new ethers.Contract(deployment.contracts.USDCpV2, usdcpV2Json.abi, operatorWallet);
  const bridge = new ethers.Contract(deployment.contracts.PrivateBridgeV2, bridgeV2Json.abi, operatorWallet);

  // Connect to contracts (WebSocket for events)
  const usdcpWs = new ethers.Contract(deployment.contracts.USDCpV2, usdcpV2Json.abi, wsProvider);
  const bridgeWs = new ethers.Contract(deployment.contracts.PrivateBridgeV2, bridgeV2Json.abi, wsProvider);

  // ============ Setup Event Listeners ============
  console.log("=".repeat(60));
  console.log("Setting up Event Listeners...");
  console.log("=".repeat(60));

  const receivedEvents = [];

  // USDCp Events
  usdcpWs.on("Transfer", (from, to, value, event) => {
    const eventData = {
      type: "TRANSFER",
      from,
      to,
      value: ethers.formatUnits(value, 6),
      blockNumber: event.log.blockNumber,
      txHash: event.log.transactionHash
    };
    receivedEvents.push(eventData);
    console.log("\n[EVENT] Transfer:", JSON.stringify(eventData, null, 2));
  });

  usdcpWs.on("Mint", (to, amount, depositId, event) => {
    const eventData = {
      type: "MINT",
      to,
      amount: ethers.formatUnits(amount, 6),
      depositId,
      blockNumber: event.log.blockNumber,
      txHash: event.log.transactionHash
    };
    receivedEvents.push(eventData);
    console.log("\n[EVENT] Mint:", JSON.stringify(eventData, null, 2));
  });

  usdcpWs.on("Burn", (from, amount, withdrawId, event) => {
    const eventData = {
      type: "BURN",
      from,
      amount: ethers.formatUnits(amount, 6),
      withdrawId,
      blockNumber: event.log.blockNumber,
      txHash: event.log.transactionHash
    };
    receivedEvents.push(eventData);
    console.log("\n[EVENT] Burn:", JSON.stringify(eventData, null, 2));
  });

  // Bridge Events
  bridgeWs.on("DepositProcessed", (depositId, recipient, amount, publicChainTxHash, event) => {
    const eventData = {
      type: "DEPOSIT_PROCESSED",
      depositId,
      recipient,
      amount: ethers.formatUnits(amount, 6),
      publicChainTxHash,
      blockNumber: event.log.blockNumber,
      txHash: event.log.transactionHash
    };
    receivedEvents.push(eventData);
    console.log("\n[EVENT] DepositProcessed:", JSON.stringify(eventData, null, 2));
  });

  bridgeWs.on("WithdrawRequested", (withdrawId, from, amount, publicChainRecipient, event) => {
    const eventData = {
      type: "WITHDRAW_REQUESTED",
      withdrawId,
      from,
      amount: ethers.formatUnits(amount, 6),
      publicChainRecipient,
      blockNumber: event.log.blockNumber,
      txHash: event.log.transactionHash
    };
    receivedEvents.push(eventData);
    console.log("\n[EVENT] WithdrawRequested:", JSON.stringify(eventData, null, 2));
  });

  bridgeWs.on("WithdrawProcessed", (withdrawId, event) => {
    const eventData = {
      type: "WITHDRAW_PROCESSED",
      withdrawId,
      blockNumber: event.log.blockNumber,
      txHash: event.log.transactionHash
    };
    receivedEvents.push(eventData);
    console.log("\n[EVENT] WithdrawProcessed:", JSON.stringify(eventData, null, 2));
  });

  console.log("Event listeners ready!");
  console.log("");

  // Wait a moment for listeners to be ready
  await new Promise(resolve => setTimeout(resolve, 1000));

  // ============ Test 1: Deposit (Public -> Private) ============
  console.log("=".repeat(60));
  console.log("TEST 1: processDeposit (Operator mints USDCp)");
  console.log("=".repeat(60));

  const depositAmount = ethers.parseUnits("1000", 6); // 1000 USDC (6 decimals)
  const fakePublicTxHash = ethers.keccak256(ethers.toUtf8Bytes("sepolia_lock_tx_001"));

  console.log("Processing deposit:");
  console.log("  Recipient:", userAddress);
  console.log("  Amount:", ethers.formatUnits(depositAmount, 6), "USDCp");
  console.log("  Public Chain TX:", fakePublicTxHash);

  const depositTx = await bridge.processDeposit(userAddress, depositAmount, fakePublicTxHash);
  console.log("  TX Hash:", depositTx.hash);
  console.log("  Waiting for confirmation...");

  await depositTx.wait();
  console.log("  Status: CONFIRMED");

  // Check balance
  const balanceAfterDeposit = await usdcp.balanceOf(userAddress);
  console.log("  User USDCp Balance:", ethers.formatUnits(balanceAfterDeposit, 6));
  console.log("");

  // Wait for events to propagate
  await new Promise(resolve => setTimeout(resolve, 2000));

  // ============ Test 2: Transfer ============
  console.log("=".repeat(60));
  console.log("TEST 2: Transfer USDCp");
  console.log("=".repeat(60));

  // Fund user with some ETH for gas
  const fundTx = await operatorWallet.sendTransaction({
    to: userAddress,
    value: ethers.parseEther("1.0")
  });
  await fundTx.wait();
  console.log("  Funded user with 1 ETH for gas");

  // User transfers some USDCp
  const usdcpAsUser = usdcp.connect(userWallet);
  const transferAmount = ethers.parseUnits("100", 6);
  console.log("  User transferring", ethers.formatUnits(transferAmount, 6), "USDCp to operator...");

  const transferTx = await usdcpAsUser.transfer(operatorWallet.address, transferAmount);
  await transferTx.wait();

  console.log("  User Balance:", ethers.formatUnits(await usdcp.balanceOf(userAddress), 6));
  console.log("  Operator Balance:", ethers.formatUnits(await usdcp.balanceOf(operatorWallet.address), 6));
  console.log("");

  await new Promise(resolve => setTimeout(resolve, 2000));

  // ============ Test 3: Withdraw ============
  console.log("=".repeat(60));
  console.log("TEST 3: requestWithdraw (Burn USDCp)");
  console.log("=".repeat(60));

  const withdrawAmount = ethers.parseUnits("500", 6);
  const publicChainRecipient = "0x1234567890123456789012345678901234567890";

  console.log("Requesting withdrawal:");
  console.log("  From:", userAddress);
  console.log("  Amount:", ethers.formatUnits(withdrawAmount, 6), "USDCp");
  console.log("  Public Chain Recipient:", publicChainRecipient);

  const bridgeAsUser = bridge.connect(userWallet);
  const withdrawTx = await bridgeAsUser.requestWithdraw(withdrawAmount, publicChainRecipient);
  console.log("  TX Hash:", withdrawTx.hash);

  const withdrawReceipt = await withdrawTx.wait();

  // Parse WithdrawRequested event from receipt
  const withdrawEvent = withdrawReceipt.logs.find(log => {
    try {
      return bridge.interface.parseLog(log)?.name === 'WithdrawRequested';
    } catch { return false; }
  });
  const parsedEvent = bridge.interface.parseLog(withdrawEvent);
  const withdrawId = parsedEvent.args.withdrawId;

  console.log("  Withdraw ID:", withdrawId);
  console.log("  User Balance After Burn:", ethers.formatUnits(await usdcp.balanceOf(userAddress), 6));
  console.log("");

  await new Promise(resolve => setTimeout(resolve, 2000));

  // ============ Summary ============
  console.log("=".repeat(60));
  console.log("Event Summary");
  console.log("=".repeat(60));
  console.log("Total events received:", receivedEvents.length);
  console.log("");
  receivedEvents.forEach((event, i) => {
    console.log(`[${i + 1}] ${event.type}`);
  });
  console.log("");

  console.log("=".repeat(60));
  console.log("Final State");
  console.log("=".repeat(60));
  console.log("Total Supply:", ethers.formatUnits(await usdcp.totalSupply(), 6), "USDCp");
  console.log("User Balance:", ethers.formatUnits(await usdcp.balanceOf(userAddress), 6), "USDCp");
  console.log("Operator Balance:", ethers.formatUnits(await usdcp.balanceOf(operatorWallet.address), 6), "USDCp");
  console.log("");
  console.log("All tests passed!");

  // Cleanup
  wsProvider.destroy();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
