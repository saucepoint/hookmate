// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

library PoolStateLibrary {
    // forge inspect lib/v4-core/src/PoolManager.sol:PoolManager storage --pretty
    // | Name                  | Type                                                                | Slot | Offset | Bytes | Contract                                    |
    // |-----------------------|---------------------------------------------------------------------|------|--------|-------|---------------------------------------------|
    // | pools                 | mapping(PoolId => struct Pool.State)                                | 8    | 0      | 32    | lib/v4-core/src/PoolManager.sol:PoolManager |
    uint256 public constant POOLS_SLOT = 8;

    function getTickLiquidity(IPoolManager manager, PoolId poolId, int24 tick)
        internal
        view
        returns (uint128 liquidityGross, int128 liquidityNet)
    {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 5th word of Pool.State, `mapping(int24 => TickInfo) ticks`
        bytes32 ticksMapping = bytes32(uint256(stateSlot) + uint256(4));

        // value slot of the tick key: `pools[poolId].ticks[tick]
        bytes32 slot = keccak256(abi.encodePacked(int256(tick), ticksMapping));

        bytes32 value = manager.extsload(slot);
        assembly {
            liquidityGross := shr(128, value)
            liquidityNet := and(value, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }

    function getFeeGrowthGlobal(IPoolManager manager, PoolId poolId)
        internal
        view
        returns (uint256 feeGrowthGlobal0, uint256 feeGrowthGlobal1)
    {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 2nd word of Pool.State, `uint256 feeGrowthGlobal0X128`
        bytes32 slot_feeGrowthGlobal0X128 = bytes32(uint256(stateSlot) + uint256(1));

        // reads 3rd word of Pool.State, `uint256 feeGrowthGlobal1X128`
        bytes32 slot_feeGrowthGlobal1X128 = bytes32(uint256(stateSlot) + uint256(2));

        feeGrowthGlobal0 = uint256(manager.extsload(slot_feeGrowthGlobal0X128));
        feeGrowthGlobal1 = uint256(manager.extsload(slot_feeGrowthGlobal1X128));
    }

    function getLiquidity(IPoolManager manager, PoolId poolId) internal view returns (uint128 liquidity) {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 4th word of Pool.State, `uint128 liquidity`
        bytes32 slot = bytes32(uint256(stateSlot) + uint256(3));

        liquidity = uint128(uint256(manager.extsload(slot)));
    }

    function getTickBitmap(IPoolManager manager, PoolId poolId, int16 tick)
        internal
        view
        returns (uint256 tickBitmap)
    {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 6th word of Pool.State, `mapping(int16 => uint256) tickBitmap;`
        bytes32 tickBitmapMapping = bytes32(uint256(stateSlot) + uint256(5));

        // value slot of the mapping key: `pools[poolId].tickBitmap[tick]
        bytes32 slot = keccak256(abi.encodePacked(int256(tick), tickBitmapMapping));

        tickBitmap = uint256(manager.extsload(slot));
    }

    function getPositionInfo(IPoolManager manager, PoolId poolId, bytes32 positionId)
        internal
        view
        returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128)
    {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 7th word of Pool.State, `mapping(bytes32 => Position.Info) positions;`
        bytes32 positionMapping = bytes32(uint256(stateSlot) + uint256(6));

        // first value slot of the mapping key: `pools[poolId].positions[positionId] (liquidity)
        bytes32 slot0 = keccak256(abi.encodePacked(positionId, positionMapping));

        // second value slot of the mapping key: `pools[poolId].positions[positionId].feeGrowthInside0LastX128`
        bytes32 slot1 = bytes32(uint256(slot0) + uint256(1));

        // third value slot of the mapping key: `pools[poolId].positions[positionId].feeGrowthInside1LastX128`
        bytes32 slot2 = bytes32(uint256(slot0) + uint256(2));

        liquidity = uint128(uint256(manager.extsload(slot0)));
        feeGrowthInside0LastX128 = uint256(manager.extsload(slot1));
        feeGrowthInside1LastX128 = uint256(manager.extsload(slot2));
    }
}
