// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/Safety.sol";
import "../lib/Authority.sol";

contract LPStorage is Authority {
    using Safety for uint256;

    struct LPInfo {
        bool        valid;
        uint256     id; // index in LPA
        uint256     baseTokensAmount;
        uint256     runningDepositAmount;
        uint256     accVaultReward;
    }

    struct PoolInfo {
        uint256     curTotalLPAmount; // baseToken unit
        uint256     liquidationBaseAmount; // baseToken repay to LP
        uint256     liquidationIPAmount; // IPToken repay to LP

        address[]   LPA;
        mapping(address => LPInfo) LPM;
    }

    // For gas optimization
    uint256 constant NONZERO_INIT = 1;

    mapping(address => mapping(address => PoolInfo)) private pools;

    function setCurLPAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].curTotalLPAmount = _amount;
    }

    function setLiquidationBaseAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].liquidationBaseAmount = _amount;
    }

    function setLiquidationIPAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].liquidationIPAmount = _amount;
    }

    function divideVault(address _ipt, address _bst, uint256 _vault) external onlyProxy {
        uint256 len = pools[_ipt][_bst].LPA.length;
        uint256 LPAmount = pools[_ipt][_bst].curTotalLPAmount;
        uint256 resVault = _vault;

        for (uint256 i = 0; i < len; i++) {
            address lp = pools[_ipt][_bst].LPA[i];
            uint256 reward = pools[_ipt][_bst].LPM[lp].accVaultReward;
            uint256 amount = pools[_ipt][_bst].LPM[lp].baseTokensAmount;
            uint256 curVault = _vault.mul(amount).div(LPAmount);

            resVault -= curVault;
            curVault = i == len - 1 ? curVault.add(resVault) : curVault;
            pools[_ipt][_bst].LPM[lp].accVaultReward = reward.add(curVault);
        }
    }

    function setLPBaseAmount(address _ipt, address _bst, address _lp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].LPM[_lp].valid, "LP Not Exist");
        pools[_ipt][_bst].LPM[_lp].baseTokensAmount = _amount;
    }

    function setLPRunningDepositAmount(address _ipt, address _bst, address _lp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].LPM[_lp].valid, "LP Not Exist");
        pools[_ipt][_bst].LPM[_lp].runningDepositAmount = _amount;
    }

    function setLPVaultReward(address _ipt, address _bst, address _lp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].LPM[_lp].valid, "LP Not Exist");
        pools[_ipt][_bst].LPM[_lp].accVaultReward = NONZERO_INIT.add(_amount);
    }

    function insertLP(address _ipt, address _bst, address _lp, uint256 _amount, bool running) external onlyProxy {
        require(!pools[_ipt][_bst].LPM[_lp].valid, "LP Already Exist");
        pools[_ipt][_bst].LPA.push(_lp);

        pools[_ipt][_bst].LPM[_lp].valid = true;
        pools[_ipt][_bst].LPM[_lp].id = pools[_ipt][_bst].LPA.length;
        if (running) {
            pools[_ipt][_bst].LPM[_lp].baseTokensAmount = 0;
            pools[_ipt][_bst].LPM[_lp].runningDepositAmount = _amount;
        } else {
            pools[_ipt][_bst].LPM[_lp].baseTokensAmount = _amount;
            pools[_ipt][_bst].LPM[_lp].runningDepositAmount = 0;
        }
        
        pools[_ipt][_bst].LPM[_lp].accVaultReward = NONZERO_INIT;
    }

    function deleteLP(address _ipt, address _bst, address _lp) external onlyProxy {
        require(pools[_ipt][_bst].LPM[_lp].valid, "LP Not Exist");
        uint256 id = pools[_ipt][_bst].LPM[_lp].id;
        uint256 length = pools[_ipt][_bst].LPA.length;

        pools[_ipt][_bst].LPA[id - 1] = pools[_ipt][_bst].LPA[length - 1];
        pools[_ipt][_bst].LPM[pools[_ipt][_bst].LPA[length - 1]].id = id;
        pools[_ipt][_bst].LPA.pop();

        pools[_ipt][_bst].LPM[_lp].valid = false;
        pools[_ipt][_bst].LPM[_lp].id = 0;
        pools[_ipt][_bst].LPM[_lp].baseTokensAmount = 0;
        pools[_ipt][_bst].LPM[_lp].runningDepositAmount = 0;
        pools[_ipt][_bst].LPM[_lp].accVaultReward = 0;
    }

    function getCurLPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalLPAmount;
    }

    function getLiquidationBaseAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].liquidationBaseAmount;
    }

    function getLiquidationIPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].liquidationIPAmount;
    }

    function getLPBaseAmount(address _ipt, address _bst, address _lp) external view returns(uint256) {
        require(pools[_ipt][_bst].LPM[_lp].valid, "LP Not Exist");
        return pools[_ipt][_bst].LPM[_lp].baseTokensAmount;
    }

    function getLPRunningDepositAmount(address _ipt, address _bst, address _lp) external view returns(uint256) {
        require(pools[_ipt][_bst].LPM[_lp].valid, "LP Not Exist");
        return pools[_ipt][_bst].LPM[_lp].runningDepositAmount;
    }

    function getLPVaultReward(address _ipt, address _bst, address _lp) external view returns(uint256) {
        require(pools[_ipt][_bst].LPM[_lp].valid, "LP Not Exist");
        return pools[_ipt][_bst].LPM[_lp].accVaultReward.sub(NONZERO_INIT);
    }

    function getLPValid(address _ipt, address _bst, address _lp) external view returns(bool) {
        return pools[_ipt][_bst].LPM[_lp].valid;
    }

    function getLPArrayLength(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].LPA.length;
    }

    function getLPByIndex(address _ipt, address _bst, uint256 _id) external view returns(address) {
        require(_id < pools[_ipt][_bst].LPA.length, "Wrong ID");
        return pools[_ipt][_bst].LPA[_id];
    }

    function getLPAddresses(address _ipt, address _bst) external view returns(address[] memory){
        return pools[_ipt][_bst].LPA;
    }
}