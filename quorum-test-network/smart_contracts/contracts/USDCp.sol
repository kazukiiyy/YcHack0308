// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title USDCp - Bridged USDC for Private Chain
 * @notice ERC20 token with mint/burn functionality controlled by a bridge
 */
contract USDCp {
    string public constant name = "Bridged USDC (Private)";
    string public constant symbol = "USDCp";
    uint8 public constant decimals = 6; // Same as USDC

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public bridge;
    address public owner;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount, bytes32 indexed depositId);
    event Burn(address indexed from, uint256 amount, bytes32 indexed withdrawId);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);

    modifier onlyBridge() {
        require(msg.sender == bridge, "USDCp: caller is not the bridge");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "USDCp: caller is not the owner");
        _;
    }

    constructor(address _bridge) {
        owner = msg.sender;
        bridge = _bridge;
    }

    // ============ ERC20 Standard Functions ============

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "USDCp: transfer to zero address");
        require(balanceOf[msg.sender] >= amount, "USDCp: insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(to != address(0), "USDCp: transfer to zero address");
        require(balanceOf[from] >= amount, "USDCp: insufficient balance");
        require(allowance[from][msg.sender] >= amount, "USDCp: insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    // ============ Bridge Functions ============

    /**
     * @notice Mint USDCp tokens (called by bridge when USDC is deposited on public chain)
     * @param to Recipient address on private chain
     * @param amount Amount to mint (in 6 decimals)
     * @param depositId Unique identifier for the deposit on public chain
     */
    function mint(address to, uint256 amount, bytes32 depositId) external onlyBridge {
        require(to != address(0), "USDCp: mint to zero address");
        require(amount > 0, "USDCp: mint amount must be > 0");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount, depositId);
    }

    /**
     * @notice Burn USDCp tokens (called by bridge when user wants to withdraw to public chain)
     * @param from Address burning tokens
     * @param amount Amount to burn
     * @param withdrawId Unique identifier for this withdrawal
     */
    function burn(address from, uint256 amount, bytes32 withdrawId) external onlyBridge {
        require(balanceOf[from] >= amount, "USDCp: insufficient balance to burn");
        require(amount > 0, "USDCp: burn amount must be > 0");

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
        emit Burn(from, amount, withdrawId);
    }

    // ============ Admin Functions ============

    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "USDCp: bridge cannot be zero address");
        emit BridgeUpdated(bridge, newBridge);
        bridge = newBridge;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "USDCp: new owner cannot be zero address");
        owner = newOwner;
    }
}
