const ethers = require('ethers');

// Sepolia RPC (public endpoint)
const SEPOLIA_RPC = "https://ethereum-sepolia-rpc.publicnode.com";

// BridgeVault contract info
const BRIDGE_VAULT_ADDRESS = "0xE69606565988E8A2bC9048ec22645670164Fab96";

// Locked event signature: Locked(address,uint256,bytes32,uint256)
// topic[0] = 0x240f20813d456c0d1aa6a84704565be4c5a6d518adfc1cda174f3dc94dfa9c96
const LOCKED_EVENT_TOPIC = "0x240f20813d456c0d1aa6a84704565be4c5a6d518adfc1cda174f3dc94dfa9c96";

// Minimal ABI for what we know
const BRIDGE_VAULT_ABI = [
  "event Locked(address indexed sender, uint256 amount, bytes32 privateChainRecipient, uint256 nonce)",
  "function balanceOf(address) view returns (uint256)",
];

async function main() {
  const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC);

  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║           Sepolia BridgeVault State                        ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log("");

  // Network info
  const blockNumber = await provider.getBlockNumber();
  const network = await provider.getNetwork();
  console.log("┌─ Network ──────────────────────────────────────────────────┐");
  console.log("│  RPC:          ", SEPOLIA_RPC);
  console.log("│  Chain ID:     ", network.chainId.toString());
  console.log("│  Block Number: ", blockNumber);
  console.log("└────────────────────────────────────────────────────────────┘");
  console.log("");

  // Contract info
  console.log("┌─ BridgeVault Contract ─────────────────────────────────────┐");
  console.log("│  Address:", BRIDGE_VAULT_ADDRESS);

  // Check contract code exists
  const code = await provider.getCode(BRIDGE_VAULT_ADDRESS);
  console.log("│  Has Code:", code.length > 2 ? "Yes (" + code.length + " bytes)" : "No");

  // Check ETH balance of vault
  const vaultBalance = await provider.getBalance(BRIDGE_VAULT_ADDRESS);
  console.log("│  ETH Balance:", ethers.formatEther(vaultBalance), "ETH");
  console.log("└────────────────────────────────────────────────────────────┘");
  console.log("");

  // Query recent Locked events
  console.log("┌─ Recent Locked Events (last 10000 blocks) ─────────────────┐");

  const fromBlock = blockNumber - 10000;
  const filter = {
    address: BRIDGE_VAULT_ADDRESS,
    topics: [LOCKED_EVENT_TOPIC],
    fromBlock: fromBlock,
    toBlock: "latest"
  };

  try {
    const logs = await provider.getLogs(filter);
    console.log("│  Found:", logs.length, "Locked events");
    console.log("│");

    if (logs.length > 0) {
      // Decode events
      const iface = new ethers.Interface(BRIDGE_VAULT_ABI);

      for (const log of logs.slice(-5)) { // Show last 5
        try {
          const decoded = iface.parseLog({
            topics: log.topics,
            data: log.data
          });

          console.log("│  ─── Event ───");
          console.log("│  Block:", log.blockNumber);
          console.log("│  TX:", log.transactionHash);
          console.log("│  Sender:", decoded.args[0]);
          console.log("│  Amount:", ethers.formatUnits(decoded.args[1], 6), "(assuming 6 decimals)");
          console.log("│  Private Recipient:", decoded.args[2]);
          console.log("│  Nonce:", decoded.args[3].toString());
          console.log("│");
        } catch (e) {
          console.log("│  Could not decode event:", e.message);
        }
      }
    }
  } catch (e) {
    console.log("│  Error fetching events:", e.message);
  }

  console.log("└────────────────────────────────────────────────────────────┘");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
