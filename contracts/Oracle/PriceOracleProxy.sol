pragma solidity ^0.8.0;

import "./Denominations.sol";
import "./PriceOracle.sol";
import "../Interfaces/FeedRegistryInterface.sol";
import "../CToken/CErc20.sol";
import "../CToken/CToken.sol";
import "../Utils/Exponential.sol";
import "../Interfaces/EIP20Interface.sol";
import "../Utils/NPSwap.sol";
import "../Utils/SafeMath.sol";

contract PriceOracleProxy is PriceOracle, Exponential, Denominations {
    using SafeMath for uint;

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

    /// @notice The ChainLink registry address
    FeedRegistryInterface public registry;

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
    address public constant wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant sushiAddress = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    address public constant xSushiExRateAddress = 0x851a040fC0Dcbb13a272EBC272F2bC2Ce1e11C4d;
    address public constant crXSushiAddress = 0x228619CCa194Fbe3Ebeb2f835eC1eA5080DaFbb2;

    /**
     * @param admin_ The address of admin to set aggregators, LPs, curve tokens, or Yvault tokens
     * @param v1PriceOracle_ The address of the v1 price oracle, which will continue to operate and hold prices for collateral assets
     * @param cEthAddress_ The address of cETH, which will return a constant 1e18, since all prices relative to ether
     * @param registry_ The address of ChainLink registry
     */
    constructor(
        address admin_,
        address v1PriceOracle_,
        address cEthAddress_,
        address registry_
    ) public {
        admin = admin_;
        cEthAddress = cEthAddress_;
        registry = FeedRegistryInterface(registry_);
    }

    /**
     * @notice Get the underlying price of a listed cToken asset
     * @param cToken The cToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18)
     */
    function getUnderlyingPrice(CToken cToken) public view override returns (uint256) {
        address cTokenAddress = address(cToken);
        if (cTokenAddress == cEthAddress) {
            // ether always worth 1
            return 1e18;
        } 

        address underlying = CErc20(cTokenAddress).underlying();

        return getTokenPrice(underlying);
    }

    /*** Internal fucntions ***/

    /**
     * @notice Get the price of a specific token. Return 1e18 is it's WETH.
     * @param token The token to get the price of
     * @return The price
     */
    function getTokenPrice(address token) internal view returns (uint256) {
        if (token == wethAddress) {
            // weth always worth 1
            return 1e18;
        }

        AggregatorInfo memory aggregatorInfo = aggregators[token];
        if (aggregatorInfo.isUsed) {
            uint256 price = getPriceFromChainlink(aggregatorInfo.base, aggregatorInfo.quote);
            if (aggregatorInfo.quote == Denominations.USD) {
                // Convert the price to ETH based if it's USD based.
                price = mul_(price, Exp({mantissa: getUsdcEthPrice()}));
            }
            uint256 underlyingDecimals = EIP20Interface(token).decimals();
            return mul_(price, 10**(18 - underlyingDecimals));
        }
        return getPriceFromDex(token);
    }

    /**
     * @notice Get price from ChainLink
     * @param base The base token that ChainLink aggregator gets the price of
     * @param quote The quote token, currenlty support ETH and USD
     * @return The price, scaled by 1e18
     */
    function getPriceFromChainlink(address base, address quote) internal view returns (uint256) {
        (, int256 price, , , ) = registry.latestRoundData(base, quote);
        require(price > 0, "invalid price");

        // Extend the decimals to 1e18.
        return mul_(uint256(price), 10**(18 - uint256(registry.decimals(base, quote))));
    }

    /**
     * @notice Get USDC price
     * @dev We treat USDC as USD for convenience
     * @return The USDC price
     */
    function getUsdcEthPrice() internal view returns (uint256) {
        return getTokenPrice(usdcAddress) / 1e12;
    }

    /**
     * @notice Get price from v1 price oracle
     * @param token The token to get the price of
     * @return The price
     */
    function getPriceFromDex(address token) internal view returns (uint256) {
        (uint tokenAmount, uint ethAmount) = NPSwap.getReserves(token, wethAddress);
        uint usdcPrice = getUsdcEthPrice();
        return ethAmount.div(usdcPrice).mul(tokenAmount);
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
    function _setAggregators(
        address[] calldata tokenAddresses,
        address[] calldata bases,
        address[] calldata quotes
    ) external {
        require(msg.sender == admin || msg.sender == guardian, "only the admin or guardian may set the aggregators");
        require(tokenAddresses.length == bases.length && tokenAddresses.length == quotes.length, "mismatched data");
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            bool isUsed;
            if (bases[i] != address(0)) {
                require(msg.sender == admin, "guardian may only clear the aggregator");
                require(quotes[i] == Denominations.ETH || quotes[i] == Denominations.USD, "unsupported denomination");
                isUsed = true;

                // Make sure the aggregator exists.
                address aggregator = registry.getFeed(bases[i], quotes[i]);
                require(registry.isFeedEnabled(aggregator), "aggregator not enabled");
            }
            aggregators[tokenAddresses[i]] = AggregatorInfo({base: bases[i], quote: quotes[i], isUsed: isUsed});
            emit AggregatorUpdated(tokenAddresses[i], bases[i], quotes[i], isUsed);
        }
    }

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
}
