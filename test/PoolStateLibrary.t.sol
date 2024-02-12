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

import {PoolManager} from "v4-core/src/PoolManager.sol";

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

    function test_getSlot0() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-600, 600, 10_000 ether), ZERO_BYTES
        );

        // swap to create fees, crossing a tick
        uint256 swapAmount = 100 ether;
        swap(key, true, int256(swapAmount), ZERO_BYTES);
        (, int24 currentTick,) = manager.getSlot0(poolId);
        assertEq(currentTick, -139);

        (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 swapFee) =
            PoolStateLibrary.getSlot0(manager, poolId);

        (uint160 sqrtPriceX96_, int24 tick_, uint16 protocolFee_) = manager.getSlot0(poolId);

        assertEq(sqrtPriceX96, sqrtPriceX96_);
        assertEq(tick, tick_);
        assertEq(tick, -139);
        assertEq(protocolFee, 0);
        assertEq(protocolFee, protocolFee_);
        assertEq(swapFee, 3000);
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

    function test_getTickBitmap() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        // TODO: why does fail for -60 or 60 :thinking:
        uint256 tickBitmap = PoolStateLibrary.getTickBitmap(manager, poolId, 0);
        assertNotEq(tickBitmap, 0);
    }

    function test_getPositionInfo() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-600, 600, 10_000 ether), ZERO_BYTES
        );

        // swap to create fees, crossing a tick
        uint256 swapAmount = 100 ether;
        swap(key, true, int256(swapAmount), ZERO_BYTES);
        (, int24 currentTick,) = manager.getSlot0(poolId);
        assertEq(currentTick, -139);

        // poke the LP so that fees are updated
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 0), ZERO_BYTES);

        bytes32 positionId = keccak256(abi.encodePacked(address(modifyLiquidityRouter), int24(-60), int24(60)));

        (uint128 liquidity, uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            PoolStateLibrary.getPositionInfo(manager, poolId, positionId);

        assertEq(liquidity, 10_000 ether);

        assertNotEq(feeGrowthInside0X128, 0);
        assertEq(feeGrowthInside1X128, 0);
    }

    function test_getTickFeeGrowthOutside() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-600, 600, 10_000 ether), ZERO_BYTES
        );

        // swap to create fees, crossing a tick
        uint256 swapAmount = 100 ether;
        swap(key, true, int256(swapAmount), ZERO_BYTES);
        (, int24 currentTick,) = manager.getSlot0(poolId);
        assertEq(currentTick, -139);

        int24 tick = -60;
        (uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128) =
            PoolStateLibrary.getTickFeeGrowthOutside(manager, poolId, tick);

        (uint256 outside0, uint256 outside1) = PoolManager(payable(manager)).getTickFeeGrowthOutside(poolId, tick);

        assertNotEq(feeGrowthOutside0X128, 0);
        assertEq(feeGrowthOutside1X128, 0);
        assertEq(feeGrowthOutside0X128, outside0);
        assertEq(feeGrowthOutside1X128, outside1);
    }

    function test_getTickInfo() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-600, 600, 10_000 ether), ZERO_BYTES
        );

        // swap to create fees, crossing a tick
        uint256 swapAmount = 100 ether;
        swap(key, true, int256(swapAmount), ZERO_BYTES);
        (, int24 currentTick,) = manager.getSlot0(poolId);
        assertEq(currentTick, -139);

        int24 tick = -60;
        (uint128 liquidityGross, int128 liquidityNet, uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128) =
            PoolStateLibrary.getTickInfo(manager, poolId, tick);

        (uint128 liquidityGross_, int128 liquidityNet_) = PoolStateLibrary.getTickLiquidity(manager, poolId, tick);
        (uint256 feeGrowthOutside0X128_, uint256 feeGrowthOutside1X128_) =
            PoolStateLibrary.getTickFeeGrowthOutside(manager, poolId, tick);

        assertEq(liquidityGross, 10_000 ether);
        assertEq(liquidityGross, liquidityGross_);
        assertEq(liquidityNet, liquidityNet_);

        assertNotEq(feeGrowthOutside0X128, 0);
        assertEq(feeGrowthOutside1X128, 0);
        assertEq(feeGrowthOutside0X128, feeGrowthOutside0X128_);
        assertEq(feeGrowthOutside1X128, feeGrowthOutside1X128_);
    }

    function test_getFeeGrowthInside() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-600, 600, 10_000 ether), ZERO_BYTES
        );

        // swap to create fees, crossing a tick
        uint256 swapAmount = 100 ether;
        swap(key, true, int256(swapAmount), ZERO_BYTES);
        (, int24 currentTick,) = manager.getSlot0(poolId);
        assertEq(currentTick, -139);

        // poke the LP so that fees are updated
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 0), ZERO_BYTES);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            PoolStateLibrary.getFeeGrowthInside(manager, poolId, -60, 60);

        bytes32 positionId = keccak256(abi.encodePacked(address(modifyLiquidityRouter), int24(-60), int24(60)));

        (, uint256 feeGrowthInside0X128_, uint256 feeGrowthInside1X128_) =
            PoolStateLibrary.getPositionInfo(manager, poolId, positionId);

        assertNotEq(feeGrowthInside0X128, 0);
        assertEq(feeGrowthInside0X128, feeGrowthInside0X128_);
        assertEq(feeGrowthInside1X128, feeGrowthInside1X128_);
    }

    function test_getPositionLiquidity() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        bytes32 positionId = keccak256(abi.encodePacked(address(modifyLiquidityRouter), int24(-60), int24(60)));

        uint128 liquidity = PoolStateLibrary.getPositionLiquidity(manager, poolId, positionId);

        assertEq(liquidity, 10_000 ether);
    }

    function test_getPositionLiquidity_fuzz(
        int24 tickLowerA,
        int24 tickUpperA,
        uint128 liquidityDeltaA,
        int24 tickLowerB,
        int24 tickUpperB,
        uint128 liquidityDeltaB
    ) public {
        vm.assume(0.1e18 < liquidityDeltaA);

        vm.assume(0.1e18 < liquidityDeltaB);

        vm.assume(liquidityDeltaA < Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing));
        vm.assume(liquidityDeltaB < Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing));

        tickLowerA = int24(
            bound(
                int256(tickLowerA),
                int256(TickMath.minUsableTick(key.tickSpacing)),
                int256(TickMath.maxUsableTick(key.tickSpacing))
            )
        );
        tickUpperA = int24(
            bound(
                int256(tickUpperA),
                int256(TickMath.minUsableTick(key.tickSpacing)),
                int256(TickMath.maxUsableTick(key.tickSpacing))
            )
        );
        tickLowerB = int24(
            bound(
                int256(tickLowerB),
                int256(TickMath.minUsableTick(key.tickSpacing)),
                int256(TickMath.maxUsableTick(key.tickSpacing))
            )
        );
        tickUpperB = int24(
            bound(
                int256(tickUpperB),
                int256(TickMath.minUsableTick(key.tickSpacing)),
                int256(TickMath.maxUsableTick(key.tickSpacing))
            )
        );

        // round down ticks
        tickLowerA = (tickLowerA / key.tickSpacing) * key.tickSpacing;
        tickUpperA = (tickUpperA / key.tickSpacing) * key.tickSpacing;
        tickLowerB = (tickLowerB / key.tickSpacing) * key.tickSpacing;
        tickUpperB = (tickUpperB / key.tickSpacing) * key.tickSpacing;

        vm.assume(tickLowerA < tickUpperA);
        vm.assume(tickLowerB < tickUpperB);
        vm.assume(tickLowerA != tickLowerB && tickUpperA != tickUpperB);

        // positionA
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(tickLowerA, tickUpperA, int256(uint256(liquidityDeltaA))),
            ZERO_BYTES
        );

        // positionB
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(tickLowerB, tickUpperB, int256(uint256(liquidityDeltaB))),
            ZERO_BYTES
        );

        bytes32 positionIdA = keccak256(abi.encodePacked(address(modifyLiquidityRouter), tickLowerA, tickUpperA));
        uint128 liquidityA = PoolStateLibrary.getPositionLiquidity(manager, poolId, positionIdA);
        assertEq(liquidityA, liquidityDeltaA);

        bytes32 positionIdB = keccak256(abi.encodePacked(address(modifyLiquidityRouter), tickLowerB, tickUpperB));
        uint128 liquidityB = PoolStateLibrary.getPositionLiquidity(manager, poolId, positionIdB);
        assertEq(liquidityB, liquidityDeltaB);
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
