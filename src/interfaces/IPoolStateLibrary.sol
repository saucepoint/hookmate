// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";

interface IPoolStateLibrary {
    function getSlot0(IPoolManager manager, PoolId poolId)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 swapFee);

    function getTickInfo(IPoolManager manager, PoolId poolId, int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128
        );

    function getTickLiquidity(IPoolManager manager, PoolId poolId, int24 tick)
        external
        view
        returns (uint128 liquidityGross, int128 liquidityNet);

    function getTickFeeGrowthOutside(IPoolManager manager, PoolId poolId, int24 tick)
        external
        view
        returns (uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128);

    function getFeeGrowthGlobal0X128(IPoolManager manager, PoolId poolId)
        external
        view
        returns (uint256 feeGrowthGlobal0X128);

    function getLiquidity(IPoolManager manager, PoolId poolId) external view returns (uint128 liquidity);

    function getTickBitmap(IPoolManager manager, PoolId poolId, int16 tick)
        external
        view
        returns (uint256 tickBitmap);

    function getPositionInfo(IPoolManager manager, PoolId poolId, bytes32 positionId)
        external
        view
        returns (
            uint128 liquidity,
            int24 tickLower,
            int24 tickUpper,
            uint128 feeGrowthInside0LastX128,
            uint128 feeGrowthInside1LastX128,
            uint128 feeGrowthOutside0X128,
            uint128 feeGrowthOutside1X128
        );

    function getFeeGrowthInside(IPoolManager manager, PoolId poolId, int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128);
}
