// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title BridgeVault
 * @notice Public chain (Ethereum) side of the Private↔Public USDC Bridge.
 *         Users lock USDC here; Relayers (multisig) approve unlocks when
 *         the corresponding WrappedUSDC is burned on the private chain.
 *
 * Flow (Public → Private):
 *   1. User calls lock(amount, privateChainRecipient)
 *   2. USDC transferred into this vault
 *   3. LockEvent emitted → Private chain Relayer picks up → mints WrappedUSDC
 *
 * Flow (Private → Public):
 *   1. WrappedUSDC burned on Private chain → BurnEvent emitted
 *   2. Each Relayer calls approveUnlock(txHash, recipient, amount)
 *   3. Once threshold signatures collected → unlock executes automatically
 */
contract BridgeVault is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ─── Roles ────────────────────────────────────────────────────────────────
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant ADMIN_ROLE   = keccak256("ADMIN_ROLE");

    // ─── State ────────────────────────────────────────────────────────────────
    IERC20 public immutable usdc;

    /// @notice Number of Relayer approvals required to execute an unlock
    uint256 public threshold;

    /// @notice Total USDC currently locked in this vault
    uint256 public totalLocked;

    /// @notice Daily unlock limit (anti-drain safety)
    uint256 public dailyUnlockLimit;
    uint256 public dailyUnlockUsed;
    uint256 public lastUnlockDay;

    struct UnlockRequest {
        address recipient;
        uint256 amount;
        uint256 approvalCount;
        bool executed;
        mapping(address => bool) approvedBy;
    }

    /// @dev privateTxHash => UnlockRequest
    mapping(bytes32 => UnlockRequest) public unlockRequests;

    /// @dev Replay protection: track processed private chain tx hashes
    mapping(bytes32 => bool) public processedTxHashes;

    // ─── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted when USDC is locked. Private chain Relayer listens to this.
    event Locked(
        address indexed sender,
        uint256 amount,
        bytes32 indexed privateChainRecipient,  // private chain address as bytes32
        uint256 indexed lockId
    );

    event UnlockApproved(
        bytes32 indexed privateTxHash,
        address indexed relayer,
        uint256 approvalCount,
        uint256 threshold
    );

    event Unlocked(
        bytes32 indexed privateTxHash,
        address indexed recipient,
        uint256 amount
    );

    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event DailyLimitUpdated(uint256 newLimit);
    event RelayerAdded(address relayer);
    event RelayerRemoved(address relayer);

    // ─── Counter ──────────────────────────────────────────────────────────────
    uint256 private _lockCounter;

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _usdc      USDC contract address on Ethereum
     * @param _relayers  Initial set of trusted relayer addresses
     * @param _threshold Number of relayer approvals required (e.g. 2-of-3)
     * @param _dailyUnlockLimit  Max USDC (in 6-decimal units) unlockable per day
     */
    constructor(
        address _usdc,
        address[] memory _relayers,
        uint256 _threshold,
        uint256 _dailyUnlockLimit
    ) {
        require(_usdc != address(0), "BridgeVault: zero usdc address");
        require(_relayers.length >= _threshold, "BridgeVault: threshold too high");
        require(_threshold > 0, "BridgeVault: threshold must be > 0");

        usdc = IERC20(_usdc);
        threshold = _threshold;
        dailyUnlockLimit = _dailyUnlockLimit;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        for (uint256 i = 0; i < _relayers.length; i++) {
            require(_relayers[i] != address(0), "BridgeVault: zero relayer address");
            _grantRole(RELAYER_ROLE, _relayers[i]);
            emit RelayerAdded(_relayers[i]);
        }
    }

    // ─── User-facing: Lock ────────────────────────────────────────────────────

    /**
     * @notice Lock USDC on Ethereum to receive WrappedUSDC on the private chain.
     * @param amount                 Amount of USDC to lock (6 decimals)
     * @param privateChainRecipient  Recipient address on the private chain (as bytes32)
     */
    function lock(
        uint256 amount,
        bytes32 privateChainRecipient
    ) external nonReentrant whenNotPaused returns (uint256 lockId) {
        require(amount > 0, "BridgeVault: amount must be > 0");
        require(privateChainRecipient != bytes32(0), "BridgeVault: zero private recipient");

        lockId = ++_lockCounter;
        totalLocked += amount;

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit Locked(msg.sender, amount, privateChainRecipient, lockId);
    }

    // ─── Relayer: Approve Unlock ──────────────────────────────────────────────

    /**
     * @notice Relayer submits approval for an unlock corresponding to a
     *         WrappedUSDC burn on the private chain.
     *         Once `threshold` unique relayers approve, USDC is released.
     *
     * @param privateTxHash  Hash of the burn transaction on the private chain
     * @param recipient      Ethereum address to receive the unlocked USDC
     * @param amount         Amount to unlock (must match the burn amount)
     */
    function approveUnlock(
        bytes32 privateTxHash,
        address recipient,
        uint256 amount
    ) external nonReentrant whenNotPaused onlyRole(RELAYER_ROLE) {
        require(!processedTxHashes[privateTxHash], "BridgeVault: already processed");
        require(recipient != address(0), "BridgeVault: zero recipient");
        require(amount > 0, "BridgeVault: amount must be > 0");

        UnlockRequest storage req = unlockRequests[privateTxHash];

        // First approval: initialize the request
        if (req.approvalCount == 0) {
            req.recipient = recipient;
            req.amount    = amount;
        } else {
            // Subsequent approvals: ensure consistency
            require(req.recipient == recipient, "BridgeVault: recipient mismatch");
            require(req.amount    == amount,    "BridgeVault: amount mismatch");
            require(!req.executed,              "BridgeVault: already executed");
        }

        require(!req.approvedBy[msg.sender], "BridgeVault: already approved by this relayer");

        req.approvedBy[msg.sender] = true;
        req.approvalCount++;

        emit UnlockApproved(privateTxHash, msg.sender, req.approvalCount, threshold);

        // Auto-execute once threshold is reached
        if (req.approvalCount >= threshold) {
            _executeUnlock(privateTxHash, req);
        }
    }

    // ─── Internal: Execute Unlock ─────────────────────────────────────────────

    function _executeUnlock(
        bytes32 privateTxHash,
        UnlockRequest storage req
    ) internal {
        req.executed = true;
        processedTxHashes[privateTxHash] = true;

        // Daily limit check
        uint256 today = block.timestamp / 1 days;
        if (today > lastUnlockDay) {
            lastUnlockDay    = today;
            dailyUnlockUsed  = 0;
        }
        require(
            dailyUnlockUsed + req.amount <= dailyUnlockLimit,
            "BridgeVault: daily unlock limit exceeded"
        );
        dailyUnlockUsed += req.amount;
        totalLocked     -= req.amount;

        usdc.safeTransfer(req.recipient, req.amount);

        emit Unlocked(privateTxHash, req.recipient, req.amount);
    }

    // ─── Admin Functions ──────────────────────────────────────────────────────

    function setThreshold(uint256 newThreshold) external onlyRole(ADMIN_ROLE) {
        require(newThreshold > 0, "BridgeVault: threshold must be > 0");
        emit ThresholdUpdated(threshold, newThreshold);
        threshold = newThreshold;
    }

    function setDailyUnlockLimit(uint256 newLimit) external onlyRole(ADMIN_ROLE) {
        dailyUnlockLimit = newLimit;
        emit DailyLimitUpdated(newLimit);
    }

    function addRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        require(relayer != address(0), "BridgeVault: zero address");
        _grantRole(RELAYER_ROLE, relayer);
        emit RelayerAdded(relayer);
    }

    function removeRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        _revokeRole(RELAYER_ROLE, relayer);
        emit RelayerRemoved(relayer);
    }

    function pause()   external onlyRole(ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(ADMIN_ROLE) { _unpause(); }

    // ─── View Helpers ─────────────────────────────────────────────────────────

    function getApprovalCount(bytes32 privateTxHash) external view returns (uint256) {
        return unlockRequests[privateTxHash].approvalCount;
    }

    function hasRelayerApproved(
        bytes32 privateTxHash,
        address relayer
    ) external view returns (bool) {
        return unlockRequests[privateTxHash].approvedBy[relayer];
    }

    function isProcessed(bytes32 privateTxHash) external view returns (bool) {
        return processedTxHashes[privateTxHash];
    }
}
