//SPDX-License-Identifier: Unlicense
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IERC20Metadata.sol";
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
        setRange(oneIsMore(_amount0, _amount1));

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

        bool useOne = oneIsMore(amount0, amount1);
        setRange(useOne);

        uint256 a0 = useOne ? 0 : amount0;
        uint256 a1 = useOne ? amount1 : 0;

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

    function setRange(bool useOne) internal {
        (, int24 tick, , , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();

        (lower, upper) = (
            ((tick + tickSpacing) / tickSpacing) * tickSpacing,
            ((tick + tickSpacing + rangeSize) / tickSpacing) * tickSpacing
        );
        if (useOne) {
            (lower, upper) = (
                ((tick - tickSpacing - rangeSize) / tickSpacing) * tickSpacing,
                ((tick - tickSpacing) / tickSpacing) * tickSpacing
            );
        }

        lastRerange = block.timestamp;
    }

    function oneIsMore(
        uint256 amount0,
        uint256 amount1
    ) public view returns (bool) {
        IERC20Metadata zero = IERC20Metadata(token0);
        IERC20Metadata one = IERC20Metadata(token1);

        uint8 decimals0 = zero.decimals();
        uint8 decimals1 = one.decimals();
        bool oneIsBigDecimals = decimals1 > decimals0;

        uint8 diff = oneIsBigDecimals
            ? decimals1 - decimals0
            : decimals0 - decimals1;

        uint256 amount0Adjusted = oneIsBigDecimals
            ? amount0 * (10 ** diff)
            : amount0;
        uint256 amount1Adjusted = oneIsBigDecimals
            ? amount1
            : amount1 * (10 ** diff);

        return amount1Adjusted > amount0Adjusted;
    }
}
