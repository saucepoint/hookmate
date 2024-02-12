// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {Pool} from "v4-core/src/libraries/Pool.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";

contract V4TestHelpers is CommonBase, StdUtils {
    function createFuzzyLiquidity(
        PoolModifyLiquidityTest modifyLiquidityRouter,
        PoolKey memory key,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityDelta,
        bytes memory hookData
    ) internal returns (int24 _tickLower, int24 _tickUpper, uint128 _liquidityDelta, BalanceDelta delta) {
        vm.assume(0.0000001e18 < liquidityDelta);

        vm.assume(liquidityDelta < Pool.tickSpacingToMaxLiquidityPerTick(key.tickSpacing));

        tickLower = int24(
            bound(
                int256(tickLower),
                int256(TickMath.minUsableTick(key.tickSpacing)),
                int256(TickMath.maxUsableTick(key.tickSpacing))
            )
        );
        tickUpper = int24(
            bound(
                int256(tickUpper),
                int256(TickMath.minUsableTick(key.tickSpacing)),
                int256(TickMath.maxUsableTick(key.tickSpacing))
            )
        );

        // round down ticks
        tickLower = (tickLower / key.tickSpacing) * key.tickSpacing;
        tickUpper = (tickUpper / key.tickSpacing) * key.tickSpacing;
        vm.assume(tickLower < tickUpper);

        delta = modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(tickLower, tickUpper, int256(uint256(liquidityDelta))), hookData
        );
        _tickLower = tickLower;
        _tickUpper = tickUpper;
        _liquidityDelta = liquidityDelta;
    }
}
