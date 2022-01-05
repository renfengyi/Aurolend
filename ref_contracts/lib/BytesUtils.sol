// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library BytesUtils {

    function bytesToUint256(bytes memory data) internal pure returns (uint256 res) {
        require(data.length >= 32, "Data Too Short");
        assembly {
            res := mload(add(data, 32))
        }
    }

    function bytesToUint32(bytes memory data) internal pure returns (uint32 res) {
        assembly {
            res := mload(data)
        }
    }
    
    function bytesToBool(bytes memory data) internal pure returns (bool res) {
        assembly {
            res := mload(data)
        }
    }
}