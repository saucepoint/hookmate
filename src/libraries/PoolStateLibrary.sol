// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IPoolStateLibrary} from "../interfaces/IPoolStateLibrary.sol";

library PoolStateLibrary {
    // forge inspect lib/v4-core/src/PoolManager.sol:PoolManager storage --pretty
    // | Name                  | Type                                                                | Slot | Offset | Bytes | Contract                                    |
    // |-----------------------|---------------------------------------------------------------------|------|--------|-------|---------------------------------------------|
    // | pools                 | mapping(PoolId => struct Pool.State)                                | 8    | 0      | 32    | lib/v4-core/src/PoolManager.sol:PoolManager |
    uint256 public constant POOLS_SLOT = 8;

    /**
     * @dev Retrieves the slot 0 information of a pool.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @return sqrtPriceX96 The square root of the price of the pool.
     * @return tick The current tick of the pool.
     * @return protocolFee The protocol fee of the pool.
     * @return swapFee The swap fee of the pool.
     */
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

    /**
     * @dev Retrieves the tick information of a pool at a specific tick.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @param tick The tick to retrieve information for.
     * @return liquidityGross The gross liquidity at the tick.
     * @return liquidityNet The net liquidity at the tick.
     * @return feeGrowthOutside0X128 The fee growth outside the tick for token0.
     * @return feeGrowthOutside1X128 The fee growth outside the tick for token1.
     */
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

    /**
     * @dev Retrieves the liquidity information of a pool at a specific tick.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @param tick The tick to retrieve liquidity for.
     * @return liquidityGross The gross liquidity at the tick.
     * @return liquidityNet The net liquidity at the tick.
     */
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

    /**
     * @dev Retrieves the fee growth outside a tick range of a pool.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @param tick The tick to retrieve fee growth for.
     * @return feeGrowthOutside0X128 The fee growth outside the tick range for token0.
     * @return feeGrowthOutside1X128 The fee growth outside the tick range for token1.
     */
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

    /**
     * @dev Retrieves the global fee growth of a pool.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @return feeGrowthGlobal0 The global fee growth for token0.
     * @return feeGrowthGlobal1 The global fee growth for token1.
     */
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

    /**
     * @dev Retrieves the liquidity of a pool.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @return liquidity The liquidity of the pool.
     */
    function getLiquidity(IPoolManager manager, PoolId poolId) internal view returns (uint128 liquidity) {
        // value slot of poolId key: `pools[poolId]`
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), bytes32(POOLS_SLOT)));

        // reads 4th word of Pool.State, `uint128 liquidity`
        bytes32 slot = bytes32(uint256(stateSlot) + uint256(3));

        liquidity = uint128(uint256(manager.extsload(slot)));
    }

    /**
     * @dev Retrieves the tick bitmap of a pool at a specific tick.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @param tick The tick to retrieve the bitmap for.
     * @return tickBitmap The bitmap of the tick.
     */
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

    /**
     * @dev Retrieves the position information of a pool at a specific position ID.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @param positionId The ID of the position.
     * @return liquidity The liquidity of the position.
     * @return feeGrowthInside0LastX128 The fee growth inside the position for token0.
     * @return feeGrowthInside1LastX128 The fee growth inside the position for token1.
     */
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

    /**
     * @dev Calculates the fee growth inside a tick range of a pool.
     * @param manager The pool manager contract.
     * @param poolId The ID of the pool.
     * @param tickLower The lower tick of the range.
     * @param tickUpper The upper tick of the range.
     * @return feeGrowthInside0X128 The fee growth inside the tick range for token0.
     * @return feeGrowthInside1X128 The fee growth inside the tick range for token1.
     */
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
