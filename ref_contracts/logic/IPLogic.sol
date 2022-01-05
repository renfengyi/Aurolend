// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/Safety.sol";
import "../lib/NPSwap.sol";
import "./BaseLogic.sol";

contract IPLogic is BaseLogic {
    using Safety for *;
    using SafeERC20 for IERC20;

    function createPool(
        address _ip,
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount,
        uint256 _dgtTokensAmount,
        uint32 _ipImpawnRatio,
        uint32 _ipCloseLine,
        uint32 _chargeRatio,
        uint256 _duration
    )
        external
        poolNotExist(_ipToken, _baseToken)
    {
        require(NPSwap.pairFor(_ipToken, _baseToken).isContract(), "No liquidity");
        qualifiedIP(_ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount, true);
        checkIPParams(_ipImpawnRatio, _ipCloseLine, _chargeRatio, _duration);

        IERC20(_ipToken).safeTransferFrom(_ip, address(this), _ipTokensAmount);
        IERC20(DGTToken).safeTransferFrom(_ip, address(this), _dgtTokensAmount);

        _IPS.insertPool(_ipToken, _baseToken);
        _IPS.setPoolStage(_ipToken, _baseToken, uint8(Stages.CREATING));
        _IPS.setPoolAuctionEndTime(_ipToken, _baseToken, block.timestamp.add(auctionDuration));

        _IPS.setIPAddress(_ipToken, _baseToken, _ip);
        _IPS.setIPTokensAmount(_ipToken, _baseToken, _ipTokensAmount);
        _IPS.setDGTTokensAmount(_ipToken, _baseToken, _dgtTokensAmount);
        _IPS.setIPImpawnRatio(_ipToken, _baseToken, _ipImpawnRatio);
        _IPS.setIPCloseLine(_ipToken, _baseToken, _ipCloseLine);
        _IPS.setIPChargeRatio(_ipToken, _baseToken, _chargeRatio);
        _IPS.setIPDuration(_ipToken, _baseToken, _duration);

        poolTransitNextStage(_ipToken, _baseToken);
    }

    function auctionPool(
        address _ip,
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount,
        uint256 _dgtTokensAmount
    )
        external
        lockPool(_ipToken, _baseToken)
    {
        poolAtStage(_ipToken, _baseToken, Stages.AUCTING);
        qualifiedIP(_ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount, false);
        require(block.timestamp < _IPS.getPoolAuctionEndTime(_ipToken, _baseToken), "Auction End");

        IERC20(_ipToken).safeTransferFrom(_ip, address(this), _ipTokensAmount);
        IERC20(DGTToken).safeTransferFrom(_ip, address(this), _dgtTokensAmount);
        address oriIP = _IPS.getIPAddress(_ipToken, _baseToken);
        IERC20(_ipToken).safeTransfer(oriIP, _IPS.getIPTokensAmount(_ipToken, _baseToken));
        IERC20(DGTToken).safeTransfer(oriIP, _IPS.getDGTTokensAmount(_ipToken, _baseToken));

        _IPS.setIPAddress(_ipToken, _baseToken, _ip);
        _IPS.setIPTokensAmount(_ipToken, _baseToken, _ipTokensAmount);
        _IPS.setDGTTokensAmount(_ipToken, _baseToken, _dgtTokensAmount);
        
        if (auctionDuration > 30 minutes &&
            block.timestamp > _IPS.getPoolAuctionEndTime(_ipToken, _baseToken).sub(30 minutes)) {
            _IPS.setPoolAuctionEndTime(_ipToken, _baseToken, block.timestamp.add(30 minutes));
        }
    }

    function changePoolParam(
        address _ipToken,
        address _baseToken,
        uint32 _ipImpawnRatio,
        uint32 _ipCloseLine,
        uint32 _chargeRatio,
        uint256 _duration
    )
        external
        lockPool(_ipToken, _baseToken)
    {
        address ip = _IPS.getIPAddress(_ipToken, _baseToken);
        require(msg.sender == ip, "Not Permit");
        poolAtStage(_ipToken, _baseToken, Stages.AUCTING);

        checkIPParams(_ipImpawnRatio, _ipCloseLine, _chargeRatio, _duration);
        _IPS.setIPImpawnRatio(_ipToken, _baseToken, _ipImpawnRatio);
        _IPS.setIPCloseLine(_ipToken, _baseToken, _ipCloseLine);
        _IPS.setIPChargeRatio(_ipToken, _baseToken, _chargeRatio);
        _IPS.setIPDuration(_ipToken, _baseToken, _duration);
    }

    function IPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        address ip = _IPS.getIPAddress(_ipToken, _baseToken);
        require(ip == msg.sender, "Not Permit");

        amount = _ipTokensAmount;
        IERC20(_ipToken).safeTransferFrom(ip, address(this), amount);
        uint256 curAmount = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        _IPS.setIPTokensAmount(_ipToken, _baseToken, curAmount.add(amount));

        return amount;
    }

    function destroyPool(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
    {
        poolAtStage(_ipToken, _baseToken, Stages.LIQUIDATION);

        clearGP(_ipToken, _baseToken);
        clearLP(_ipToken, _baseToken);
        clearVault(_ipToken, _baseToken);
        clearIP(_ipToken, _baseToken);
    }

    function qualifiedIP(
        address ip,
        address ipToken,
        address baseToken,
        uint256 ipTokensAmount,
        uint256 dgtTokensAmount,
        bool create
    )
        internal view
    {
        /* There are several conditions need to be filled as a qualified IP:
         * 1. IP should own and impawn at least minRatio percent of total supply of this token
         * 2. If the pool is in auction, new bid price should be 1.05 more than current bid price
         */
        require(ipTokensAmount <= IERC20(ipToken).balanceOf(ip) &&
                ipTokensAmount >= IERC20(ipToken).totalSupply().mul(minRatio).div(RATIO_FACTOR),
                "Token Not Enough");

        if (!create) {
            require(dgtTokensAmount > 0 && dgtTokensAmount >= 
                    _IPS.getDGTTokensAmount(ipToken, baseToken).mul(105).div(100),
                    "Bid Price Should Increase 5%");
        }
    }

    function checkIPParams(
        uint32 _ipImpawnRatio, //(0,100%]
        uint32 _ipCloseLine, // (_ipImpawnRatio,300%]
        uint32 _chargeRatio, // (0, 100%)
        uint256 _duration
    )
        internal view
    {
        /* IP Params should meet following condition:
         * 1. ipImpawnRatio should be larger than 0 and no larger than 100%
         * 2. ipCloseLine should be larger than ipImpawnRatio and no no larger than 300%
         * 3. chargeRatio should be smaller than 100%
         * 4. duration should no smaller than minimumDuration
         */
        require(RATIO_FACTOR >= _ipImpawnRatio && _ipImpawnRatio > 0,
                "invalid impawnRatio");
        require(RATIO_FACTOR.mul(3) >= _ipCloseLine && _ipCloseLine > _ipImpawnRatio,
                "invalid closeLine");
        require(RATIO_FACTOR > _chargeRatio && _chargeRatio > 0,
                "invalid chargeRatio");
        require(_duration >= minimumDuration, "invalid duration");
    }

    function clearGP(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 len = _GPS.getGPArrayLength(_ipToken, _baseToken);
        uint256 totalIPAmount = _GPS.getLiquidationIPAmount(_ipToken, _baseToken);
        uint256 totalBaseAmount =  _GPS.getLiquidationBaseAmount(_ipToken, _baseToken);
        uint256 totalBalance = _GPS.getCurGPBalance(_ipToken, _baseToken);

        for (uint256 i = len; i > 0; i--) {
            address gp = _GPS.getGPByIndex(_ipToken, _baseToken, i - 1);
            uint256 balance = _GPS.getGPBaseBalance(_ipToken, _baseToken, gp);

            if (totalIPAmount > 0) {
                IERC20(_ipToken).safeTransfer(gp, totalIPAmount.mul(balance).div(totalBalance));
            }

            if (totalBaseAmount > 0) {
                IERC20(_baseToken).safeTransfer(gp, totalBaseAmount.mul(balance).div(totalBalance));
            }

            _GPS.deleteGP(_ipToken, _baseToken, gp);
        }

        // Reset Pool GP Info
        _GPS.setCurGPAmount(_ipToken, _baseToken, 0);
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, 0);
        _GPS.setCurIPAmount(_ipToken, _baseToken, 0);
        _GPS.setCurGPBalance(_ipToken, _baseToken, 0);
        _GPS.setLiquidationIPAmount(_ipToken, _baseToken, 0);
        _GPS.setLiquidationBaseAmount(_ipToken, _baseToken, 0);
    }

    function clearLP(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 len = _LPS.getLPArrayLength(_ipToken, _baseToken);
        uint256 totalIPAmount = _LPS.getLiquidationIPAmount(_ipToken, _baseToken);
        uint256 totalBaseAmount =  _LPS.getLiquidationBaseAmount(_ipToken, _baseToken);
        uint256 totalLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);

        for (uint256 i = len; i > 0; i--) {
            address lp = _LPS.getLPByIndex(_ipToken, _baseToken, i - 1);
            uint256 LPAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, lp);
            uint256 reward = _LPS.getLPVaultReward(_ipToken, _baseToken, lp);

            if (totalIPAmount > 0) {
                IERC20(_ipToken).safeTransfer(lp, totalIPAmount.mul(LPAmount).div(totalLPAmount));
            }

            if (totalBaseAmount > 0) {
                reward = reward.add(totalBaseAmount.mul(LPAmount).div(totalLPAmount));
            }

            IERC20(_baseToken).safeTransfer(lp, reward);
            _LPS.deleteLP(_ipToken, _baseToken, lp);
        }

        // Reset Pool LP Info
        _LPS.setCurLPAmount(_ipToken, _baseToken, 0);
        _LPS.setLiquidationIPAmount(_ipToken, _baseToken, 0);
        _LPS.setLiquidationBaseAmount(_ipToken, _baseToken, 0);
    }

    function clearVault(
        address _ipToken,
        address _baseToken
    )
        private
    {
        // Reset Pool Vault Info
        _VTS.setTotalVault(_ipToken, _baseToken, 0);
        _VTS.setIPWithdrawed(_ipToken, _baseToken, 0);
        _VTS.setCurVault(_ipToken, _baseToken, 0);
        _VTS.setLastUpdateTime(_ipToken, _baseToken, 0);
    }

    function clearIP(
        address _ipToken,
        address _baseToken
    )
        private
    {
        // Reset Pool Info
        _IPS.setPoolStage(_ipToken, _baseToken, uint8(Stages.FINISHED));
        _IPS.deletePool(_ipToken, _baseToken);
    }
}