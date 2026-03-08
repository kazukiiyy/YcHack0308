const ethers = require('ethers');

// Sepolia config
const SEPOLIA_RPC = "https://ethereum-sepolia-rpc.publicnode.com";
const BRIDGE_VAULT_ADDRESS = "0xE69606565988E8A2bC9048ec22645670164Fab96";

// Operator private key (テスト用)
const PRIVATE_KEY = "0x9c5ad69214fa7bdfaa4ffce99e895257a1d95d92e682a7210ff710129320a299";

const ABI = [
  "function approveUnlock(bytes32 privateTxHash, address recipient, uint256 amount)",
  "event Unlocked(bytes32 indexed privateTxHash, address indexed recipient, uint256 amount)"
];

async function main() {
  console.log("═".repeat(60));
  console.log("  approveUnlock Test - Sepolia BridgeVault");
  console.log("═".repeat(60));

  const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const contract = new ethers.Contract(BRIDGE_VAULT_ADDRESS, ABI, wallet);

  // ネットワーク確認
  const network = await provider.getNetwork();
  const balance = await provider.getBalance(wallet.address);

  console.log("\n[Network]");
  console.log("  Chain ID:  ", network.chainId.toString());
  console.log("  Block:     ", await provider.getBlockNumber());

  console.log("\n[Wallet]");
  console.log("  Address:   ", wallet.address);
  console.log("  ETH Balance:", ethers.formatEther(balance), "ETH");

  if (balance === 0n) {
    console.error("\n❌ ETH残高が0です。Sepoliaのfaucetからガス代を取得してください。");
    console.error("   https://sepoliafaucet.com");
    process.exit(1);
  }

  // パラメータ設定
  // QuorumのWithdrawRequested txHash（前回のテストのもの）
  const privateTxHash = "0x46b9a0c536e48a8cc6c6f035077455cd1a0838a24d24782c2d998eedfb5e1591";
  const recipient = wallet.address; // 自分自身をrecipientとしてテスト
  const amount = ethers.parseUnits("1.0", 6); // 1 USDC (6 decimals)

  console.log("\n[approveUnlock パラメータ]");
  console.log("  privateTxHash:", privateTxHash);
  console.log("  recipient:    ", recipient);
  console.log("  amount:       ", ethers.formatUnits(amount, 6), "USDC");
  console.log("  Contract:     ", BRIDGE_VAULT_ADDRESS);

  console.log("\n[送信中...]");

  try {
    // ガス見積もり
    let gasEstimate;
    try {
      gasEstimate = await contract.approveUnlock.estimateGas(
        ethers.zeroPadBytes(privateTxHash, 32),
        recipient,
        amount
      );
      console.log("  Gas Estimate:", gasEstimate.toString());
    } catch (e) {
      console.log("  ⚠️  Gas見積もりエラー（revertの可能性）:", e.reason || e.message);
      console.log("  → 強制送信を試みます...");
    }

    const tx = await contract.approveUnlock(
      ethers.zeroPadBytes(privateTxHash, 32),
      recipient,
      amount,
      { gasLimit: gasEstimate ? gasEstimate * 120n / 100n : 200000n }
    );

    console.log("\n✅ トランザクション送信！");
    console.log("  TX Hash:", tx.hash);
    console.log("  Etherscan: https://sepolia.etherscan.io/tx/" + tx.hash);

    console.log("\n[確認待ち...]");
    const receipt = await tx.wait(1);

    console.log("\n" + "═".repeat(60));
    if (receipt.status === 1) {
      console.log("✅ 成功！");
      console.log("  Block:    ", receipt.blockNumber);
      console.log("  Gas Used: ", receipt.gasUsed.toString());

      // イベント確認
      const iface = new ethers.Interface(ABI);
      for (const log of receipt.logs) {
        try {
          const parsed = iface.parseLog(log);
          if (parsed?.name === 'Unlocked') {
            console.log("\n[Unlocked Event]");
            console.log("  privateTxHash:", parsed.args[0]);
            console.log("  recipient:    ", parsed.args[1]);
            console.log("  amount:       ", ethers.formatUnits(parsed.args[2], 6), "USDC");
          }
        } catch (_) {}
      }
    } else {
      console.log("❌ トランザクション失敗（revert）");
    }
    console.log("═".repeat(60));

  } catch (err) {
    console.error("\n❌ エラー:", err.reason || err.message || err);
    if (err.data) {
      console.error("   Revert data:", err.data);
    }
    process.exit(1);
  }
}

main();
