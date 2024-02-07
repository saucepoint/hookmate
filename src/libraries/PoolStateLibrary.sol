// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {console2} from "forge-std/console2.sol";

library PoolStateLibrary {
    // forge inspect lib/v4-core/src/PoolManager.sol:PoolManager storage --pretty
    // | Name                  | Type                                                                | Slot | Offset | Bytes | Contract                                    |
    // |-----------------------|---------------------------------------------------------------------|------|--------|-------|---------------------------------------------|
    // | pools                 | mapping(PoolId => struct Pool.State)                                | 8    | 0      | 32    | lib/v4-core/src/PoolManager.sol:PoolManager |
    uint256 public constant POOLS_SLOT = 8;

    function getSlot0(IPoolManager manager, PoolId poolId)
        internal
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 swapFee)
    {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        bytes32 data = manager.extsload(stateSlot);

        //   32 bits  |24bits|16bits      |24 bits|160 bits
        // 0x00000000 000bb8 0000         ffff75  0000000000000000fe3aa841ba359daa0ea9eff7
        // ---------- | fee  |protocolfee | tick  | sqrtPriceX96
        assembly {
            // bottom 160 bits of data
            sqrtPriceX96 := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            // next 24 bits of data
            tick := and(shr(160, data), 0xFFFFFF)
            // next 16 bits of data
            protocolFee := and(shr(184, data), 0xFFFF)
            // last 24 bits of data
            swapFee := and(shr(200, data), 0xFFFFFF)
        }
    }

    function getTickInfo(IPoolManager manager, PoolId poolId, int24 tick)
        internal
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128
        )
    {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 5th word of Pool.State, `mapping(int24 => TickInfo) ticks`
        bytes32 ticksMapping = bytes32(uint256(stateSlot) + uint256(4));

        // value slot of the tick key: `pools[poolId].ticks[tick]
        bytes32 slot = keccak256(abi.encodePacked(int256(tick), ticksMapping));

        // read all 3 words of the TickInfo struct
        bytes memory data = manager.extsload(slot, 3);
        assembly {
            liquidityGross := shr(128, mload(add(data, 32)))
            liquidityNet := and(mload(add(data, 32)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            feeGrowthOutside0X128 := mload(add(data, 64))
            feeGrowthOutside1X128 := mload(add(data, 96))
        }
    }

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

    function getTickFeeGrowthOutside(IPoolManager manager, PoolId poolId, int24 tick)
        internal
        view
        returns (uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128)
    {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 5th word of Pool.State, `mapping(int24 => TickInfo) ticks`
        bytes32 ticksMapping = bytes32(uint256(stateSlot) + uint256(4));

        // value slot of the tick key: `pools[poolId].ticks[tick]
        bytes32 slot = keccak256(abi.encodePacked(int256(tick), ticksMapping));

        bytes memory data = manager.extsload(slot, 3);
        assembly {
            feeGrowthOutside0X128 := mload(add(data, 64))
            feeGrowthOutside1X128 := mload(add(data, 96))
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
        bytes32 slot = keccak256(abi.encodePacked(positionId, positionMapping));

        // read all 3 words of the Position.Info struct
        bytes memory data = manager.extsload(slot, 3);

        assembly {
            liquidity := mload(add(data, 32))
            feeGrowthInside0LastX128 := mload(add(data, 64))
            feeGrowthInside1LastX128 := mload(add(data, 96))
        }
    }

    // Calculates the fee growth inside a tick range. More reliable than `feeGrowthInside0LastX128` returned by getPositionInfo
    function getFeeGrowthInside(IPoolManager manager, PoolId poolId, int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128) = getFeeGrowthGlobal(manager, poolId);

        (uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128) =
            getTickFeeGrowthOutside(manager, poolId, tickLower);
        (uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128) =
            getTickFeeGrowthOutside(manager, poolId, tickUpper);
        (, int24 tickCurrent,,) = getSlot0(manager, poolId);
        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent >= tickUpper) {
                feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
                feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
            } else {
                feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            }
        }
    }
}
