const ethers = require('ethers');

// Sepolia WebSocket RPC
const SEPOLIA_WS = "wss://ethereum-sepolia-rpc.publicnode.com";
const SEPOLIA_HTTP = "https://ethereum-sepolia-rpc.publicnode.com";

// BridgeVault contract info
const BRIDGE_VAULT_ADDRESS = "0xE69606565988E8A2bC9048ec22645670164Fab96";

// Locked event: Locked(address,uint256,bytes32,uint256)
const BRIDGE_VAULT_ABI = [
  "event Locked(address indexed sender, uint256 amount, bytes32 privateChainRecipient, uint256 nonce)",
];

async function main() {
  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║        Sepolia BridgeVault Event Listener                  ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log("");
  console.log("BridgeVault:", BRIDGE_VAULT_ADDRESS);
  console.log("Listening for Locked events...");
  console.log("");
  console.log("Press Ctrl+C to stop");
  console.log("─".repeat(60));
  console.log("");

  let provider;
  let useWebSocket = true;

  // Try WebSocket first, fallback to HTTP polling
  try {
    provider = new ethers.WebSocketProvider(SEPOLIA_WS);
    await provider.getBlockNumber(); // Test connection
    console.log("[Connected] WebSocket:", SEPOLIA_WS);
  } catch (e) {
    console.log("[WebSocket failed, using HTTP polling]", e.message);
    provider = new ethers.JsonRpcProvider(SEPOLIA_HTTP);
    useWebSocket = false;
  }

  const contract = new ethers.Contract(BRIDGE_VAULT_ADDRESS, BRIDGE_VAULT_ABI, provider);

  // Get current block
  const currentBlock = await provider.getBlockNumber();
  console.log("[Current Block]", currentBlock);
  console.log("");

  if (useWebSocket) {
    // Real-time WebSocket listener
    contract.on("Locked", (sender, amount, privateChainRecipient, nonce, event) => {
      console.log("═".repeat(60));
      console.log("[NEW EVENT] Locked");
      console.log("═".repeat(60));
      console.log("  Block:       ", event.log.blockNumber);
      console.log("  TX Hash:     ", event.log.transactionHash);
      console.log("  Sender:      ", sender);
      console.log("  Amount:      ", amount.toString(), "(raw)");
      console.log("  Amount:      ", ethers.formatUnits(amount, 6), "USDC (6 decimals)");
      console.log("  Private Recv:", privateChainRecipient);
      console.log("  Nonce:       ", nonce.toString());
      console.log("");

      // Convert bytes32 to address
      const addressFromBytes32 = "0x" + privateChainRecipient.slice(-40);
      console.log("  → Quorum Addr:", addressFromBytes32);
      console.log("");
      console.log("  Ready to call: processDeposit(");
      console.log("    recipient:", addressFromBytes32 + ",");
      console.log("    amount:", amount.toString() + ",");
      console.log("    sepoliaTxHash:", event.log.transactionHash);
      console.log("  )");
      console.log("═".repeat(60));
      console.log("");
    });

    console.log("[Listening...] Waiting for Locked events on Sepolia");
    console.log("");

  } else {
    // HTTP polling fallback
    console.log("[Polling mode] Checking every 10 seconds...");
    let lastBlock = currentBlock;

    setInterval(async () => {
      try {
        const newBlock = await provider.getBlockNumber();
        if (newBlock > lastBlock) {
          console.log(`[Checking blocks ${lastBlock + 1} to ${newBlock}]`);

          const filter = contract.filters.Locked();
          const events = await contract.queryFilter(filter, lastBlock + 1, newBlock);

          for (const event of events) {
            const [sender, amount, privateChainRecipient, nonce] = event.args;
            console.log("═".repeat(60));
            console.log("[NEW EVENT] Locked");
            console.log("═".repeat(60));
            console.log("  Block:       ", event.blockNumber);
            console.log("  TX Hash:     ", event.transactionHash);
            console.log("  Sender:      ", sender);
            console.log("  Amount:      ", ethers.formatUnits(amount, 6), "USDC");
            console.log("  Private Recv:", privateChainRecipient);
            console.log("  Nonce:       ", nonce.toString());
            console.log("═".repeat(60));
          }

          lastBlock = newBlock;
        }
      } catch (e) {
        console.log("[Polling error]", e.message);
      }
    }, 10000);
  }

  // Keep alive
  await new Promise(() => {});
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
