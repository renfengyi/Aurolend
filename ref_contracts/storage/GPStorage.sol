// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/Safety.sol";
import "../lib/Authority.sol";

contract GPStorage is Authority {
    using Safety for uint256;

    // For gas optimization
    uint256 constant NONZERO_INIT = 1;

    struct GPInfo {
        bool        valid;
        uint256     id; // index in GPA
        uint256     baseTokensAmount; // baseToken unit
        uint256     baseTokensBalance; // ipTokensAmount * price - raisedFromLPAmount
        uint256     runningDepositAmount;
        uint256     ipTokensAmount; // ipToken unit, include GP and LP
        uint256     raisedFromLPAmount; // baseToken unit
        uint256     overRaisedAmount;    //baseToken repay to GP after raising end
    }

    struct PoolInfo {
        uint256     curTotalGPAmount; // baseToken unit
        uint256     curTotalBalance; // baseToken unit
        uint256     curTotalLPAmount; // baseToken unit
        uint256     curTotalIPAmount; // baseToken swapped into ipToken amount
        uint256     liquidationBaseAmount; // baseToken repay to GP
        uint256     liquidationIPAmount; // IPToken repay to GP

        address[]   GPA;
        mapping(address => GPInfo) GPM;
    }

    mapping(address => mapping(address => PoolInfo)) private pools;

    function setCurGPAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].curTotalGPAmount = _amount;
    }

    function setCurRaiseLPAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].curTotalLPAmount = _amount;
    }

    function setCurIPAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].curTotalIPAmount = _amount;
    }

    function setCurGPBalance(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].curTotalBalance = _amount;
    }

    function setLiquidationBaseAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].liquidationBaseAmount = _amount;
    }

    function setLiquidationIPAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].liquidationIPAmount = _amount;
    }

    function setGPBaseAmount(address _ipt, address _bst, address _gp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].baseTokensAmount = _amount;
    }

    function setGPRunningDepositAmount(address _ipt, address _bst, address _gp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].runningDepositAmount = _amount;
    }

    function setGPHoldIPAmount(address _ipt, address _bst, address _gp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].ipTokensAmount = _amount;
    }

    function setGPRaiseLPAmount(address _ipt, address _bst, address _gp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount = _amount;
    }

    function setGPBaseBalance(address _ipt, address _bst, address _gp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = _amount;
    }

    function setGPAmount(address _ipt, address _bst, address _gp, uint256 _baseAmount, uint256 _baseBalance, uint256 _overRaisedAmount) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].baseTokensAmount = _baseAmount;
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = _baseBalance;
        pools[_ipt][_bst].GPM[_gp].overRaisedAmount = NONZERO_INIT.add(_overRaisedAmount);
    }

    function setOverRaisedAmount(address _ipt, address _bst, address _gp, uint256 _amount) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].overRaisedAmount = _amount;
    }

    function insertGP(address _ipt, address _bst, address _gp, uint256 _amount, bool running) external onlyProxy {
        require(!pools[_ipt][_bst].GPM[_gp].valid, "GP Already Exist");
        pools[_ipt][_bst].GPA.push(_gp);

        pools[_ipt][_bst].GPM[_gp].valid = true;
        pools[_ipt][_bst].GPM[_gp].id = pools[_ipt][_bst].GPA.length;
        if (running) {
            pools[_ipt][_bst].GPM[_gp].baseTokensAmount = 0;
            pools[_ipt][_bst].GPM[_gp].runningDepositAmount = _amount;
        } else {
            pools[_ipt][_bst].GPM[_gp].baseTokensAmount = _amount;
            pools[_ipt][_bst].GPM[_gp].runningDepositAmount = 0;
        }

        pools[_ipt][_bst].GPM[_gp].ipTokensAmount = NONZERO_INIT;
        pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount = NONZERO_INIT;
        pools[_ipt][_bst].GPM[_gp].overRaisedAmount = NONZERO_INIT;
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = 0;
    }

    function deleteGP(address _ipt, address _bst, address _gp) external onlyProxy {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        uint256 id = pools[_ipt][_bst].GPM[_gp].id;
        uint256 length = pools[_ipt][_bst].GPA.length;

        pools[_ipt][_bst].GPA[id - 1] = pools[_ipt][_bst].GPA[length - 1];
        pools[_ipt][_bst].GPM[pools[_ipt][_bst].GPA[length - 1]].id = id;
        pools[_ipt][_bst].GPA.pop();

        pools[_ipt][_bst].GPM[_gp].valid = false;
        pools[_ipt][_bst].GPM[_gp].id = 0;
        pools[_ipt][_bst].GPM[_gp].baseTokensAmount = 0;
        pools[_ipt][_bst].GPM[_gp].runningDepositAmount = 0;
        pools[_ipt][_bst].GPM[_gp].ipTokensAmount = 0;
        pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount = 0;
        pools[_ipt][_bst].GPM[_gp].overRaisedAmount = 0;
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = 0;
    }

    function getCurGPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalGPAmount;
    }

    function getCurRaiseLPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalLPAmount;
    }

    function getCurIPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalIPAmount;
    }

    function getCurGPBalance(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalBalance;
    }

    function getLiquidationBaseAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].liquidationBaseAmount;
    }

    function getLiquidationIPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].liquidationIPAmount;
    }

    function getGPBaseAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].baseTokensAmount;
    }

    function getGPRunningDepositAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].runningDepositAmount;
    }

    function getGPHoldIPAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].ipTokensAmount;
    }

    function getGPRaiseLPAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount;
    }

    function getGPBaseBalance(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].baseTokensBalance;
    }

    function getOverRaisedAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid, "GP Not Exist");
        if (pools[_ipt][_bst].GPM[_gp].overRaisedAmount == 0) {
            return 0;
        } else {
            return pools[_ipt][_bst].GPM[_gp].overRaisedAmount.sub(NONZERO_INIT);
        }
    }

    function getGPValid(address _ipt, address _bst, address _gp) external view returns(bool) {
        return pools[_ipt][_bst].GPM[_gp].valid;
    }

    function getGPArrayLength(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].GPA.length;
    }

    function getGPByIndex(address _ipt, address _bst, uint256 _id) external view returns(address) {
        require(_id < pools[_ipt][_bst].GPA.length, "Wrong ID");
        return pools[_ipt][_bst].GPA[_id];
    }

    function getGPAddresses(address _ipt, address _bst) external view returns(address[] memory) {
        return pools[_ipt][_bst].GPA;
    }

    function allocateFunds(address _ipt, address _bst) external onlyProxy {
        uint256 len = pools[_ipt][_bst].GPA.length;
        uint256 balance = pools[_ipt][_bst].curTotalBalance;
        uint256 IPAmount = pools[_ipt][_bst].curTotalIPAmount;
        uint256 raiseLP = pools[_ipt][_bst].curTotalLPAmount;
        uint256 resIPAmount = IPAmount;
        uint256 resRaiseLP = raiseLP;

        for (uint256 i = 0; i < len; i++) {
            address gp = pools[_ipt][_bst].GPA[i];
            uint256 gpBalance = pools[_ipt][_bst].GPM[gp].baseTokensBalance;

            uint256 curIPAmount = gpBalance.mul(IPAmount).div(balance);
            resIPAmount -= curIPAmount;
            curIPAmount = i == len - 1 ? curIPAmount.add(resIPAmount) : curIPAmount;

            uint256 curRaiseAmount = gpBalance.mul(raiseLP).div(balance);
            resRaiseLP -= curRaiseAmount;
            curRaiseAmount = i == len - 1 ? curRaiseAmount.add(resRaiseLP) : curRaiseAmount;

            pools[_ipt][_bst].GPM[gp].ipTokensAmount = curIPAmount;
            pools[_ipt][_bst].GPM[gp].raisedFromLPAmount = curRaiseAmount;
        }
    }
}
