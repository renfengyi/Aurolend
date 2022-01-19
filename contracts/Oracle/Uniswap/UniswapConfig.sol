// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

// interface CErc20 {
//     function underlying() external view returns (address);
// }

contract UniswapConfig {
    /// @dev Describe how to interpret the fixedPrice in the TokenConfig.
    enum PriceSource {
        FIXED_ETH, /// implies the fixedPrice is a constant multiple of the ETH price (which varies)
        FIXED_USD, /// implies the fixedPrice is a constant multiple of the USD price (which is 1)
        REPORTER   /// implies the price is set by the reporter
    }

    /// @dev Describe how the USD price should be determined for an asset.
    ///  There should be 1 TokenConfig object for each supported asset, passed in the constructor.
    struct TokenConfig {
        address cToken;
        address underlying;
        bytes32 symbolHash;
        uint256 baseUnit;
        address stableCoin; // change to stableCoin
        // uint256 fixedPrice;      // not used
        address uniswapMarket;   // pairAddress
        bool isUniswapReversed;  // USD - Token means reversed
    }

    /// @notice The max number of tokens this contract is hardcoded to support
    /// @dev Do not change this variable without updating all the fields throughout the contract.
    uint public constant maxTokens = 30;

    /// @notice The number of tokens this contract actually supports
    uint public numTokens;

    // todo: 1. 将token config改为映射，可添加; 2. onlyAdmin
    mapping(address => TokenConfig) public configForCToken;
    address[] internal cTokens;

    constructor() {}

    /**
     * @notice Get the config for the cToken
     * @dev If a config for the cToken is not found, falls back to searching for the underlying.
     * @param cToken The address of the cToken of the config to get
     * @return The config object
     */
    function getTokenConfigByCToken(address cToken) public view returns (TokenConfig memory) {
        require(configForCToken[cToken].baseUnit>0, "Invalid cToken");
        return configForCToken[cToken];
    }
}
