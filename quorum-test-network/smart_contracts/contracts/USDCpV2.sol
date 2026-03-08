// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title USDCp V2 - Bridged USDC for Private Chain (Security Enhanced)
 * @notice ERC20 token with mint/burn functionality controlled by a bridge
 *
 * ============================================================
 * ERC20 トークン解説
 * ============================================================
 *
 * ERC20とは、Ethereumブロックチェーン上でトークンを標準化するためのインターフェース規格です。
 * この規格に従うことで、ウォレットやDEXなど様々なアプリケーションと互換性を持ちます。
 *
 * 【必須の状態変数】
 * - name: トークンの名前 (例: "Bridged USDC (Private)")
 * - symbol: トークンのシンボル (例: "USDCp")
 * - decimals: 小数点以下の桁数 (USDCは6桁)
 * - totalSupply: トークンの総発行量
 * - balanceOf: 各アドレスの残高を記録するマッピング
 * - allowance: 他者への送金許可額を記録するマッピング
 *
 * 【必須の関数】
 * - transfer(to, amount): 自分のトークンを他者に送る
 * - approve(spender, amount): 他者に自分のトークンを使う許可を与える
 * - transferFrom(from, to, amount): 許可された範囲で他者のトークンを送る
 *
 * 【必須のイベント】
 * - Transfer: トークン移転時に発行
 * - Approval: 許可設定時に発行
 *
 * ============================================================
 */
