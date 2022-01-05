// SPDX-License-Identifier: MIT
import "../lib/Authority.sol";

pragma solidity ^0.8.0;

contract IPStorage is Authority {
    struct IPParam {
        uint32      ipImpawnRatio;
        uint32      ipCloseLine;
        uint32      chargeRatio;
        uint256     duration;
    }

    struct IPInfo {
        address     ip;
        uint256     ipTokensAmount;
        uint256     dgtTokensAmount;
        IPParam     param;
    }

    struct PoolInfo {
        bool        valid;
        bool        locked;
        uint8       stage;

        uint256     id; // index in poolsArray
        uint256     createdTime;
        uint256     auctionEndTime;
        
        uint256     initPrice;
        uint256     initIPCanRaiseAmount;
        uint256     maxIPCanRaiseAmount; // baseToken unit
        IPInfo      IP;
    }

    struct Pool {
        address     ipToken;
        address     baseToken;
    }

    mapping(address => mapping(address => PoolInfo)) private pools;
    Pool[]  private poolsArray;

    function insertPool(address _ipt, address _bst) external onlyProxy {
        require(!pools[_ipt][_bst].valid, "Pool Already Exist");

        poolsArray.push(Pool(_ipt, _bst));
        pools[_ipt][_bst].valid = true;
        pools[_ipt][_bst].locked = false;
        pools[_ipt][_bst].id = poolsArray.length;
        pools[_ipt][_bst].createdTime = block.timestamp;
    }

    function deletePool(address _ipt, address _bst) external onlyProxy {
        require(pools[_ipt][_bst].valid, "Pool Not Exist");
        uint256 id = pools[_ipt][_bst].id;
        uint256 length = poolsArray.length;

        poolsArray[id - 1] = poolsArray[length - 1];
        pools[poolsArray[length - 1].ipToken][poolsArray[length - 1].baseToken].id = id;
        poolsArray.pop();

        pools[_ipt][_bst].valid = false;
        pools[_ipt][_bst].locked = false;
        pools[_ipt][_bst].id = 0;
        pools[_ipt][_bst].createdTime = 0;

        pools[_ipt][_bst].auctionEndTime = 0;
        pools[_ipt][_bst].initPrice = 0;
        pools[_ipt][_bst].initIPCanRaiseAmount = 0;
        pools[_ipt][_bst].maxIPCanRaiseAmount = 0;

        pools[_ipt][_bst].IP.ip = address(0);
        pools[_ipt][_bst].IP.ipTokensAmount = 0;
        pools[_ipt][_bst].IP.dgtTokensAmount = 0;

        pools[_ipt][_bst].IP.param.ipImpawnRatio = 0;
        pools[_ipt][_bst].IP.param.ipCloseLine = 0;
        pools[_ipt][_bst].IP.param.chargeRatio = 0;
        pools[_ipt][_bst].IP.param.duration = 0;
    }

    function setPoolValid(address _ipt, address _bst, bool _valid) external onlyProxy {
        pools[_ipt][_bst].valid = _valid;
    }

    function setPoolLocked(address _ipt, address _bst, bool _locked) external onlyProxy {
        pools[_ipt][_bst].locked = _locked;
    }

    function setPoolStage(address _ipt, address _bst, uint8 _stage) external onlyProxy {
        pools[_ipt][_bst].stage = _stage;
    }

    function setPoolCreateTime(address _ipt, address _bst, uint256 _time) external onlyProxy {
        pools[_ipt][_bst].createdTime = _time;
    }

    function setPoolAuctionEndTime(address _ipt, address _bst, uint256 _time) external onlyProxy {
        pools[_ipt][_bst].auctionEndTime = _time;
    }

    function setPoolInitPrice(address _ipt, address _bst, uint256 _price) external onlyProxy {
        pools[_ipt][_bst].initPrice = _price;
    }

    function setIPInitCanRaise(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].initIPCanRaiseAmount = _amount;
    }

    function setIPMaxCanRaise(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].maxIPCanRaiseAmount = _amount;
    }

    function setIPAddress(address _ipt, address _bst, address _ip) external onlyProxy {
        pools[_ipt][_bst].IP.ip = _ip;
    }

    function setIPTokensAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].IP.ipTokensAmount = _amount;
    }

    function setDGTTokensAmount(address _ipt, address _bst, uint256 _amount) external onlyProxy {
        pools[_ipt][_bst].IP.dgtTokensAmount = _amount;
    }

    function setIPImpawnRatio(address _ipt, address _bst, uint32 _ratio) external onlyProxy {
        pools[_ipt][_bst].IP.param.ipImpawnRatio = _ratio;
    }

    function setIPCloseLine(address _ipt, address _bst, uint32 _ratio) external onlyProxy {
        pools[_ipt][_bst].IP.param.ipCloseLine = _ratio;
    }

    function setIPChargeRatio(address _ipt, address _bst, uint32 _ratio) external onlyProxy {
        pools[_ipt][_bst].IP.param.chargeRatio = _ratio;
    }

    function setIPDuration(address _ipt, address _bst, uint256 _duration) external onlyProxy {
        pools[_ipt][_bst].IP.param.duration = _duration;
    }

    function getPoolValid(address _ipt, address _bst) external view returns(bool) {
        return pools[_ipt][_bst].valid;
    }

    function getPoolLocked(address _ipt, address _bst) external view returns(bool) {
        return pools[_ipt][_bst].locked;
    }

    function getPoolStage(address _ipt, address _bst) external view returns(uint8) {
        return pools[_ipt][_bst].stage;
    }

    function getPoolCreateTime(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].createdTime;
    }

    function getPoolAuctionEndTime(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].auctionEndTime;
    }

    function getPoolInitPrice(address _ipt, address _bst) external view returns(uint256){
        return pools[_ipt][_bst].initPrice;
    }

    function getIPInitCanRaise(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].initIPCanRaiseAmount;
    }

    function getIPMaxCanRaise(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].maxIPCanRaiseAmount;
    }

    function getIPAddress(address _ipt, address _bst) external view returns(address) {
        return pools[_ipt][_bst].IP.ip;
    }

    function getIPTokensAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].IP.ipTokensAmount;
    }

    function getDGTTokensAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].IP.dgtTokensAmount;
    }

    function getIPImpawnRatio(address _ipt, address _bst) external view returns(uint32) {
        return pools[_ipt][_bst].IP.param.ipImpawnRatio;
    }

    function getIPCloseLine(address _ipt, address _bst) external view returns(uint32) {
        return pools[_ipt][_bst].IP.param.ipCloseLine;
    }

    function getIPChargeRatio(address _ipt, address _bst) external view returns(uint32) {
        return pools[_ipt][_bst].IP.param.chargeRatio;
    }

    function getIPDuration(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].IP.param.duration;
    }

    function getPoolsArray() external view returns (address[] memory, address[] memory) {
        uint256 length = poolsArray.length;
        address[] memory iptArr = new address[](length);
        address[] memory bstArr = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            iptArr[i] = poolsArray[i].ipToken;
            bstArr[i] = poolsArray[i].baseToken;
        }

        return (iptArr, bstArr);
    }
}
