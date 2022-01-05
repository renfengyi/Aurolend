// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../storage/NPStorage.sol";
import "../lib/NPSwap.sol";
import "../lib/Safety.sol";

contract BaseLogic is NPStorage {
    using Safety for uint256;
    using SafeERC20 for IERC20;

    enum Stages {
        FINISHED,
        CREATING,
        AUCTING,
        RAISING,
        ALLOCATING,
        RUNNING,
        LIQUIDATION
    }

    modifier poolExist(
        address _ipToken,
        address _baseToken
    )
    {
        require(_IPS.getPoolValid(_ipToken, _baseToken),
                "NudgePool Not Exist");
        _;
    }

    modifier poolNotExist(
        address _ipToken,
        address _baseToken
    )
    {
        require(!_IPS.getPoolValid(_ipToken, _baseToken),
                "NudgePool Exist");
        _;
    }

    modifier lockPool(
        address _ipToken,
        address _baseToken
    )
    {
        require(_IPS.getPoolValid(_ipToken, _baseToken),
                "NudgePool Not Exist");
        require(!_IPS.getPoolLocked(_ipToken, _baseToken),
                "NudgePool Locked");
        _IPS.setPoolLocked(_ipToken, _baseToken, true);
        _;
        _IPS.setPoolLocked(_ipToken, _baseToken, false);
    }

    function poolAtStage(
        address _ipToken,
        address _baseToken,
        Stages _stage
    )
        internal view
    {
        uint8 stage = _IPS.getPoolStage(_ipToken, _baseToken);
        require(stage == uint8(_stage), "Stage Not Match");
    }

    function poolTransitNextStage(
        address _ipToken,
        address _baseToken
    )
        internal
    {
        uint8 stage = _IPS.getPoolStage(_ipToken, _baseToken);
        Stages next = Stages(stage + 1);
        uint8 nexStage = uint8(next);

        require(nexStage > stage, "Wrong Stage Transit");
        _IPS.setPoolStage(_ipToken, _baseToken, nexStage);
    }

    function safeSwap(
        address _inToken,
        address _outToken,
        uint256 inAmount
    )
        internal
        returns(uint256)
    {
        uint256 inUnit = 10**ERC20(_outToken).decimals();
        uint256 priceBefore = NPSwap.getAmountOut(_inToken, _outToken, inUnit);
        uint256 outAmount = NPSwap.swap(_inToken, _outToken, inAmount);
        uint256 priceAfter = NPSwap.getAmountOut(_inToken, _outToken, inUnit);
        require(priceAfter.mul(RATIO_FACTOR) >= priceBefore.mul(swapBoundaryRatio), "Lose too much");
        return outAmount;
    }
}