contract USDCpV2 {
    // ============================================================
    // ERC20 基本情報
    // ============================================================

    /// @notice トークン名 - ウォレットやエクスプローラーで表示される
    string public constant name = "Bridged USDC (Private)";

    /// @notice シンボル - 短縮表記 (ETH, USDC, USDCp など)
    string public constant symbol = "USDCp";

    /// @notice 小数点以下の桁数
    /// @dev USDCは6桁 (1 USDC = 1,000,000 units)
    /// @dev ETHは18桁 (1 ETH = 1,000,000,000,000,000,000 wei)
    uint8 public constant decimals = 6;

    /// @notice 総発行量 - mint時に増加、burn時に減少
    uint256 public totalSupply;

    /// @notice 各アドレスの残高
    /// @dev balanceOf[address] = amount
    mapping(address => uint256) public balanceOf;

    /// @notice 許可額 (Allowance)
    /// @dev allowance[owner][spender] = amount
    /// @dev ownerがspenderに対してamount分の使用を許可
    mapping(address => mapping(address => uint256)) public allowance;

    // ============================================================
    // ブリッジ・管理用変数
    // ============================================================

    address public bridge;
    address public owner;
    address public pendingOwner; // 2段階ownership移転用
    bool public paused;          // 緊急停止フラグ

    // ============================================================
    // イベント定義
    // ============================================================

    /// @notice トークン移転イベント (ERC20必須)
    /// @dev from=0x0 はmint、to=0x0 はburnを意味する
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice 許可設定イベント (ERC20必須)
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Mint実行イベント
    event Mint(address indexed to, uint256 amount, bytes32 indexed depositId);

    /// @notice Burn実行イベント
    event Burn(address indexed from, uint256 amount, bytes32 indexed withdrawId);

    /// @notice Bridge変更イベント
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);

    /// @notice Ownership移転開始イベント
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @notice Ownership移転完了イベント
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Pause状態変更イベント
    event Paused(address account);
    event Unpaused(address account);

    // ============================================================
    // 修飾子 (Modifier)
    // ============================================================

    modifier onlyBridge() {
        require(msg.sender == bridge, "USDCp: caller is not the bridge");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "USDCp: caller is not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "USDCp: paused");
        _;
    }

    // ============================================================
    // コンストラクタ
    // ============================================================

    constructor(address _bridge) {
        require(_bridge != address(0), "USDCp: bridge cannot be zero");
        owner = msg.sender;
        bridge = _bridge;
    }

    // ============================================================
    // ERC20 標準関数
    // ============================================================

    /**
     * @notice トークンを送金する
     * @dev 自分のbalanceからtoのbalanceへamount移動
     * @param to 送金先アドレス
     * @param amount 送金額
     * @return success 成功したらtrue
     *
     * 処理フロー:
     * 1. toがゼロアドレスでないことを確認
     * 2. 送金者の残高が十分あることを確認
     * 3. 送金者の残高を減らす
     * 4. 受取者の残高を増やす
     * 5. Transferイベントを発行
     */
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        require(to != address(0), "USDCp: transfer to zero address");
        require(balanceOf[msg.sender] >= amount, "USDCp: insufficient balance");

        // Solidity 0.8+ ではオーバーフロー/アンダーフローは自動でrevert
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice 他者にトークン使用を許可する
     * @dev spenderがtransferFromで使える上限を設定
     * @param spender 許可を与える相手
     * @param amount 許可する量
     * @return success 成功したらtrue
     *
     * ⚠️ セキュリティ注意:
     * approve(100)の後にapprove(50)を呼ぶと、攻撃者が間に100を使って
     * さらに50を使える可能性がある（race condition）
     * → increaseAllowance/decreaseAllowance の使用を推奨
     */
    function approve(address spender, uint256 amount) external whenNotPaused returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice 許可された範囲で他者のトークンを送金
     * @dev DEXなどが使用。ユーザーがapproveした後、DEXがtransferFromで引き出す
     * @param from 送金元
     * @param to 送金先
     * @param amount 送金額
     * @return success 成功したらtrue
     */
    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        require(to != address(0), "USDCp: transfer to zero address");
        require(balanceOf[from] >= amount, "USDCp: insufficient balance");
        require(allowance[from][msg.sender] >= amount, "USDCp: insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @notice 許可額を増加させる（race condition対策）
     * @param spender 許可を与える相手
     * @param addedValue 追加する許可量
     */
    function increaseAllowance(address spender, uint256 addedValue) external whenNotPaused returns (bool) {
        _approve(msg.sender, spender, allowance[msg.sender][spender] + addedValue);
        return true;
    }

    /**
     * @notice 許可額を減少させる（race condition対策）
     * @param spender 許可を与える相手
     * @param subtractedValue 減らす許可量
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external whenNotPaused returns (bool) {
        uint256 currentAllowance = allowance[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "USDCp: decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    /// @dev 内部approve関数
    function _approve(address _owner, address spender, uint256 amount) internal {
        require(spender != address(0), "USDCp: approve to zero address");
        allowance[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    // ============================================================
    // Bridge専用関数 (Mint/Burn)
    // ============================================================

    /**
     * @notice 新しいトークンを発行（Mint）
     * @dev Public ChainでUSDCがロックされた時にBridgeが呼び出す
     * @param to 発行先アドレス
     * @param amount 発行量
     * @param depositId 一意のデポジットID（重複防止用）
     */
    function mint(address to, uint256 amount, bytes32 depositId) external onlyBridge whenNotPaused {
        require(to != address(0), "USDCp: mint to zero address");
        require(amount > 0, "USDCp: mint amount must be > 0");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount); // from=0x0 はmintを示す
        emit Mint(to, amount, depositId);
    }

    /**
     * @notice トークンを焼却（Burn）
     * @dev ユーザーがPublic ChainでUSDCを受け取りたい時にBridgeが呼び出す
     * @param from 焼却元アドレス
     * @param amount 焼却量
     * @param withdrawId 一意の引き出しID
     */
    function burn(address from, uint256 amount, bytes32 withdrawId) external onlyBridge whenNotPaused {
        require(balanceOf[from] >= amount, "USDCp: insufficient balance to burn");
        require(amount > 0, "USDCp: burn amount must be > 0");

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount); // to=0x0 はburnを示す
        emit Burn(from, amount, withdrawId);
    }

    // ============================================================
    // 管理者関数
    // ============================================================

    /// @notice Bridgeアドレスを変更
    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "USDCp: bridge cannot be zero address");
        emit BridgeUpdated(bridge, newBridge);
        bridge = newBridge;
    }

    /// @notice Ownership移転を開始（2段階移転）
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "USDCp: new owner cannot be zero address");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice Ownership移転を受諾（新オーナーが呼び出す）
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "USDCp: caller is not pending owner");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    /// @notice 緊急停止
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice 緊急停止解除
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
}
