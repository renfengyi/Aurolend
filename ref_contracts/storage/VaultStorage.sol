// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/Authority.sol";

contract VaultStorage is Authority {
    struct VaultInfo {
        uint256     totalVault;
        uint256     ipWithdrawed;
        uint256     curVault;
        uint256     lastUpdateTime;
    }

    struct PoolInfo {
        VaultInfo   VT;
    }

    mapping(address => mapping(address => PoolInfo)) private pools;

    function setTotalVault(address _ipt, address _bst, uint256 amount) external onlyProxy {
        pools[_ipt][_bst].VT.totalVault = amount;
    }

    function setIPWithdrawed(address _ipt, address _bst, uint256 amount) external onlyProxy {
        pools[_ipt][_bst].VT.ipWithdrawed = amount;
    }

    function setCurVault(address _ipt, address _bst, uint256 amount) external onlyProxy {
        pools[_ipt][_bst].VT.curVault = amount;
    }

    function setLastUpdateTime(address _ipt, address _bst, uint256 time) external onlyProxy {
        pools[_ipt][_bst].VT.lastUpdateTime = time;
    }

    function getTotalVault(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].VT.totalVault;
    }

    function getIPWithdrawed(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].VT.ipWithdrawed;
    }

    function getCurVault(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].VT.curVault;
    }

    function getLastUpdateTime(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].VT.lastUpdateTime;
    }
}