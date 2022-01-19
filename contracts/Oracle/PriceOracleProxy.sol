pragma solidity ^0.8.0;

import "./PriceOracle.sol";
import "../Interfaces/FeedRegistryInterface.sol";
import "../CToken/CErc20.sol";
import "../CToken/CToken.sol";
import "../Utils/Exponential.sol";
import "../Interfaces/EIP20Interface.sol";
import "../Utils/SafeMath.sol";
// import "./Uniswap/UniswapLib.sol";
import "./Uniswap/UniswapConfig.sol";
import "../Utils/NPSwap.sol";

struct Observation {
    uint timestamp;
    uint acc;
}

contract PriceOracleProxy is PriceOracle, Exponential, UniswapConfig {
    using SafeMath for uint;
    using FixedPoint for *;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not Admin");
        _;
    }

    modifier notZeroAddress(address addr_) {
        require(addr_!=address(0), "Not Zero Address");
        _;
    }

    struct AggregatorInfo {
        // The base
        address base;
        // The quote denomination
        address quote;
        // It's being used or not
        bool isUsed;
    }

    /// @notice Admin address
    address public admin;

    /// @notice Guardian address
    address public guardian;

    /// @notice The minimum amount of time in seconds required for the old uniswap price accumulator to be replaced
    uint public immutable anchorPeriod;

    /// @notice A common scaling factor to maintain precision
    // uint public constant expScale = 1e18;

    /// @notice The number of wei in 1 ETH
    uint public constant ethBaseUnit = 1e18;

    /// @notice Official prices by symbol hash
    mapping(bytes32 => uint) public prices;

    /// @notice The old observation for each symbolHash
    mapping(bytes32 => Observation) public oldObservations;

    /// @notice The new observation for each symbolHash
    mapping(bytes32 => Observation) public newObservations;

    /// @notice ChainLink quotes
    mapping(address => AggregatorInfo) public aggregators;

    /// @notice BTC related addresses. All these underlying we use `Denominations.BTC` as the aggregator base.
    address[6] public btcAddresses = [
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
        0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D, // renBTC
        0x9BE89D2a4cd102D8Fecc6BF9dA793be995C22541, // BBTC
        0x8dAEBADE922dF735c38C80C7eBD708Af50815fAa, // tBTC
        0x0316EB71485b0Ab14103307bf65a021042c6d380, // HBTC
        0xc4E15973E6fF2A35cC804c2CF9D2a1b817a8b40F // ibBTC
    ];

    address public cEthAddress;

    address public constant usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant wethAddress = 0xDA2E05B28c42995D0FE8235861Da5124C1CE81Dd;
    address public constant sushiAddress = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    address public constant xSushiExRateAddress = 0x851a040fC0Dcbb13a272EBC272F2bC2Ce1e11C4d;
    address public constant crXSushiAddress = 0x228619CCa194Fbe3Ebeb2f835eC1eA5080DaFbb2;

    /**
     * @param admin_ The address of admin to set aggregators, LPs, curve tokens, or Yvault tokens
     * @param anchorPeriod_ Minimum price updating interval
     */
    constructor(
        address admin_,
        uint anchorPeriod_
    ) public {
        admin = admin_;
        anchorPeriod = anchorPeriod_;
    }

    function addConfig(TokenConfig[] memory configs) public onlyAdmin {
        require(configs.length+numTokens < maxTokens, "Too Many Configs");
        for (uint i; i<configs.length; i++) {
            configs[i].isUniswapReversed = NPSwap.isReversed(configs[i].underlying, 
                                                             configs[i].stableCoin);
            configForCToken[configs[i].cToken] = configs[i];
            cTokens.push(configs[i].cToken);
        }
    }

    function initialize(
        address[] memory ctokens
    ) public {
        for (uint i; i < ctokens.length; i++) {
            address ctoken = ctokens[i];

            TokenConfig memory config = configForCToken[ctoken];
            bytes32 symbolHash = config.symbolHash;
            require(config.baseUnit > 0, "baseUnit must be greater than zero");
            require(oldObservations[symbolHash].timestamp == 0, "Already initialized");
            address uniswapMarket = config.uniswapMarket;

            require(uniswapMarket != address(0), "reported prices must have an anchor");
            uint cumulativePrice = currentCumulativePrice(config);
            oldObservations[symbolHash].timestamp = block.timestamp;
            newObservations[symbolHash].timestamp = block.timestamp;
            oldObservations[symbolHash].acc = cumulativePrice;
            newObservations[symbolHash].acc = cumulativePrice;
            // emit UniswapWindowUpdated(symbolHash, block.timestamp, block.timestamp, cumulativePrice, cumulativePrice);
        }
    }

    /**
     * @dev Fetches the current token/eth price accumulator from uniswap.
     */
    function currentCumulativePrice(TokenConfig memory config) internal view returns (uint) {
        (uint cumulativePrice0, uint cumulativePrice1,) = UniswapV2OracleLibrary.currentCumulativePrices(config.uniswapMarket);
        if (config.isUniswapReversed) {
            return cumulativePrice1; // in order: token1, token0
        } else {
            return cumulativePrice0; // in order: token0, token1
        }
    }

    /**
     * @notice Get the underlying price of a listed cToken asset
     * @param cToken The cToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18)
     */
    function getUnderlyingPrice(CToken cToken) public view override returns (uint256) {
        return getTokenPrice(CErc20(address(cToken)).underlying());
    }

    function updateTokenPrices() public {
        for (uint i; i<cTokens.length; i++) {
            updateTokenPrice(cTokens[i]);
        }
    }

    function updateTokenPrice(address cToken) internal {
        TokenConfig memory config = configForCToken[cToken];

        bytes32 symbolHash = config.symbolHash;

        uint anchorPrice = fetchAnchorPrice(config);

        prices[symbolHash] = anchorPrice;
        // emit PriceUpdated(symbol, anchorPrice);
    }

    /*** Internal fucntions ***/

    /**
     * @notice Get the price of a specific token. Return 1e18 is it's WETH.
     * @param token The token to get the price of
     * @return The price
     */
     // todo: revise to internal
    function getTokenPrice(address token) public view returns (uint256) {
        if (token == wethAddress) {
            // weth always worth 1
            return 1e18;
        }

        return prices[configForCToken[token].symbolHash];
    }

    // function getPriceFromChainlink(address token) internal view returns (uint256) {
    //     require(aggregators[token].isUsed, "Chainlink Not Valid");
    //     (, int256 price, , , ) = registry.latestRoundData(aggregators[token].base, aggregators[token].quote);
    //     require(price > 0, "invalid price");
    //     uint256 underlyingDecimals = EIP20Interface(token).decimals();
    //     price = mul_(price, 10**(18 - underlyingDecimals));

    //     if (aggregators[token].quote == Denominations.USD) {
    //         // Convert the price to ETH based if it's USD based.
    //         price = mul_(price, Exp({mantissa: getUsdcEthPrice()}));
    //     }
    // }

    /**
     * @notice Get USDC price
     * @dev We treat USDC as USD for convenience
     * @return The USDC price
     */
    function getUsdcEthPrice() internal view returns (uint256) {
        return getTokenPrice(usdcAddress) / 1e12;
    }

    /**
     * @dev Get time-weighted average prices for a token at the current timestamp.
     *  Update new and old observations of lagging window if period elapsed.
     */
    function pokeWindowValues(TokenConfig memory config) internal returns (uint, uint, uint) {
        bytes32 symbolHash = config.symbolHash;
        uint cumulativePrice = currentCumulativePrice(config); // Token0 vs stablecoin, care about reversed

        Observation memory newObservation = newObservations[symbolHash];

        // Update new and old observations if elapsed time is greater than or equal to anchor period
        uint timeElapsed = block.timestamp - newObservation.timestamp;
        if (timeElapsed >= anchorPeriod) {
            oldObservations[symbolHash].timestamp = newObservation.timestamp;
            oldObservations[symbolHash].acc = newObservation.acc;

            newObservations[symbolHash].timestamp = block.timestamp;
            newObservations[symbolHash].acc = cumulativePrice;
            // emit UniswapWindowUpdated(config.symbolHash, newObservation.timestamp, block.timestamp, newObservation.acc, cumulativePrice);
        }
        return (cumulativePrice, oldObservations[symbolHash].acc, oldObservations[symbolHash].timestamp);
    }

    /**
     * @dev Fetches the current token/usd price from uniswap, with 6 decimals of precision.
     */
     // todo: internal
    function fetchAnchorPrice(TokenConfig memory config) public virtual returns (uint) {
        (uint nowCumulativePrice, uint oldCumulativePrice, uint oldTimestamp) = pokeWindowValues(config);

        // This should be impossible, but better safe than sorry
        require(block.timestamp > oldTimestamp, "now must come after before");
        uint timeElapsed = block.timestamp - oldTimestamp;

        // Calculate uniswap time-weighted average price
        // Underflow is a property of the accumulators: https://uniswap.org/audit.html#orgc9b3190
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(uint224((nowCumulativePrice - oldCumulativePrice) / timeElapsed));
        uint rawUniswapPriceMantissa = priceAverage.decode112with18(); // 10 * 10 ** 18 eth / token
        uint unscaledPriceMantissa = mul(rawUniswapPriceMantissa, 10 ** 6); // 10 * 10 ** 18 * 3000 * 10 ** 6
        uint anchorPrice;

        // Adjust rawUniswapPrice according to the units of the non-ETH asset
        // In the case of ETH, we would have to scale by 1e6 / USDC_UNITS, but since baseUnit2 is 1e6 (USDC), it cancels

        // In the case of non-ETH tokens
        // a. pokeWindowValues already handled uniswap reversed cases, so priceAverage will always be Token/ETH TWAP price.
        // b. conversionFactor = ETH price * 1e6
        // unscaledPriceMantissa = priceAverage(token/StableCoin TWAP price) * expScale * conversionFactor
        // so ->
        // anchorPrice = priceAverage * tokenBaseUnit / ethBaseUnit * ETH_price * 1e6
        //             = priceAverage * conversionFactor * tokenBaseUnit / ethBaseUnit
        //             = unscaledPriceMantissa / expScale * tokenBaseUnit / ethBaseUnit
        // 10  * 3000 * 10 ** 6 
        anchorPrice = mul(unscaledPriceMantissa, config.baseUnit) / ethBaseUnit / expScale;

        // emit AnchorPriceUpdated(symbol, anchorPrice, oldTimestamp, block.timestamp);
        emit Test(timeElapsed, unscaledPriceMantissa, anchorPrice);
        return anchorPrice;
    }
    event Test(uint indexed timeElapsed, uint indexed unscaledPriceMantissa, uint indexed anchorPrice);

    /**
     * @notice Get price whose base token is token1
     * @param token1 token address
     * @param token2 token address
     * @return price
     */
    function getPriceFromDex(address token1, address token2) public view returns (uint256 price) {
        (uint token1Amount, uint token2Amount) = NPSwap.getReserves(token1, token2);
        // uint usdcPrice = getUsdcEthPrice();
        price = token1Amount.mul(10**18).div(token2Amount);
    }

    /*** Admin or guardian functions ***/

    event AggregatorUpdated(address tokenAddress, address base, address quote, bool isUsed);
    event SetGuardian(address guardian);
    event SetAdmin(address admin);

    /**
     * @notice Set ChainLink aggregators for multiple tokens
     * @param tokenAddresses The list of underlying tokens
     * @param bases The list of ChainLink aggregator bases
     * @param quotes The list of ChainLink aggregator quotes, currently support 'ETH' and 'USD'
     */
    // function _setAggregators(
    //     address[] calldata tokenAddresses,
    //     address[] calldata bases,
    //     address[] calldata quotes
    // ) external {
    //     require(msg.sender == admin || msg.sender == guardian, "only the admin or guardian may set the aggregators");
    //     require(tokenAddresses.length == bases.length && tokenAddresses.length == quotes.length, "mismatched data");
    //     for (uint256 i = 0; i < tokenAddresses.length; i++) {
    //         bool isUsed;
    //         if (bases[i] != address(0)) {
    //             require(msg.sender == admin, "guardian may only clear the aggregator");
    //             require(quotes[i] == Denominations.ETH || quotes[i] == Denominations.USD, "unsupported denomination");
    //             isUsed = true;

    //             // Make sure the aggregator exists.
    //             address aggregator = registry.getFeed(bases[i], quotes[i]);
    //             require(registry.isFeedEnabled(aggregator), "aggregator not enabled");
    //         }
    //         aggregators[tokenAddresses[i]] = AggregatorInfo({base: bases[i], quote: quotes[i], isUsed: isUsed});
    //         emit AggregatorUpdated(tokenAddresses[i], bases[i], quotes[i], isUsed);
    //     }
    // }

    /**
     * @notice Set guardian for price oracle proxy
     * @param _guardian The new guardian
     */
    function _setGuardian(address _guardian) external {
        require(msg.sender == admin, "only the admin may set new guardian");
        guardian = _guardian;
        emit SetGuardian(guardian);
    }

    /**
     * @notice Set admin for price oracle proxy
     * @param _admin The new admin
     */
    function _setAdmin(address _admin) external {
        require(msg.sender == admin, "only the admin may set new admin");
        admin = _admin;
        emit SetAdmin(admin);
    }

    /// @dev Overflow proof multiplication
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) return 0;
        uint c = a * b;
        require(c / a == b, "multiplication overflow");
        return c;
    }
}
