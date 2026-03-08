// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BridgeVault} from "../src/BridgeVault.sol";

contract DeployBridgeVault is Script {
    // Circle公式 Sepolia USDC
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    // Circle公式 Mainnet USDC
    address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        // Relayerは空で deploy → 後から addRelayer() で追加できる
        address[] memory relayers = new address[](0);
        uint256 threshold  = 0;           // 後でaddRelayer()+setThreshold()で設定           // Relayerが0人なので仮で1（後で変更可）
        uint256 dailyLimit = 1_000_000e6; // 1,000,000 USDC/day

        address usdcAddr = block.chainid == 1 ? USDC_MAINNET : USDC_SEPOLIA;

        console.log("=== BridgeVault Deploy ===");
        console.log("Network    :", block.chainid == 1 ? "Mainnet" : "Sepolia");
        console.log("Deployer   :", deployer);
        console.log("USDC       :", usdcAddr);
        console.log("Relayers   : none (add later via addRelayer())");
        console.log("Threshold  :", threshold);
        console.log("DailyLimit :", dailyLimit / 1e6, "USDC");

        vm.startBroadcast(deployerKey);

        BridgeVault vault = new BridgeVault(
            usdcAddr,
            relayers,
            threshold,
            dailyLimit
        );

        vm.stopBroadcast();

        console.log("=========================");
        console.log("Deployed at:", address(vault));
        console.log("Etherscan  : https://sepolia.etherscan.io/address/");
        console.logAddress(address(vault));
        console.log("");
        console.log("Next: add relayers via addRelayer()");
    }
}
