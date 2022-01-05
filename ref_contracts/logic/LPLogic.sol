// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/Safety.sol";
import "../lib/NPSwap.sol";
import "./BaseLogic.sol";

contract LPLogic is BaseLogic {
    using Safety for uint256;
    using SafeERC20 for IERC20;

    uint256 constant MAX_LP_NUMBER = 1500;

    function LPDepositRaising(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RAISING);
        address _lp = msg.sender;
        uint256 oriLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);

        amount = _baseTokensAmount;
        IERC20(_baseToken).safeTransferFrom(_lp, address(this), amount);
        _LPS.setCurLPAmount(_ipToken, _baseToken, oriLPAmount.add(amount));
        if (_create) {
            _LPS.insertLP(_ipToken, _baseToken, _lp, amount, false);
        } else {
            uint256 oriAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
            _LPS.setLPBaseAmount(_ipToken, _baseToken, _lp, oriAmount.add(amount));
        }
        
        require(amount > 0, "Deposit Zero");
        require(_LPS.getLPArrayLength(_ipToken, _baseToken) <= MAX_LP_NUMBER, "Too Many LP");
        return amount;
    }

    function LPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _lp = msg.sender;

        amount = _baseTokensAmount;
        IERC20(_baseToken).safeTransferFrom(_lp, address(this), amount);
        if (_create) {
            _LPS.insertLP(_ipToken, _baseToken, _lp, amount, true);
        } else {
            uint256 oriAmount = _LPS.getLPRunningDepositAmount(_ipToken, _baseToken, _lp);
            require(oriAmount == 0, "Wait To Do");
            _LPS.setLPRunningDepositAmount(_ipToken, _baseToken, _lp, amount);
        }

        require(amount > 0, "Deposit Zero");
        require(_LPS.getLPArrayLength(_ipToken, _baseToken) <= MAX_LP_NUMBER, "Too Many LP");
        return amount;
    }

    function LPDoDepositRunning(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _lp = msg.sender;
        uint256 oriLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 oriAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        uint256 curRaiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 amount = _LPS.getLPRunningDepositAmount(_ipToken, _baseToken, _lp);

        require(amount > 0, "Already done");
        _LPS.setLPRunningDepositAmount(_ipToken, _baseToken, _lp, 0);
        _LPS.setCurLPAmount(_ipToken, _baseToken, oriLPAmount.add(amount));
        _LPS.setLPBaseAmount(_ipToken, _baseToken, _lp, oriAmount.add(amount));

        lendToGP(_ipToken, _baseToken, oriLPAmount.add(amount).sub(curRaiseLP));
    }

    function LPWithdrawRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _vaultOnly
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _lp = msg.sender;

        if (_vaultOnly) {
            amount = _LPS.getLPVaultReward(_ipToken, _baseToken, _lp);
            _LPS.setLPVaultReward(_ipToken, _baseToken, _lp, 0);
            IERC20(_baseToken).safeTransfer(_lp, amount);
            return amount;
        }

        // Withdraw all base token, ignore input amount
        uint256 runningDepositAmount = _LPS.getLPRunningDepositAmount(_ipToken, _baseToken, _lp);
        _baseTokensAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        amount = reclaimFromGP(_ipToken, _baseToken, _baseTokensAmount);
        amount = amount.add(_LPS.getLPVaultReward(_ipToken, _baseToken, _lp));
        amount = amount.sub(chargeFee(_ipToken, _baseToken, _lp)).add(runningDepositAmount);
        IERC20(_baseToken).safeTransfer(_lp, amount);
        _LPS.deleteLP(_ipToken, _baseToken, _lp);

        return amount;
    }

    function LPWithdrawLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
    {
        poolAtStage(_ipToken, _baseToken, Stages.LIQUIDATION);

        address _lp = msg.sender;
        uint256 totalIPAmount = _LPS.getLiquidationIPAmount(_ipToken, _baseToken);
        uint256 totalBaseAmount =  _LPS.getLiquidationBaseAmount(_ipToken, _baseToken);
        uint256 totalLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 LPAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        uint256 reward = _LPS.getLPVaultReward(_ipToken, _baseToken, _lp);
        uint256 runningDepositAmount = _LPS.getLPRunningDepositAmount(_ipToken, _baseToken, _lp);

        if (totalIPAmount > 0) {
            IERC20(_ipToken).safeTransfer(_lp, totalIPAmount.mul(LPAmount).div(totalLPAmount));
        }

        if (totalBaseAmount > 0) {
            reward = reward.add(totalBaseAmount.mul(LPAmount).div(totalLPAmount));
        }

        IERC20(_baseToken).safeTransfer(_lp, reward.add(runningDepositAmount));
        _LPS.deleteLP(_ipToken, _baseToken, _lp);
    }

    function lendToGP(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 lend)
    {
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 balance = IPAmount.mul(price).div(inUnit);

        if (raiseLP >= balance ||
            balance.mul(RATIO_FACTOR).div(balance.sub(raiseLP)) >=
            raiseRatio + RATIO_FACTOR) {
            lend = 0;
            return lend;
        }

        uint256 GPBalance = balance.sub(raiseLP);
        lend = GPBalance.mul(raiseRatio + RATIO_FACTOR).div(RATIO_FACTOR).sub(balance);
        lend = lend > _amount ? _amount : lend;

        uint256 swappedIP = safeSwap(_baseToken, _ipToken, lend);
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, raiseLP.add(lend));
        _GPS.setCurIPAmount(_ipToken, _baseToken, IPAmount.add(swappedIP));
        _GPS.allocateFunds(_ipToken, _baseToken);

        return lend;
    }

    function reclaimFromGP(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 amount)
    {
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 LPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 curRaiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 balance = IPAmount.mul(price).div(inUnit);
        uint256 expect;

        if (curRaiseLP >= balance ||
            balance.mul(RATIO_FACTOR).div(balance.sub(curRaiseLP)) >=
            raiseRatio + RATIO_FACTOR) {
            expect = curRaiseLP > _amount ? _amount : curRaiseLP;
        } else {
            expect = _amount > LPAmount.sub(curRaiseLP) ?
                     _amount.sub(LPAmount.sub(curRaiseLP)) : 0;
        }

        if (expect == 0) {
            amount = _amount;
            _LPS.setCurLPAmount(_ipToken, _baseToken, LPAmount.sub(_amount));
            return amount;
        }

        uint256 swappedIP = expect.mul(inUnit).div(price);
        uint256 real = safeSwap(_ipToken, _baseToken, swappedIP);
        _GPS.setCurIPAmount(_ipToken, _baseToken, IPAmount.sub(swappedIP));
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, curRaiseLP.sub(expect));
        _LPS.setCurLPAmount(_ipToken, _baseToken, LPAmount.sub(_amount));
        _GPS.allocateFunds(_ipToken, _baseToken);

        amount = real > expect ? _amount.add(real.sub(expect)) :
                   _amount.sub(expect.sub(real));
        return amount;
    }

    function chargeFee(
        address _ipToken,
        address _baseToken,
        address _lp
    )
        private
        returns (uint256 fee)
    {
        uint256 amount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        fee = amount.mul(1).div(100);
        IERC20(_baseToken).safeTransfer(DGTBeneficiary, fee);
        return fee;
    }
}