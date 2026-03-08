// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BridgeVault} from "../src/BridgeVault.sol";

contract DeployBridgeVault is Script {
    // ── デプロイ設定 ─────────────────────────────────────────────
    // 本番環境ではこれらを環境変数 or .env で管理する

    // Ethereum Mainnet USDC
    address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // Sepolia testnet USDC (Circle公式)
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        // Relayerアドレス（本番では信頼できる複数の機関のアドレスに変更）
        address[] memory relayers = new address[](3);
        relayers[0] = vm.envAddress("RELAYER_1");
        relayers[1] = vm.envAddress("RELAYER_2");
        relayers[2] = vm.envAddress("RELAYER_3");

        uint256 threshold       = 2;             // 2-of-3
        uint256 dailyLimit      = 1_000_000e6;   // 1,000,000 USDC/day

        // testnetかmainnetかを判定
        address usdcAddr = block.chainid == 1 ? USDC_MAINNET : USDC_SEPOLIA;

        console.log("Deploying BridgeVault...");
        console.log("  Deployer  :", deployer);
        console.log("  USDC      :", usdcAddr);
        console.log("  Threshold :", threshold);
        console.log("  DailyLimit:", dailyLimit / 1e6, "USDC");

        vm.startBroadcast(deployerKey);

        BridgeVault vault = new BridgeVault(
            usdcAddr,
            relayers,
            threshold,
            dailyLimit
        );

        vm.stopBroadcast();

        console.log("BridgeVault deployed at:", address(vault));
    }
}
