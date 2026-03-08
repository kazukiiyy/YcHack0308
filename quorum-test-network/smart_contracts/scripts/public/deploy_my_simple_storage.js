const path = require('path');
const fs = require('fs-extra');
const ethers = require('ethers');

// RPCNODE details
const { quorum } = require("../keys.js");
const host = quorum.rpcnode.url;
const accountPrivateKey = quorum.rpcnode.accountPrivateKey;

// Load compiled contract
const contractJsonPath = path.resolve(__dirname, '../../', 'contracts', 'MySimpleStorage.json');
const contractJson = JSON.parse(fs.readFileSync(contractJsonPath));
const contractAbi = contractJson.abi;
const contractBytecode = contractJson.evm.bytecode.object;

async function deployContract(provider, wallet, abi, bytecode, initMessage) {
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  console.log("Deploying MySimpleStorage with message:", initMessage);
  const contract = await factory.deploy(initMessage);
  await contract.waitForDeployment();
  return contract;
}

async function readMessage(contract) {
  const message = await contract.readMessage();
  console.log("Current message:", message);
  return message;
}

async function updateMessage(contract, newMessage) {
  console.log("Updating message to:", newMessage);
  const tx = await contract.updateMessage(newMessage);
  await tx.wait();
  console.log("Message updated! TX hash:", tx.hash);
  return tx;
}

async function main() {
  const provider = new ethers.JsonRpcProvider(host);
  const wallet = new ethers.Wallet(accountPrivateKey, provider);

  console.log("Deploying from address:", wallet.address);
  console.log("Connected to:", host);
  console.log("");

  // Deploy contract with initial message
  const initMessage = "Hello from Quorum!";
  const contract = await deployContract(provider, wallet, contractAbi, contractBytecode, initMessage);
  const contractAddress = await contract.getAddress();

  console.log("");
  console.log("=".repeat(50));
  console.log("Contract deployed successfully!");
  console.log("Contract address:", contractAddress);
  console.log("=".repeat(50));
  console.log("");

  // Read initial message
  await readMessage(contract);

  // Update message
  await updateMessage(contract, "Updated message from Quorum!");

  // Read updated message
  await readMessage(contract);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
