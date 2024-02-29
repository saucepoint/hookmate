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

A solidity library to access `Pool.State` information -- *even the nested mappings*. Relies on the arbitrary storage slot reads exposed via `PoolManager.extsload`

Every value in `mapping(PoolId id => Pool.State) public pools;` is available via PoolStateLibrary:

```solidity
// PoolManager.sol
mapping(PoolId id => Pool.State) public pools;

// Pool.sol
struct State {
    Slot0 slot0;                   // getSlot0()
        | uint160 sqrtPriceX96;
        | int24 tick;
        | uint16 protocolFee;
        | uint24 swapFee;
    uint256 feeGrowthGlobal0X128;  // getFeeGrowthGlobal()
    uint256 feeGrowthGlobal1X128;  // ..
    uint128 liquidity;             // getLiquidity()
    mapping(int24 => TickInfo) ticks;      // getTickInfo()
        | uint128 liquidityGross;          // getTickLiquidity()
        | int128 liquidityNet;             // ..
        | uint256 feeGrowthOutside0X128;   // getTickFeeGrowthOutside()
        | uint256 feeGrowthOutside1X128;   // ..
    mapping(int16 => uint256) tickBitmap;  // getTickBitmap()
    mapping(bytes32 => Position.Info) positions;  // getPositionInfo()
        | uint128 liquidity;                      // getPositionLiquidity()
        | uint256 feeGrowthInside0LastX128;       // getFeeGrowthInside() (calculated live)
        | uint256 feeGrowthInside1LastX128;       // ..
}
```

Example Usage: Get Position Fees
```solidity
import {PoolStateLibrary} from "hookmate/libraries/PoolStateLibrary.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

...

using PoolIdLibrary for PoolKey;

...

IPoolManager manager = address(0xABC);
address liquidityOwner = address(0x123); // likely will be PoolModifyLiquidityTest
int24 tickLower = -60;
int24 tickUpper = 60;
PoolKey memory key = PoolKey(...);

bytes32 positionId = keccak256(abi.encodePacked(address(liquidityOwner), tickLower, tickUpper));

(uint128 liquidity, uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
    PoolStateLibrary.getPositionInfo(manager, key.toId(), positionId);

```
