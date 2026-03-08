const path = require('path');
const fs = require('fs-extra');
const ethers = require('ethers');

// RPCNODE details
const { quorum } = require("../keys.js");
const host = quorum.rpcnode.url;
const accountPrivateKey = quorum.rpcnode.accountPrivateKey;

// Load deployment info
const deploymentPath = path.resolve(__dirname, '../../', 'deployments', 'bridge-deployment.json');
const deployment = JSON.parse(fs.readFileSync(deploymentPath));

// Load contract ABIs
const usdcpJson = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../', 'contracts', 'USDCp.json')));
const bridgeJson = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../', 'contracts', 'PrivateBridge.json')));

async function main() {
  const provider = new ethers.JsonRpcProvider(host);
  const operatorWallet = new ethers.Wallet(accountPrivateKey, provider);

  // Create a test user wallet
  const userWallet = ethers.Wallet.createRandom().connect(provider);
  const userAddress = userWallet.address;

  console.log("=".repeat(60));
  console.log("Bridge Test Script");
  console.log("=".repeat(60));
  console.log("Operator:", operatorWallet.address);
  console.log("Test User:", userAddress);
  console.log("");

  // Connect to contracts
  const usdcp = new ethers.Contract(deployment.contracts.USDCp, usdcpJson.abi, operatorWallet);
  const bridge = new ethers.Contract(deployment.contracts.PrivateBridge, bridgeJson.abi, operatorWallet);

  // ============ Test 1: Deposit (Public -> Private) ============
  console.log("=".repeat(60));
  console.log("TEST 1: Simulate Deposit (USDC locked on public chain)");
  console.log("=".repeat(60));

  const depositAmount = ethers.parseUnits("1000", 6); // 1000 USDC (6 decimals)
  const fakePublicTxHash = ethers.keccak256(ethers.toUtf8Bytes("fake_public_chain_tx_001"));

  console.log("Processing deposit:");
  console.log("  Recipient:", userAddress);
  console.log("  Amount:", ethers.formatUnits(depositAmount, 6), "USDCp");
  console.log("  Public Chain TX:", fakePublicTxHash);

  const depositTx = await bridge.processDeposit(userAddress, depositAmount, fakePublicTxHash);
  const depositReceipt = await depositTx.wait();

  console.log("  TX Hash:", depositTx.hash);
  console.log("  Status: SUCCESS");

  // Check balance
  const balanceAfterDeposit = await usdcp.balanceOf(userAddress);
  console.log("  User USDCp Balance:", ethers.formatUnits(balanceAfterDeposit, 6));
  console.log("");

  // ============ Test 2: Transfer (within private chain) ============
  console.log("=".repeat(60));
  console.log("TEST 2: Transfer USDCp within Private Chain");
  console.log("=".repeat(60));

  // Fund user with some ETH for gas (operator sends ETH)
  const fundTx = await operatorWallet.sendTransaction({
    to: userAddress,
    value: ethers.parseEther("1.0")
  });
  await fundTx.wait();
  console.log("  Funded user with 1 ETH for gas");

  // User transfers some USDCp
  const usdcpAsUser = usdcp.connect(userWallet);
  const transferAmount = ethers.parseUnits("100", 6);
  const transferTx = await usdcpAsUser.transfer(operatorWallet.address, transferAmount);
  await transferTx.wait();

  console.log("  Transferred:", ethers.formatUnits(transferAmount, 6), "USDCp to operator");
  console.log("  User Balance:", ethers.formatUnits(await usdcp.balanceOf(userAddress), 6));
  console.log("  Operator Balance:", ethers.formatUnits(await usdcp.balanceOf(operatorWallet.address), 6));
  console.log("");

  // ============ Test 3: Withdraw (Private -> Public) ============
  console.log("=".repeat(60));
  console.log("TEST 3: Withdraw Request (burn USDCp, unlock USDC)");
  console.log("=".repeat(60));

  const withdrawAmount = ethers.parseUnits("500", 6);
  const publicChainRecipient = "0x1234567890123456789012345678901234567890"; // Fake public chain address

  console.log("Requesting withdrawal:");
  console.log("  From:", userAddress);
  console.log("  Amount:", ethers.formatUnits(withdrawAmount, 6), "USDCp");
  console.log("  Public Chain Recipient:", publicChainRecipient);

  const bridgeAsUser = bridge.connect(userWallet);
  const withdrawTx = await bridgeAsUser.requestWithdraw(withdrawAmount, publicChainRecipient);
  const withdrawReceipt = await withdrawTx.wait();

  // Parse WithdrawRequested event
  const withdrawEvent = withdrawReceipt.logs.find(log => {
    try {
      return bridge.interface.parseLog(log)?.name === 'WithdrawRequested';
    } catch { return false; }
  });
  const parsedEvent = bridge.interface.parseLog(withdrawEvent);
  const withdrawId = parsedEvent.args.withdrawId;

  console.log("  TX Hash:", withdrawTx.hash);
  console.log("  Withdraw ID:", withdrawId);
  console.log("  User Balance After Burn:", ethers.formatUnits(await usdcp.balanceOf(userAddress), 6));
  console.log("");

  // Operator marks withdrawal as processed (after unlocking on public chain)
  console.log("Operator marking withdrawal as processed...");
  const markTx = await bridge.markWithdrawProcessed(withdrawId);
  await markTx.wait();

  const withdrawRequest = await bridge.getWithdrawRequest(withdrawId);
  console.log("  Withdrawal processed:", withdrawRequest.processed);
  console.log("");

  // ============ Summary ============
  console.log("=".repeat(60));
  console.log("Summary");
  console.log("=".repeat(60));
  console.log("Total Supply:", ethers.formatUnits(await usdcp.totalSupply(), 6), "USDCp");
  console.log("User Balance:", ethers.formatUnits(await usdcp.balanceOf(userAddress), 6), "USDCp");
  console.log("Operator Balance:", ethers.formatUnits(await usdcp.balanceOf(operatorWallet.address), 6), "USDCp");
  console.log("");
  console.log("All tests passed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
