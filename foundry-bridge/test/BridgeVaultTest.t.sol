// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BridgeVault} from "../src/BridgeVault.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract BridgeVaultTest is Test {
    // expectEmit用にイベントを再宣言
    event Locked(address indexed sender, uint256 amount, bytes32 indexed privateChainRecipient, uint256 indexed lockId);
    event Unlocked(bytes32 indexed privateTxHash, address indexed recipient, uint256 amount);
    event UnlockApproved(bytes32 indexed privateTxHash, address indexed relayer, uint256 approvalCount, uint256 threshold);

    BridgeVault public vault;
    MockUSDC    public usdc;

    address admin    = makeAddr("admin");
    address user     = makeAddr("user");
    address relayer1 = makeAddr("relayer1");
    address relayer2 = makeAddr("relayer2");
    address relayer3 = makeAddr("relayer3");
    address attacker = makeAddr("attacker");

    // Private chain burn tx hash (Besuでのburn txをシミュレート)
    bytes32 constant PRIVATE_TX_HASH   = keccak256("besu-burn-tx-001");
    bytes32 constant PRIVATE_RECIPIENT = bytes32(uint256(0xABCD));

    // USDC: 6 decimals
    function _usdc(uint256 amount) internal pure returns (uint256) {
        return amount * 1e6;
    }

    function setUp() public {
        vm.startPrank(admin);

        usdc = new MockUSDC();

        address[] memory relayers = new address[](3);
        relayers[0] = relayer1;
        relayers[1] = relayer2;
        relayers[2] = relayer3;

        vault = new BridgeVault(
            address(usdc),
            relayers,
            2,               // threshold: 2-of-3
            _usdc(1_000_000) // dailyUnlockLimit: 1,000,000 USDC
        );

        vm.stopPrank();

        // Fund user
        usdc.mint(user, _usdc(10_000));
        vm.prank(user);
        usdc.approve(address(vault), _usdc(10_000));
    }

    // ─────────────────────────────────────────────────────────────
    // 1. LOCK: 基本動作
    // ─────────────────────────────────────────────────────────────

    function test_Lock_TransfersUSDCToVault() public {
        uint256 before = usdc.balanceOf(address(vault));

        vm.prank(user);
        vault.lock(_usdc(500), PRIVATE_RECIPIENT);

        assertEq(usdc.balanceOf(address(vault)) - before, _usdc(500));
    }

    function test_Lock_IncrementsTotalLocked() public {
        vm.prank(user);
        vault.lock(_usdc(500), PRIVATE_RECIPIENT);

        assertEq(vault.totalLocked(), _usdc(500));
    }

    function test_Lock_EmitsLockedEvent() public {
        // expectEmit: (checkTopic1, checkTopic2, checkTopic3, checkData)
        vm.expectEmit(true, true, true, true);
        emit Locked(user, _usdc(500), PRIVATE_RECIPIENT, 1);

        vm.prank(user);
        vault.lock(_usdc(500), PRIVATE_RECIPIENT);
    }

    function test_Lock_AssignsIncrementingLockIds() public {
        vm.startPrank(user);

        // 1回目: lockId = 1
        vm.expectEmit(true, false, false, true);
        emit Locked(user, _usdc(100), PRIVATE_RECIPIENT, 1);
        vault.lock(_usdc(100), PRIVATE_RECIPIENT);

        // 2回目: lockId = 2
        vm.expectEmit(true, false, false, true);
        emit Locked(user, _usdc(200), PRIVATE_RECIPIENT, 2);
        vault.lock(_usdc(200), PRIVATE_RECIPIENT);

        vm.stopPrank();
    }

    function test_Lock_RevertWhen_AmountIsZero() public {
        vm.prank(user);
        vm.expectRevert("BridgeVault: amount must be > 0");
        vault.lock(0, PRIVATE_RECIPIENT);
    }

    function test_Lock_RevertWhen_PrivateRecipientIsZero() public {
        vm.prank(user);
        vm.expectRevert("BridgeVault: zero private recipient");
        vault.lock(_usdc(100), bytes32(0));
    }

    function test_Lock_RevertWhen_Paused() public {
        vm.prank(admin);
        vault.pause();

        vm.prank(user);
        vm.expectRevert();
        vault.lock(_usdc(100), PRIVATE_RECIPIENT);
    }

    function test_Lock_RevertWhen_InsufficientAllowance() public {
        address newUser = makeAddr("newUser");
        usdc.mint(newUser, _usdc(1000));
        // approve なし

        vm.prank(newUser);
        vm.expectRevert();
        vault.lock(_usdc(100), PRIVATE_RECIPIENT);
    }

    // ─────────────────────────────────────────────────────────────
    // 2. MULTISIG UNLOCK: approveUnlock フロー
    // ─────────────────────────────────────────────────────────────

    modifier withLockedUSDC(uint256 amount) {
        vm.prank(user);
        vault.lock(amount, PRIVATE_RECIPIENT);
        _;
    }

    function test_ApproveUnlock_FirstApprovalSetsState()
        public withLockedUSDC(_usdc(1000))
    {
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        assertEq(vault.getApprovalCount(PRIVATE_TX_HASH), 1);
        assertTrue(vault.hasRelayerApproved(PRIVATE_TX_HASH, relayer1));
    }

    function test_ApproveUnlock_EmitsUnlockApprovedEvent()
        public withLockedUSDC(_usdc(1000))
    {
        vm.expectEmit(true, true, false, true);
        emit UnlockApproved(PRIVATE_TX_HASH, relayer1, 1, 2);

        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
    }

    function test_ApproveUnlock_ExecutesAfterThreshold()
        public withLockedUSDC(_usdc(1000))
    {
        uint256 balBefore = usdc.balanceOf(user);

        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        vm.prank(relayer2);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        assertEq(usdc.balanceOf(user) - balBefore, _usdc(500));
    }

    function test_ApproveUnlock_EmitsUnlockedEvent()
        public withLockedUSDC(_usdc(1000))
    {
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        vm.expectEmit(true, true, false, true);
        emit Unlocked(PRIVATE_TX_HASH, user, _usdc(500));

        vm.prank(relayer2);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
    }

    function test_ApproveUnlock_MarksTxHashProcessed()
        public withLockedUSDC(_usdc(1000))
    {
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
        vm.prank(relayer2);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        assertTrue(vault.isProcessed(PRIVATE_TX_HASH));
    }

    function test_ApproveUnlock_RevertWhen_SameRelayerApproveTwice()
        public withLockedUSDC(_usdc(1000))
    {
        vm.startPrank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        vm.expectRevert("BridgeVault: already approved by this relayer");
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
        vm.stopPrank();
    }

    function test_ApproveUnlock_RevertWhen_NonRelayer()
        public withLockedUSDC(_usdc(1000))
    {
        vm.prank(attacker);
        vm.expectRevert();
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
    }

    function test_ApproveUnlock_RevertWhen_RecipientMismatch()
        public withLockedUSDC(_usdc(1000))
    {
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        vm.prank(relayer2);
        vm.expectRevert("BridgeVault: recipient mismatch");
        vault.approveUnlock(PRIVATE_TX_HASH, attacker, _usdc(500));
    }

    function test_ApproveUnlock_RevertWhen_AmountMismatch()
        public withLockedUSDC(_usdc(1000))
    {
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        vm.prank(relayer2);
        vm.expectRevert("BridgeVault: amount mismatch");
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(999));
    }

    // ─────────────────────────────────────────────────────────────
    // 3. リプレイ攻撃防止
    // ─────────────────────────────────────────────────────────────

    function test_ReplayAttack_RevertWhen_SameTxHashReused() public {
        vm.prank(user);
        vault.lock(_usdc(2000), PRIVATE_RECIPIENT);

        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
        vm.prank(relayer2);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        // 同じtxHashで再度試みる
        vm.prank(relayer1);
        vm.expectRevert("BridgeVault: already processed");
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
    }

    // ─────────────────────────────────────────────────────────────
    // 4. 日次アンロック上限
    // ─────────────────────────────────────────────────────────────

    function test_DailyLimit_RevertWhen_ExceedsLimit() public {
        // 上限100 USDCのVaultを新規作成
        address[] memory relayers = new address[](2);
        relayers[0] = relayer1;
        relayers[1] = relayer2;

        vm.prank(admin);
        BridgeVault tinyVault = new BridgeVault(
            address(usdc),
            relayers,
            2,
            _usdc(100) // 100 USDC/day
        );

        usdc.mint(user, _usdc(10_000));
        vm.startPrank(user);
        usdc.approve(address(tinyVault), _usdc(10_000));
        tinyVault.lock(_usdc(10_000), PRIVATE_RECIPIENT);
        vm.stopPrank();

        bytes32 bigHash = keccak256("big-burn");
        vm.prank(relayer1);
        tinyVault.approveUnlock(bigHash, user, _usdc(500));

        vm.prank(relayer2);
        vm.expectRevert("BridgeVault: daily unlock limit exceeded");
        tinyVault.approveUnlock(bigHash, user, _usdc(500));
    }

    function test_DailyLimit_ResetsNextDay() public {
        vm.prank(user);
        vault.lock(_usdc(2000), PRIVATE_RECIPIENT);

        // 1日目: 500 USDC unlock
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
        vm.prank(relayer2);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        // 翌日に時間を進める
        vm.warp(block.timestamp + 1 days + 1);

        // 翌日は別のhashで再度unlock可能
        bytes32 nextHash = keccak256("besu-burn-tx-002");
        vm.prank(relayer1);
        vault.approveUnlock(nextHash, user, _usdc(500));
        vm.prank(relayer2);
        vault.approveUnlock(nextHash, user, _usdc(500));

        // 2回分のunlockが成功していること
        assertTrue(vault.isProcessed(PRIVATE_TX_HASH));
        assertTrue(vault.isProcessed(nextHash));
    }

    // ─────────────────────────────────────────────────────────────
    // 5. PAUSE / UNPAUSE
    // ─────────────────────────────────────────────────────────────

    function test_Pause_AdminCanPauseAndUnpause() public {
        vm.prank(admin);
        vault.pause();

        vm.prank(user);
        vm.expectRevert();
        vault.lock(_usdc(100), PRIVATE_RECIPIENT);

        vm.prank(admin);
        vault.unpause();

        // unpause後は通常通り動作
        vm.expectEmit(true, false, false, false);
        emit Locked(user, _usdc(100), PRIVATE_RECIPIENT, 1);
        vm.prank(user);
        vault.lock(_usdc(100), PRIVATE_RECIPIENT);
    }

    function test_Pause_RevertWhen_NonAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.pause();
    }

    // ─────────────────────────────────────────────────────────────
    // 6. イベント監視 (WebSocketリスナーのシミュレーション)
    //
    // Foundryでは vm.recordLogs() + vm.getRecordedLogs() を使って
    // オフチェーンのWebSocketリスナーと同等のイベント検証ができる
    // ─────────────────────────────────────────────────────────────

    function test_Event_LockedEventHasCorrectTopicsAndData() public {
        vm.recordLogs();

        vm.prank(user);
        vault.lock(_usdc(300), PRIVATE_RECIPIENT);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Transfer(ERC20) + Locked の2イベントが発火
        // Locked は最後のログ
        Vm.Log memory lockedLog = logs[logs.length - 1];

        // topic[0] = イベントシグネチャ
        assertEq(
            lockedLog.topics[0],
            keccak256("Locked(address,uint256,bytes32,uint256)")
        );
        // topic[1] = sender (indexed)
        assertEq(lockedLog.topics[1], bytes32(uint256(uint160(user))));
        // topic[2] = privateChainRecipient (indexed)
        assertEq(lockedLog.topics[2], PRIVATE_RECIPIENT);

        // data = amount のみ（lockIdはindexedなのでtopic[3]に入る）
        uint256 amount = abi.decode(lockedLog.data, (uint256));
        assertEq(amount, _usdc(300));

        // topic[3] = lockId (indexed)
        assertEq(lockedLog.topics[3], bytes32(uint256(1)));
    }

    function test_Event_UnlockedEventHasCorrectTopicsAndData()
        public withLockedUSDC(_usdc(1000))
    {
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        vm.recordLogs();

        vm.prank(relayer2);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Unlockedイベントを探す
        bytes32 unlockedSig = keccak256("Unlocked(bytes32,address,uint256)");
        Vm.Log memory unlockedLog;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == unlockedSig) {
                unlockedLog = logs[i];
                break;
            }
        }

        // topic[1] = privateTxHash (indexed)
        assertEq(unlockedLog.topics[1], PRIVATE_TX_HASH);
        // topic[2] = recipient (indexed)
        assertEq(unlockedLog.topics[2], bytes32(uint256(uint160(user))));

        // data = amount
        uint256 amount = abi.decode(unlockedLog.data, (uint256));
        assertEq(amount, _usdc(500));
    }

    function test_Event_LockUnlockFlowEmitsEventsInOrder()
        public
    {
        vm.recordLogs();

        // Step1: Lock
        vm.prank(user);
        vault.lock(_usdc(500), PRIVATE_RECIPIENT);

        // Step2: Unlock (2-of-3)
        vm.prank(relayer1);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));
        vm.prank(relayer2);
        vault.approveUnlock(PRIVATE_TX_HASH, user, _usdc(500));

        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 lockedSig   = keccak256("Locked(address,uint256,bytes32,uint256)");
        bytes32 unlockedSig = keccak256("Unlocked(bytes32,address,uint256)");

        // ログ内でLockedがUnlockedより前に出現することを確認
        uint256 lockedIdx   = type(uint256).max;
        uint256 unlockedIdx = type(uint256).max;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == lockedSig   && lockedIdx   == type(uint256).max) lockedIdx = i;
            if (logs[i].topics[0] == unlockedSig && unlockedIdx == type(uint256).max) unlockedIdx = i;
        }

        assertTrue(lockedIdx   != type(uint256).max, "Locked event not found");
        assertTrue(unlockedIdx != type(uint256).max, "Unlocked event not found");
        assertLt(lockedIdx, unlockedIdx, "Locked should come before Unlocked");

        console.log("Locked  event at log index:", lockedIdx);
        console.log("Unlocked event at log index:", unlockedIdx);
    }

    // ─────────────────────────────────────────────────────────────
    // 7. ADMIN 管理
    // ─────────────────────────────────────────────────────────────

    function test_Admin_CanAddRelayer() public {
        vm.prank(admin);
        vault.addRelayer(attacker);

        bytes32 RELAYER_ROLE = vault.RELAYER_ROLE();
        assertTrue(vault.hasRole(RELAYER_ROLE, attacker));
    }

    function test_Admin_CanRemoveRelayer() public {
        vm.prank(admin);
        vault.removeRelayer(relayer3);

        bytes32 RELAYER_ROLE = vault.RELAYER_ROLE();
        assertFalse(vault.hasRole(RELAYER_ROLE, relayer3));
    }

    function test_Admin_CanUpdateThreshold() public {
        vm.prank(admin);
        vault.setThreshold(3);
        assertEq(vault.threshold(), 3);
    }

    function test_Admin_CanUpdateDailyLimit() public {
        vm.prank(admin);
        vault.setDailyUnlockLimit(_usdc(500_000));
        assertEq(vault.dailyUnlockLimit(), _usdc(500_000));
    }

    // ─────────────────────────────────────────────────────────────
    // 8. FUZZ TESTS
    // ─────────────────────────────────────────────────────────────

    function testFuzz_Lock_AnyValidAmountWorks(uint256 amount) public {
        // 1 〜 10,000 USDCの範囲でfuzz
        amount = bound(amount, 1, _usdc(10_000));

        usdc.mint(user, amount);
        vm.prank(user);
        usdc.approve(address(vault), amount);

        vm.prank(user);
        vault.lock(amount, PRIVATE_RECIPIENT);

        assertEq(vault.totalLocked(), amount);
    }

    function testFuzz_ReplayProtection_DifferentHashesWork(
        bytes32 hash1,
        bytes32 hash2
    ) public withLockedUSDC(_usdc(2000)) {
        vm.assume(hash1 != hash2);
        vm.assume(hash1 != bytes32(0));
        vm.assume(hash2 != bytes32(0));

        // hash1 でunlock
        vm.prank(relayer1);
        vault.approveUnlock(hash1, user, _usdc(100));
        vm.prank(relayer2);
        vault.approveUnlock(hash1, user, _usdc(100));

        // hash2 でも別途unlock可能
        vm.prank(relayer1);
        vault.approveUnlock(hash2, user, _usdc(100));
        vm.prank(relayer2);
        vault.approveUnlock(hash2, user, _usdc(100));

        assertTrue(vault.isProcessed(hash1));
        assertTrue(vault.isProcessed(hash2));
    }
}
