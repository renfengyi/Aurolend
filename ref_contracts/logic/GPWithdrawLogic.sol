// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/Safety.sol";
import "./BaseLogic.sol";

contract GPWithdrawLogic is BaseLogic {
    using Safety for uint256;
    using SafeERC20 for IERC20;

    function GPWithdrawRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _gp = msg.sender;
        require(_GPS.getGPValid(_ipToken, _baseToken, _gp), "GP Not Exist");

        // Withdraw all base token, ignore input amount
        uint256 belongLP = _GPS.getGPRaiseLPAmount(_ipToken, _baseToken, _gp);
        uint256 IPAmount = _GPS.getGPHoldIPAmount(_ipToken, _baseToken, _gp);
        uint256 swappedBase = safeSwap(_ipToken, _baseToken, IPAmount);

        amount = swappedBase > belongLP ? swappedBase.sub(belongLP) : 0;
        uint256 GPBase = _GPS.getGPBaseAmount(_ipToken, _baseToken, _gp);
        uint256 earnedGP = amount > GPBase ? amount.sub(GPBase) : 0;

        if (earnedGP > 0) {
            IERC20(_baseToken).safeTransfer(DGTBeneficiary, earnedGP.mul(20).div(100));
            amount = amount.sub(earnedGP.mul(20).div(100));
        }

        amount = amount.add(_GPS.getGPRunningDepositAmount(_ipToken, _baseToken, _gp));
        if (amount > 0) {
            IERC20(_baseToken).safeTransfer(_gp, amount);
        }

        uint256 gpAmount = _GPS.getGPBaseAmount(_ipToken, _baseToken, _gp);
        uint256 poolAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);
        _GPS.setCurGPAmount(_ipToken, _baseToken, poolAmount.sub(gpAmount));

        gpAmount = _GPS.getGPBaseBalance(_ipToken, _baseToken, _gp);
        poolAmount = _GPS.getCurGPBalance(_ipToken, _baseToken);
        _GPS.setCurGPBalance(_ipToken, _baseToken, poolAmount.sub(gpAmount));

        gpAmount = _GPS.getGPHoldIPAmount(_ipToken, _baseToken, _gp);
        poolAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        _GPS.setCurIPAmount(_ipToken, _baseToken, poolAmount.sub(gpAmount));

        gpAmount = _GPS.getGPRaiseLPAmount(_ipToken, _baseToken, _gp);
        poolAmount = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, poolAmount.sub(gpAmount));

        _GPS.deleteGP(_ipToken, _baseToken, _gp);
        return amount;
    }

    function GPWithdrawLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
    {
        poolAtStage(_ipToken, _baseToken, Stages.LIQUIDATION);

        address _gp = msg.sender;
        uint256 totalIPAmount = _GPS.getLiquidationIPAmount(_ipToken, _baseToken);
        uint256 totalBaseAmount =  _GPS.getLiquidationBaseAmount(_ipToken, _baseToken);
        uint256 totalBalance = _GPS.getCurGPBalance(_ipToken, _baseToken);
        uint256 balance = _GPS.getGPBaseBalance(_ipToken, _baseToken, _gp);
        uint256 runningDepositAmount = _GPS.getGPRunningDepositAmount(_ipToken, _baseToken, _gp);
        totalBaseAmount = totalBaseAmount.mul(balance).div(totalBalance).add(runningDepositAmount);

        if (totalIPAmount > 0) {
            IERC20(_ipToken).safeTransfer(_gp, totalIPAmount.mul(balance).div(totalBalance));
        }

        if (totalBaseAmount > 0) {
            IERC20(_baseToken).safeTransfer(_gp, totalBaseAmount);
        }

        _GPS.deleteGP(_ipToken, _baseToken, _gp);
    }
}
