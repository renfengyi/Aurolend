// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/Safety.sol";
import "./lib/NPSwap.sol";
import "./storage/IPStorage.sol";
import "./storage/GPStorage.sol";
import "./storage/VaultStorage.sol";
import "./storage/LPStorage.sol";
import "./NudgePool.sol";

contract NudgePoolStatus {
    using Safety for uint256;

    // Keep consistent with Stages in BaseLogic.sol
    enum Stages {
        FINISHED,
        CREATING,
        AUCTING,
        RAISING,
        ALLOCATING,
        RUNNING,
        LIQUIDATION
    }

    enum Keys {
        PoolStage,
        CreateTime,
        AuctionEndTime,
        IPImpawnAmount,
        IPBidDGTAmount,
        IPImpawnRatio,
        IPCloseLine,
        IPChargeRatio,
        PoolDuration,
        GPVolume,
        GPAmount,
        GPBalance,
        SwapIPAmount,
        RaiseLPAmount,
        LPAmount,
        CurVault,
        IPAvailVault,
        IPWithdrawedVault,
        MAXELEMENTS
    }

    IPStorage public _IPS;
    GPStorage public _GPS;
    LPStorage public _LPS;
    VaultStorage public _VTS;
    NudgePool public _NP;

    constructor(
        address _ips,
        address _gps,
        address _lps,
        address _vts,
        address _np
    )
    {
        _IPS = IPStorage(_ips);
        _GPS = GPStorage(_gps);
        _LPS = LPStorage(_lps);
        _VTS = VaultStorage(_vts);
        _NP = NudgePool(_np);
    }

    function getAllPools()
        external view
        returns (address[] memory, address[] memory)
    {
        return _IPS.getPoolsArray();
    }

    function getPoolStage(
        address _ipToken,
        address _baseToken
    )
        external view
        returns(uint8)
    {
        return _IPS.getPoolStage(_ipToken, _baseToken);
    }

    function getPoolCreateTime(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getPoolCreateTime(_ipToken, _baseToken);
    }

    function getPoolAuctionEndTime(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);
    }

    function getIPAddress(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (address)
    {
        return _IPS.getIPAddress(_ipToken, _baseToken);
    }

    function getIPTokensAmount(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getIPTokensAmount(_ipToken, _baseToken);
    }

    function getIPImpawnRatio(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getIPImpawnRatio(_ipToken, _baseToken);
    }

    function getIPCloseLine(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getIPCloseLine(_ipToken, _baseToken);
    }

    function getIPChargeRatio(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getIPChargeRatio(_ipToken, _baseToken);
    }

    function getIPDuration(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getIPDuration(_ipToken, _baseToken);
    }

    function getIPDGTAmount(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getDGTTokensAmount(_ipToken, _baseToken);
    }

    function getMaxGPVolume(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _IPS.getIPMaxCanRaise(_ipToken, _baseToken);
    }

    function getCurGPAmount(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _GPS.getCurGPAmount(_ipToken, _baseToken);
    }

    function getCurIPAmount(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _GPS.getCurIPAmount(_ipToken, _baseToken);
    }

    function getCurRaiseLPAmount(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
    }

    function getCurGPBalance(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _GPS.getCurGPBalance(_ipToken, _baseToken);
    }

    function getGPBaseAmount(
        address _ipToken,
        address _baseToken,
        address _gp
    )
        external view
        returns (uint256)
    {
        return _GPS.getGPBaseAmount(_ipToken, _baseToken, _gp);
    }

    function getGPBaseBalance(
        address _ipToken,
        address _baseToken,
        address _gp
    )
        external view
        returns (uint256)
    {
        return _GPS.getGPBaseBalance(_ipToken, _baseToken, _gp);
    }

    function getOverRaisedAmount(
        address _ipToken,
        address _baseToken,
        address _gp
    )
        external view
        returns (uint256)
    {
        return _GPS.getOverRaisedAmount(_ipToken, _baseToken, _gp);
    }

    function getGPHoldIPAmount(
        address _ipToken,
        address _baseToken,
        address _gp
    )
        external view
        returns (uint256)
    {
        return _GPS.getGPHoldIPAmount(_ipToken, _baseToken, _gp);
    }

    function getGPAddresses(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (address[] memory)
    {
        return _GPS.getGPAddresses(_ipToken, _baseToken);
    }

    function getCurLPAmount(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _LPS.getCurLPAmount(_ipToken, _baseToken);
    }

    function getLPBaseAmount(
        address _ipToken,
        address _baseToken,
        address _lp
    )
        external view
        returns (uint256)
    {
        return _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
    }

    function getLPReward(
        address _ipToken,
        address _baseToken,
        address _lp
    ) 
        external view
        returns (uint256)
    {
        return _LPS.getLPVaultReward(_ipToken, _baseToken, _lp);
    }

    function getLPAddresses(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (address[] memory)
    {
        return _LPS.getLPAddresses(_ipToken, _baseToken);
    }

    function getIPWithdrawed(
        address _ipToken,
        address _baseToken
    ) 
        external view
        returns (uint256)
    {
        return _VTS.getIPWithdrawed(_ipToken, _baseToken);
    }

    function getCurVault(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (uint256)
    {
        return _VTS.getCurVault(_ipToken, _baseToken);
    }

    function getAvailVault(
        address _ipToken,
        address _baseToken
    )
        public view
        returns (uint256)
    {
        uint256 vault = _VTS.getTotalVault(_ipToken, _baseToken);
        uint256 withdrawed = _VTS.getIPWithdrawed(_ipToken, _baseToken);
        uint256 curVault = _VTS.getCurVault(_ipToken, _baseToken);
        uint256 avail = vault.mul(80).div(100);
        avail = avail.sub(withdrawed);
        avail = avail > curVault ? curVault : avail;
        return avail;
    }

    function getStageTransit(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (bool)
    {
        uint8 stage = _IPS.getPoolStage(_ipToken, _baseToken);
        uint256 time = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);

        if (stage == uint8(Stages.AUCTING)) {
            if (block.timestamp >= time) {
                return true;
            }
        } else if (stage == uint8(Stages.RAISING)) {
            if (block.timestamp >= time.add(_NP.raisingDuration())) {
                return true;
            }
        } else if (stage == uint8(Stages.ALLOCATING)) {
            return true;
        } else if (stage == uint8(Stages.RUNNING)) {
            uint256 duration = _IPS.getIPDuration(_ipToken, _baseToken);
            if (block.timestamp >= time.add(duration)) {
                return true;
            }
        }

        return false;
    }

    function getPoolInfo(
        address _ipToken,
        address _baseToken
    )
        external view
        returns (string[] memory keys, uint256[] memory values)
    {
        keys = new string[](uint256(Keys.MAXELEMENTS));
        values = new uint256[](uint256(Keys.MAXELEMENTS));

        keys[uint256(Keys.PoolStage)] = "PoolStage";
        values[uint256(Keys.PoolStage)] = uint256(_IPS.getPoolStage(_ipToken, _baseToken));

        keys[uint256(Keys.CreateTime)] = "CreateTime";
        values[uint256(Keys.CreateTime)] = _IPS.getPoolCreateTime(_ipToken, _baseToken);

        keys[uint256(Keys.AuctionEndTime)] = "AuctionEndTime";
        values[uint256(Keys.AuctionEndTime)] = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);

        keys[uint256(Keys.IPImpawnAmount)] = "IPImpawnAmount";
        values[uint256(Keys.IPImpawnAmount)] = _IPS.getIPTokensAmount(_ipToken, _baseToken);

        keys[uint256(Keys.IPBidDGTAmount)] = "IPBidDGTAmount";
        values[uint256(Keys.IPBidDGTAmount)] = _IPS.getDGTTokensAmount(_ipToken, _baseToken);

        keys[uint256(Keys.IPImpawnRatio)] = "IPImpawnRatio";
        values[uint256(Keys.IPImpawnRatio)]  = _IPS.getIPImpawnRatio(_ipToken, _baseToken);

        keys[uint256(Keys.IPCloseLine)] = "IPCloseLine";
        values[uint256(Keys.IPCloseLine)] = _IPS.getIPCloseLine(_ipToken, _baseToken);

        keys[uint256(Keys.IPChargeRatio)] = "IPChargeRatio";
        values[uint256(Keys.IPChargeRatio)] = _IPS.getIPChargeRatio(_ipToken, _baseToken);

        keys[uint256(Keys.PoolDuration)] = "PoolDuration";
        values[uint256(Keys.PoolDuration)] = _IPS.getIPDuration(_ipToken, _baseToken);

        keys[uint256(Keys.GPVolume)] = "GPVolume";
        values[uint256(Keys.GPVolume)] = _IPS.getIPMaxCanRaise(_ipToken, _baseToken);

        keys[uint256(Keys.GPAmount)] = "GPAmount";
        values[uint256(Keys.GPAmount)] = _GPS.getCurGPAmount(_ipToken, _baseToken);

        keys[uint256(Keys.GPBalance)] = "GPBalance";
        values[uint256(Keys.GPBalance)] = _GPS.getCurGPBalance(_ipToken, _baseToken);

        keys[uint256(Keys.SwapIPAmount)] = "SwapIPAmount";
        values[uint256(Keys.SwapIPAmount)] = _GPS.getCurIPAmount(_ipToken, _baseToken);

        keys[uint256(Keys.RaiseLPAmount)] = "RaiseLPAmount";
        values[uint256(Keys.RaiseLPAmount)] = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);

        keys[uint256(Keys.LPAmount)] = "LPAmount";
        values[uint256(Keys.LPAmount)] = _LPS.getCurLPAmount(_ipToken, _baseToken);

        keys[uint256(Keys.CurVault)] = "CurVault";
        values[uint256(Keys.CurVault)] = _VTS.getCurVault(_ipToken, _baseToken);

        keys[uint256(Keys.IPAvailVault)] = "IPAvailVault";
        values[uint256(Keys.IPAvailVault)] = getAvailVault(_ipToken, _baseToken);

        keys[uint256(Keys.IPWithdrawedVault)] = "IPWithdrawedVault";
        values[uint256(Keys.IPWithdrawedVault)] = _VTS.getIPWithdrawed(_ipToken, _baseToken);

        return (keys, values);
    }
    
    function getLPAsset(
        address _ipToken,
        address _baseToken,
        address _lp
    ) 
        external view 
        returns (uint256 ipAsset, uint256 baseAsset)
    {
        require(_IPS.getPoolValid(_ipToken, _baseToken), "NudgePool Not Exist");
        
        if (!_LPS.getLPValid(_ipToken, _baseToken, _lp)) {
            return (ipAsset, baseAsset);
        }

        uint8 stage = _IPS.getPoolStage(_ipToken, _baseToken);
        uint256 LPBaseAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        uint256 vaultReward = _LPS.getLPVaultReward(_ipToken, _baseToken, _lp);
        
        if (stage == uint8(Stages.RAISING)) {
            baseAsset = LPBaseAmount;
        } else if (stage == uint8(Stages.RUNNING)) {
            uint256 fee = LPBaseAmount.mul(1).div(100);
            baseAsset = LPBaseAmount.add(vaultReward).sub(fee);

        } else if (stage == uint8(Stages.LIQUIDATION)) {
            uint256 totalIPAmount = _LPS.getLiquidationIPAmount(_ipToken, _baseToken);
            uint256 totalBaseAmount =  _LPS.getLiquidationBaseAmount(_ipToken, _baseToken);
            uint256 totalLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);

            if (totalIPAmount > 0) {
                ipAsset = totalIPAmount.mul(LPBaseAmount).div(totalLPAmount);
            }

            if (totalBaseAmount > 0) {
                baseAsset = vaultReward.add(totalBaseAmount.mul(LPBaseAmount).div(totalLPAmount));
            }
        }
    }

    function getGPAsset(
        address _ipToken,
        address _baseToken,
        address _gp
    ) 
        external view 
        returns (uint256 ipAsset, uint256 baseAsset)
    {
        require(_IPS.getPoolValid(_ipToken, _baseToken), "NudgePool Not Exist");
        
        if (!_GPS.getGPValid(_ipToken, _baseToken, _gp)) {
            return (ipAsset, baseAsset);
        }
        
        uint8 stage = _IPS.getPoolStage(_ipToken, _baseToken);
        
        if (stage == uint8(Stages.RAISING)) {
            baseAsset = _GPS.getGPBaseBalance(_ipToken, _baseToken, _gp);
        } else if (stage == uint8(Stages.RUNNING)) {
            uint256 belongLP = _GPS.getGPRaiseLPAmount(_ipToken, _baseToken, _gp);
            uint256 IPAmount = _GPS.getGPHoldIPAmount(_ipToken, _baseToken, _gp);
            uint256 swappedBase = NPSwap.getAmountOut(_ipToken, _baseToken, IPAmount);
            baseAsset = swappedBase > belongLP ? swappedBase.sub(belongLP) : 0;
            uint256 GPBase = _GPS.getGPBaseAmount(_ipToken, _baseToken, _gp);
            uint256 earnedGP = baseAsset > GPBase ? baseAsset.sub(GPBase) : 0;

            if (earnedGP > 0) {
                baseAsset = baseAsset.sub(earnedGP.mul(20).div(100));
            }
        } else if (stage == uint8(Stages.LIQUIDATION)) {
            uint256 totalIPAmount = _GPS.getLiquidationIPAmount(_ipToken, _baseToken);
            uint256 totalBaseAmount =  _GPS.getLiquidationBaseAmount(_ipToken, _baseToken);
            uint256 totalBalance = _GPS.getCurGPBalance(_ipToken, _baseToken);
            uint256 balance = _GPS.getGPBaseBalance(_ipToken, _baseToken, _gp);

            if (totalIPAmount > 0) {
                ipAsset = totalIPAmount.mul(balance).div(totalBalance);
            }

            if (totalBaseAmount > 0) {
                baseAsset = totalBaseAmount.mul(balance).div(totalBalance);
            }
        }
    }
}