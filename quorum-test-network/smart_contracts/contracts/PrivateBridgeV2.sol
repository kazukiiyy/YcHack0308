// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./USDCpV2.sol";

/**
 * @title PrivateBridge V2 (Security Enhanced)
 * @notice Bridge contract on Private Chain for handling USDC <-> USDCp transfers
 */
contract PrivateBridgeV2 {
    USDCpV2 public usdcp;
    address public owner;
    address public pendingOwner;
    bool public paused;

    // Operators who can execute bridge operations
    mapping(address => bool) public operators;

    // Track processed deposits to prevent replay attacks
    mapping(bytes32 => bool) public processedDeposits;

    // Track withdrawal requests
    mapping(bytes32 => WithdrawRequest) public withdrawRequests;
    uint256 public withdrawNonce;

    // Minimum/Maximum limits for security
    uint256 public minDepositAmount;
    uint256 public maxDepositAmount;
    uint256 public minWithdrawAmount;
    uint256 public maxWithdrawAmount;

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
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event LimitsUpdated(uint256 minDeposit, uint256 maxDeposit, uint256 minWithdraw, uint256 maxWithdraw);
    event USDCpUpdated(address indexed oldUsdcp, address indexed newUsdcp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Bridge: caller is not owner");
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Bridge: caller is not operator");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Bridge: paused");
        _;
    }

    constructor(address _usdcp) {
        require(_usdcp != address(0), "Bridge: invalid usdcp address");
        owner = msg.sender;
        usdcp = USDCpV2(_usdcp);
        operators[msg.sender] = true;
        emit OperatorAdded(msg.sender);

        // Set default limits (in 6 decimals)
        minDepositAmount = 1 * 10**6;        // 1 USDC minimum
        maxDepositAmount = 1000000 * 10**6;  // 1M USDC maximum
        minWithdrawAmount = 1 * 10**6;       // 1 USDC minimum
        maxWithdrawAmount = 1000000 * 10**6; // 1M USDC maximum
    }

    // ============ Operator Functions ============

    /**
     * @notice Process a deposit from public chain (mint USDCp)
     * @param recipient Address to receive USDCp on private chain
     * @param amount Amount of USDCp to mint
     * @param publicChainTxHash Transaction hash of the lock on public chain
     */
    function processDeposit(
        address recipient,
        uint256 amount,
        bytes32 publicChainTxHash
    ) external onlyOperator whenNotPaused {
        require(recipient != address(0), "Bridge: invalid recipient");
        require(amount >= minDepositAmount, "Bridge: amount below minimum");
        require(amount <= maxDepositAmount, "Bridge: amount above maximum");

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
    function requestWithdraw(
        uint256 amount,
        address publicChainRecipient
    ) external whenNotPaused {
        require(amount >= minWithdrawAmount, "Bridge: amount below minimum");
        require(amount <= maxWithdrawAmount, "Bridge: amount above maximum");
        require(publicChainRecipient != address(0), "Bridge: invalid recipient");
        require(usdcp.balanceOf(msg.sender) >= amount, "Bridge: insufficient balance");

        // Generate unique withdraw ID
        bytes32 withdrawId = keccak256(abi.encodePacked(
            msg.sender,
            amount,
            publicChainRecipient,
            withdrawNonce,
            block.timestamp,
            block.number  // Added for extra uniqueness
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
     * @notice Mark withdrawal as processed
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
        require(!operators[operator], "Bridge: already operator");
        operators[operator] = true;
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        require(operators[operator], "Bridge: not an operator");
        operators[operator] = false;
        emit OperatorRemoved(operator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Bridge: invalid owner");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Bridge: caller is not pending owner");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    function setUSDCp(address _usdcp) external onlyOwner {
        require(_usdcp != address(0), "Bridge: invalid usdcp address");
        emit USDCpUpdated(address(usdcp), _usdcp);
        usdcp = USDCpV2(_usdcp);
    }

    function setLimits(
        uint256 _minDeposit,
        uint256 _maxDeposit,
        uint256 _minWithdraw,
        uint256 _maxWithdraw
    ) external onlyOwner {
        require(_minDeposit <= _maxDeposit, "Bridge: invalid deposit limits");
        require(_minWithdraw <= _maxWithdraw, "Bridge: invalid withdraw limits");
        minDepositAmount = _minDeposit;
        maxDepositAmount = _maxDeposit;
        minWithdrawAmount = _minWithdraw;
        maxWithdrawAmount = _maxWithdraw;
        emit LimitsUpdated(_minDeposit, _maxDeposit, _minWithdraw, _maxWithdraw);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
}
