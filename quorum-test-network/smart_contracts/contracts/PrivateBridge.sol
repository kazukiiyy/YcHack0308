// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./USDCp.sol";

/**
 * @title PrivateBridge
 * @notice Bridge contract on Private Chain for handling USDC <-> USDCp transfers
 * @dev Called by external bridge software (operator) to mint/burn USDCp
 */
contract PrivateBridge {
    USDCp public usdcp;
    address public owner;

    // Operators who can execute bridge operations
    mapping(address => bool) public operators;

    // Track processed deposits to prevent replay
    mapping(bytes32 => bool) public processedDeposits;

    // Track withdrawal requests
    mapping(bytes32 => WithdrawRequest) public withdrawRequests;
    uint256 public withdrawNonce;

    struct WithdrawRequest {
        address from;
        uint256 amount;
        address publicChainRecipient;
        uint256 timestamp;
        bool processed;
    }

    // Events
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event DepositProcessed(
        bytes32 indexed depositId,
        address indexed recipient,
        uint256 amount,
        bytes32 publicChainTxHash
    );
    event WithdrawRequested(
        bytes32 indexed withdrawId,
        address indexed from,
        uint256 amount,
        address publicChainRecipient
    );
    event WithdrawProcessed(bytes32 indexed withdrawId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Bridge: caller is not owner");
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Bridge: caller is not operator");
        _;
    }

    constructor(address _usdcp) {
        owner = msg.sender;
        usdcp = USDCp(_usdcp);
        operators[msg.sender] = true;
        emit OperatorAdded(msg.sender);
    }

    // ============ Operator Functions ============

    /**
     * @notice Process a deposit from public chain (mint USDCp)
     * @dev Called by operator when USDC is locked on public chain
     * @param recipient Address to receive USDCp on private chain
     * @param amount Amount of USDCp to mint
     * @param publicChainTxHash Transaction hash of the lock on public chain
     */
    function processDeposit(
        address recipient,
        uint256 amount,
        bytes32 publicChainTxHash
    ) external onlyOperator {
        // Create unique deposit ID from public chain tx hash
        bytes32 depositId = keccak256(abi.encodePacked(publicChainTxHash, recipient, amount));

        require(!processedDeposits[depositId], "Bridge: deposit already processed");
        processedDeposits[depositId] = true;

        // Mint USDCp to recipient
        usdcp.mint(recipient, amount, depositId);

        emit DepositProcessed(depositId, recipient, amount, publicChainTxHash);
    }

    /**
     * @notice Request withdrawal to public chain (user calls this)
     * @param amount Amount of USDCp to burn
     * @param publicChainRecipient Address to receive USDC on public chain
     */
    function requestWithdraw(uint256 amount, address publicChainRecipient) external {
        require(amount > 0, "Bridge: amount must be > 0");
        require(publicChainRecipient != address(0), "Bridge: invalid recipient");
        require(usdcp.balanceOf(msg.sender) >= amount, "Bridge: insufficient balance");

        // Generate withdraw ID
        bytes32 withdrawId = keccak256(abi.encodePacked(
            msg.sender,
            amount,
            publicChainRecipient,
            withdrawNonce,
            block.timestamp
        ));
        withdrawNonce++;

        // Store withdrawal request
        withdrawRequests[withdrawId] = WithdrawRequest({
            from: msg.sender,
            amount: amount,
            publicChainRecipient: publicChainRecipient,
            timestamp: block.timestamp,
            processed: false
        });

        // Burn USDCp immediately
        usdcp.burn(msg.sender, amount, withdrawId);

        emit WithdrawRequested(withdrawId, msg.sender, amount, publicChainRecipient);
    }

    /**
     * @notice Mark withdrawal as processed (called by operator after unlocking on public chain)
     * @param withdrawId The withdrawal ID to mark as processed
     */
    function markWithdrawProcessed(bytes32 withdrawId) external onlyOperator {
        require(withdrawRequests[withdrawId].from != address(0), "Bridge: withdraw not found");
        require(!withdrawRequests[withdrawId].processed, "Bridge: already processed");

        withdrawRequests[withdrawId].processed = true;
        emit WithdrawProcessed(withdrawId);
    }

    // ============ View Functions ============

    function getWithdrawRequest(bytes32 withdrawId) external view returns (
        address from,
        uint256 amount,
        address publicChainRecipient,
        uint256 timestamp,
        bool processed
    ) {
        WithdrawRequest memory req = withdrawRequests[withdrawId];
        return (req.from, req.amount, req.publicChainRecipient, req.timestamp, req.processed);
    }

    function isDepositProcessed(bytes32 depositId) external view returns (bool) {
        return processedDeposits[depositId];
    }

    // ============ Admin Functions ============

    function addOperator(address operator) external onlyOwner {
        require(operator != address(0), "Bridge: invalid operator");
        operators[operator] = true;
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        operators[operator] = false;
        emit OperatorRemoved(operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Bridge: invalid owner");
        owner = newOwner;
    }

    function setUSDCp(address _usdcp) external onlyOwner {
        usdcp = USDCp(_usdcp);
    }
}
