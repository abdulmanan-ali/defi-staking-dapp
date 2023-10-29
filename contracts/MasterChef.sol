// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC20-MasterChef.sol";

// -----------------------Formulas--------------------------

// Multiplier = (LastBlock - FirstBlock) * Bonus
// Pool Reward = Multiplier * Coin Per Block * Pool Allocation / Total Allocation
// Pool Token Reward per Share = Pool Reward / Total Staked Amount
// Defi Staking Reward = My Staking * Pool Token Reward per Share

contract N2DMasterChefV1 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 pendingReward;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 rewardTokenPerShare;
    }

    N2DRewards public n2dr;
    address public dev;
    uint256 public n2drPerBlock;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    PoolInfo[] public poolInfo;
    uint256 public totalAllocation = 0;
    uint256 public startBlock;
    uint256 public BONUS_MULTIPLIER;

    constructor(
        N2DRewards _n2dr,
        address _dev,
        uint256 _n2drPerBlock,
        uint256 _startBlock,
        uint256 _multiplier
    ) public {
        n2dr = _n2dr;
        dev = _dev;
        n2drPerBlock = _n2drPerBlock;
        startBlock = _startBlock;
        BONUS_MULTIPLIER = _multiplier;

        poolInfo.push(
            PoolInfo({
                lpToken: _n2dr,
                allocPoint: 10000,
                lastRewardBlock: _startBlock,
                rewardTokenPerShare: 0
            })
        );

        totalAllocation = 10000;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getPoolInfo(
        uint256 pid
    )
        public
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 rewardTokenPerShare
        )
    {
        return (
            (address(poolInfo[pid].lpToken)),
            poolInfo[pid].allocPoint,
            poolInfo[pid].lastRewardBlock,
            poolInfo[pid].rewardTokenPerShare
        );
    }

    function getMultiplier(uint256 _multiplier) public onlyOwner {
        BONUS_MULTIPLIER = _multiplier;
    }

    function checkDuplicatePool(IERC20 token) public view {
        uint256 length = poolInfo.length;
        for (uint256 _pid = 0; _pid < length; _pid++) {
            require(poolInfo[_pid].lpToken != token, "Pool Already Exists");
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; pid++) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocation = totalAllocation.sub(poolInfo[0].allocPoint).add(
                points
            );
            poolInfo[0].allocPoint = points;
        }
    }
}