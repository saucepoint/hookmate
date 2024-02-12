## hookmate

**_Experimental solidity utilities, libraries, and components for Uniswap v4 Hook development_**

---

## Installation

_requires [foundry](https://book.getfoundry.sh)_

```bash
forge install uniswapfoundation/hookmate
```

---

# Documentation

## Libraries

### `PoolStateLibrary.sol`

⚠️ Not production-ready. Will have breaking changes in the future ⚠️

_until v4-core code-freezes, the interfaces are subject to changes_

A solidity library to access `Pool.State` information -- even the nested mappings. Relies on the arbitrary storage slot reads exposed via `PoolManager.extsload`

Every value, below, is available via PoolStateLibrary:

```solidity
// PoolManager.sol
mapping(PoolId id => Pool.State) public pools;

// Pool.sol
struct State {
    Slot0 slot0;
    uint256 feeGrowthGlobal0X128;
    uint256 feeGrowthGlobal1X128;
    uint128 liquidity;
    mapping(int24 => TickInfo) ticks;
    mapping(int16 => uint256) tickBitmap;
    mapping(bytes32 => Position.Info) positions;
}

struct Slot0 {
    // the current price
    uint160 sqrtPriceX96;
    // the current tick
    int24 tick;
    // protocol swap fee represented as integer denominator (1/x), taken as a % of the LP swap fee
    // upper 8 bits are for 1->0, and the lower 8 are for 0->1
    // the minimum permitted denominator is 4 - meaning the maximum protocol fee is 25%
    // granularity is increments of 0.38% (100/type(uint8).max)
    uint16 protocolFee;
    // used for the swap fee, either static at initialize or dynamic via hook
    uint24 swapFee;
}

// info stored for each initialized individual tick
struct TickInfo {
    // the total position liquidity that references this tick
    uint128 liquidityGross;
    // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left),
    int128 liquidityNet;
    // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
    // only has relative meaning, not absolute — the value depends on when the tick is initialized
    uint256 feeGrowthOutside0X128;
    uint256 feeGrowthOutside1X128;
}

// Position.sol
// info stored for each user's position
struct Info {
    // the amount of liquidity owned by this position
    uint128 liquidity;
    // fee growth per unit of liquidity as of the last update to liquidity or fees owed
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
}
```

#### _getSlot0_
