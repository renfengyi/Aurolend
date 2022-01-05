// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/Safety.sol";
import "../lib/NPSwap.sol";
import "./BaseLogic.sol";

contract LiquidationLogic is BaseLogic {
    using Safety for *;
    using SafeERC20 for IERC20;

    function checkIPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        require(!msg.sender.isContract(), "Not support contract");
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint32 closeLine = _IPS.getIPCloseLine(_ipToken, _baseToken);
        uint256 GPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 closeLineAmount = IPAmount.mul(price).mul(closeLine).div(inUnit).div(RATIO_FACTOR);
        uint256 curIPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);

        // Check the situation of IP liquidation
        if (closeLineAmount <= GPAmount) {
            // Check the situation of GP liquidation and the lowest swap boundary
            if (IPAmount.add(curIPAmount).mul(price).mul(RATIO_FACTOR).div(inUnit) <= raiseLP.mul(swapBoundaryRatio)) {
                doIPLiquidation(_ipToken, _baseToken, true);
            } else {
                doIPLiquidation(_ipToken, _baseToken, false);
            }
            return true;
        }

        return false;
    }

    function checkGPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        require(!msg.sender.isContract(), "Not support contract");
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint256 curIPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint32 closeLine = _IPS.getIPCloseLine(_ipToken, _baseToken);
        uint256 GPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);

        // Only do GP liquidation when IP did not reach the closeline
        if (IPAmount.mul(price).mul(closeLine).div(inUnit) <= GPAmount.mul(RATIO_FACTOR)) {
            return false;
        } else if (curIPAmount.mul(price).div(inUnit) < raiseLP) {
            doGPLiquidation(_ipToken, _baseToken);
            return true;
        }

        return false;
    }

    function checkRunningEnd(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        uint256 time = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);
        uint256 duration = _IPS.getIPDuration(_ipToken, _baseToken);

        if (block.timestamp < time.add(duration)) {
            return false;
        }

        runningEnd(_ipToken, _baseToken);
        return true;
    }

    function doIPLiquidation(
        address _ipToken,
        address _baseToken,
        bool _raiseLPLoss
    )
        private
    {
        uint256 IPStake = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 LPBase = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 belongLP = 0;
        uint256 belongGP = 0;

        IPAmount = IPAmount.add(IPStake);
        uint256 requireIP = NPSwap.getAmountIn(_ipToken, _baseToken, raiseLP);
        requireIP = requireIP > IPAmount ? IPAmount : requireIP;
        if (requireIP > 0 && !_raiseLPLoss) {
            belongLP = safeSwap(_ipToken, _baseToken, requireIP);
        }

        belongGP = IPAmount.sub(requireIP);
        belongLP = belongLP.add(LPBase.sub(raiseLP));
        divideVault(_ipToken, _baseToken);

        if (_raiseLPLoss) {
            belongLP = LPBase.sub(raiseLP);
            repayLP(_ipToken, _baseToken, IPAmount, false);
            repayLP(_ipToken, _baseToken, belongLP, true);
            repayGP(_ipToken, _baseToken, 0, false);
            repayIP(_ipToken, _baseToken, true);
        } else {
            repayLP(_ipToken, _baseToken, belongLP, true);
            repayGP(_ipToken, _baseToken, belongGP, false);
            repayIP(_ipToken, _baseToken, true);
        }

        poolTransitNextStage(_ipToken, _baseToken);
    }

    function doGPLiquidation(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 LPBase = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 belongLP = 0;

        if (IPAmount > 0) {
            belongLP= NPSwap.swap(_ipToken, _baseToken, IPAmount);
            belongLP= safeSwap(_ipToken, _baseToken, IPAmount);
        }

        belongLP = belongLP.add(LPBase.sub(raiseLP));
        divideVault(_ipToken, _baseToken);
        repayLP(_ipToken, _baseToken, belongLP, true);
        repayGP(_ipToken, _baseToken, 0, true);
        repayIP(_ipToken, _baseToken, false);

        poolTransitNextStage(_ipToken, _baseToken);
    }

    function runningEnd(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 LPBase = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 swappedBase = 0;
        uint256 belongLP = 0;
        uint256 belongGP = 0;

        if (IPAmount > 0 ) {
            swappedBase = safeSwap(_ipToken, _baseToken, IPAmount);
        }

        belongLP = swappedBase > raiseLP ? raiseLP : swappedBase;
        belongGP = swappedBase.sub(belongLP);
        belongGP = belongGP.sub(chargeGPFee(_ipToken, _baseToken, belongGP));
        belongLP = belongLP.add(LPBase.sub(raiseLP));
        belongLP = belongLP.sub(chargeLPFee(_ipToken, _baseToken));

        divideVault(_ipToken, _baseToken);
        repayLP(_ipToken, _baseToken, belongLP, true);
        repayGP(_ipToken, _baseToken, belongGP, true);
        repayIP(_ipToken, _baseToken, false);

        poolTransitNextStage(_ipToken, _baseToken);
    }

    function divideVault(
        address _ipToken,
        address _baseToken
    )
        private
    {
        _LPS.divideVault(_ipToken, _baseToken,
                         _VTS.getCurVault(_ipToken, _baseToken));
        _VTS.setCurVault(_ipToken, _baseToken, 0);
    }

    function repayLP(
        address _ipToken,
        address _baseToken,
        uint256 _amount,
        bool _base
    )
        private
    {
        if (_base) {
            _LPS.setLiquidationBaseAmount(_ipToken, _baseToken, _amount);
        } else {
            _LPS.setLiquidationIPAmount(_ipToken, _baseToken, _amount);
        }
    }

    function repayGP(
        address _ipToken,
        address _baseToken,
        uint256 _amount,
        bool _base
    )
        private
    {
        if (_base) {
            _GPS.setLiquidationBaseAmount(_ipToken, _baseToken, _amount);
        } else {
            _GPS.setLiquidationIPAmount(_ipToken, _baseToken, _amount);
        }
    }

    function repayIP(
        address _ipToken,
        address _baseToken,
        bool ipLiquidation
    )
        private
    {
        if (ipLiquidation) {
            return;
        }

        uint256 IPStake = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        address ip = _IPS.getIPAddress(_ipToken, _baseToken);
        IERC20(_ipToken).safeTransfer(ip, IPStake);
    }

    function chargeGPFee(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 fee)
    {
        uint256 GPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);
        uint256 earnedGP = _amount > GPAmount ? _amount.sub(GPAmount) : 0;

        if (earnedGP > 0) {
            fee = earnedGP.mul(20).div(100);
            IERC20(_baseToken).safeTransfer(DGTBeneficiary, fee);
            return fee;
        }

        return 0;
    }

    function chargeLPFee(
        address _ipToken,
        address _baseToken
    )
        private
        returns (uint256 fee)
    {
        uint256 LPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        fee = LPAmount.mul(1).div(100);
        IERC20(_baseToken).safeTransfer(DGTBeneficiary, fee);
        return fee;
    }
}