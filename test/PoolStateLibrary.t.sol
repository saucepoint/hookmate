// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Pool} from "v4-core/src/libraries/Pool.sol";

import {PoolStateLibrary} from "../src/libraries/PoolStateLibrary.sol";

contract PoolStateLibraryTest is Test, Deployers {
    using FixedPointMathLib for uint256;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    PoolId poolId;

    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        (currency0, currency1) = Deployers.deployMintAndApprove2Currencies();

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(0x0)));
        poolId = key.toId();
        initializeRouter.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);
    }

    function test_getTickLiquidity() public {
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);

        (uint128 liquidityGross, int128 liquidityNet) = PoolStateLibrary.getTickLiquidity(manager, poolId, -60);
        // console2.log("liquidityGross", liquidityGross);
        // console2.log("liquidityNet", liquidityNet);

        assertEq(liquidityGross, 10 ether);
    }

    function test_getFeeGrowthGlobal0() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        (uint256 feeGrowthGlobal0, uint256 feeGrowthGlobal1) = PoolStateLibrary.getFeeGrowthGlobal(manager, poolId);
        assertEq(feeGrowthGlobal0, 0);
        assertEq(feeGrowthGlobal1, 0);

        // swap to create fees on the output token (currency1)
        uint256 swapAmount = 10 ether;
        swap(key, true, int256(swapAmount), ZERO_BYTES);

        (feeGrowthGlobal0, feeGrowthGlobal1) = PoolStateLibrary.getFeeGrowthGlobal(manager, poolId);

        assertEq(feeGrowthGlobal0, swapAmount.mulWadDown(0.003e18) * Q128);
        assertEq(feeGrowthGlobal1, 0);
    }

    function test_getFeeGrowthGlobal1() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        (uint256 feeGrowthGlobal0, uint256 feeGrowthGlobal1) = PoolStateLibrary.getFeeGrowthGlobal(manager, poolId);
        assertEq(feeGrowthGlobal0, 0);
        assertEq(feeGrowthGlobal1, 0);

        // swap to create fees on the input token (currency0)
        uint256 swapAmount = 10 ether;
        swap(key, false, int256(swapAmount), ZERO_BYTES);

        (feeGrowthGlobal0, feeGrowthGlobal1) = PoolStateLibrary.getFeeGrowthGlobal(manager, poolId);

        assertEq(feeGrowthGlobal0, 0);
        assertEq(feeGrowthGlobal1, swapAmount.mulWadDown(0.003e18) * Q128);
    }

    function test_getLiquidity() public {
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether), ZERO_BYTES);

        uint128 liquidity = PoolStateLibrary.getLiquidity(manager, poolId);
        assertEq(liquidity, 20 ether);
    }

    function test_getLiquidity_fuzz(uint128 liquidityDelta) public {
        vm.assume(liquidityDelta != 0);
        vm.assume(liquidityDelta < Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing));
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(
                TickMath.minUsableTick(60), TickMath.maxUsableTick(60), int256(uint256(liquidityDelta))
            ),
            ZERO_BYTES
        );

        uint128 liquidity = PoolStateLibrary.getLiquidity(manager, poolId);
        assertEq(liquidity, liquidityDelta);
    }

    /// Test Helper
    function swap(PoolKey memory key, bool zeroForOne, int256 amountSpecified, bytes memory hookData)
        internal
        returns (BalanceDelta delta)
    {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1 // unlimited impact
        });

        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({withdrawTokens: true, settleUsingTransfer: true, currencyAlreadySent: false});

        delta = swapRouter.swap(key, params, testSettings, hookData);
    }
}