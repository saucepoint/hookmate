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
import {TickBitmap} from "v4-core/src/libraries/TickBitmap.sol";
import {FixedPoint128} from "v4-core/src/libraries/FixedPoint128.sol";

import {PoolManager} from "v4-core/src/PoolManager.sol";

import {PoolStateLibrary} from "../src/libraries/PoolStateLibrary.sol";
import {V4TestHelpers} from "../src/test/V4TestHelpers.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

contract PoolStateLibraryGasTest is Test, Deployers, V4TestHelpers, GasSnapshot {
    using FixedPointMathLib for uint256;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    PoolId poolId;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        (currency0, currency1) = Deployers.deployMintAndApprove2Currencies();

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(0x0)));
        poolId = key.toId();
        manager.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);
    }

    function test_gas_slot0Native() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-600, 600, 10_000 ether), ZERO_BYTES
        );

        // swap to create fees, crossing a tick
        uint256 swapAmount = 100 ether;
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        (, int24 currentTick,,) = manager.getSlot0(poolId);
        assertEq(currentTick, -139);

        snapStart("getSlot0_native");
        manager.getSlot0(poolId);
        snapEnd();
    }

    function test_gas_slot0Extsload() public {
        // create liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 10_000 ether), ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-600, 600, 10_000 ether), ZERO_BYTES
        );

        // swap to create fees, crossing a tick
        uint256 swapAmount = 100 ether;
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        (, int24 currentTick,,) = manager.getSlot0(poolId);
        assertEq(currentTick, -139);

        snapStart("getSlot0_extsload");
        PoolStateLibrary.getSlot0(manager, poolId);
        snapEnd();
    }
}
