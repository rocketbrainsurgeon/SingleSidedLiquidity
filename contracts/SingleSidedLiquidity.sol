//SPDX-License-Identifier: Unlicense
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

contract SingleSidedLiquidity is LiquidityManagement {
    IUniswapV3Pool public pool;
    address public user;
    int24 public lower;
    int24 public upper;
    address public token0;
    address public token1;
    uint24 public fee;
    int24 public rangeSize;
    uint256 public lastRerange;

    constructor(
        address _factory,
        address _WETH9
    ) PeripheryImmutableState(_factory, _WETH9) {}

    function deposit(
        address _token0,
        address _token1,
        uint24 _fee,
        uint256 _amount0,
        uint256 _amount1,
        int24 _ticks
    ) external {
        require(user == address(0), "User already deposited");
        require(_amount0 > 0 || _amount1 > 0, "Must deposit something");
        require(_amount0 == 0 || _amount1 == 0, "Must deposit only one token");

        user = msg.sender;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;

        // sort tokens, otherwise factory.getPool fails
        (token0, token1) = _token0 < _token1
            ? (_token0, _token1)
            : (_token1, _token0);

        pool = IUniswapV3Pool(
            IUniswapV3Factory(factory).getPool(_token0, _token1, _fee)
        );

        rangeSize = _ticks * pool.tickSpacing();
        setRange(_amount1 > _amount0);

        addLiquidity(
            AddLiquidityParams({
                token0: token0,
                token1: token1,
                fee: fee,
                recipient: address(this),
                tickLower: lower,
                tickUpper: upper,
                amount0Desired: _amount0,
                amount1Desired: _amount1,
                amount0Min: (_amount0 * 90) / 100,
                amount1Min: (_amount1 * 90) / 100
            })
        );
    }

    function getPosition()
        public
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        (
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        ) = pool.positions(PositionKey.compute(address(this), lower, upper));
    }

    function burn() private returns (uint256 amount0, uint256 amount1) {
        (uint128 liquidity, , , , ) = getPosition();

        pool.burn(lower, upper, liquidity);

        // contract harvests at same time as removes position
        // all fees and principal are sent to the user
        (amount0, amount1) = pool.collect(
            user,
            lower,
            upper,
            type(uint128).max,
            type(uint128).max
        );
    }

    function withdraw() external {
        require(user == msg.sender, "Only the depositor can withdraw");

        burn();

        user = address(0);
    }

    function rerange() external {
        require(user == msg.sender, "Only the depositor can rerange");
        require(isInRange() == false, "Must be out of range to rerange");

        // contract will compound all fees of the active token
        // fees gained from the inactive token are sent to the user
        (uint256 amount0, uint256 amount1) = burn();

        setRange(amount1 > amount0);

        uint256 a0 = amount0 > amount1 ? amount0 : 0;
        uint256 a1 = amount1 > amount0 ? amount1 : 0;

        addLiquidity(
            AddLiquidityParams({
                token0: token0,
                token1: token1,
                fee: fee,
                recipient: address(this),
                tickLower: lower,
                tickUpper: upper,
                amount0Desired: a0,
                amount1Desired: a1,
                amount0Min: (a0 * 90) / 100,
                amount1Min: (a1 * 90) / 100
            })
        );
    }

    function isInRange() public view returns (bool) {
        (, int24 currentTick, , , , , ) = pool.slot0();
        return currentTick >= lower && currentTick <= upper;
    }

    function setRange(bool oneIsMore) internal {
        (, int24 tick, , , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();

        (lower, upper) = (
            ((tick + tickSpacing) / tickSpacing) * tickSpacing,
            ((tick + tickSpacing + rangeSize) / tickSpacing) * tickSpacing
        );
        if (oneIsMore) {
            (lower, upper) = (
                ((tick - tickSpacing - rangeSize) / tickSpacing) * tickSpacing,
                ((tick - tickSpacing) / tickSpacing) * tickSpacing
            );
        }

        lastRerange = block.timestamp;
    }
}