pragma solidity ^0.8.0;

interface V1PriceOracleInterface {
    function assetPrices(address asset) external view returns (uint256);
}
