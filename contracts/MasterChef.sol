// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC20.sol";

// -----------------------Formulas--------------------------

// multiplier = (LastBlock - FirstBlock) * Bonus
// Pool Reward = multiplier * Coin Per Block * Pool Allocation / Total Allocation
// Pool Token Reward per Share = Pool Reward / Total Staked Amount
// Defi Staking Reward = My Staking * Pool Token Reward per Share

contract MTKMasterChefV1 is Ownable, ReentrancyGuard {
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

    MTKRewards public mtk;
    address public devaddr;
    uint256 public mtkPerBlock;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    PoolInfo[] public poolInfo;
    uint256 public totalAllocation = 0;
    uint256 public startBlock;
    uint256 public BONUS_MULTIPLIER;

    constructor(
        MTKRewards _mtk,
        address _devaddr,
        uint256 _mtkPerBlock,
        uint256 _startBlock,
        uint256 _multiplier
    ) public {
        mtk = _mtk;
        devaddr = _devaddr;
        mtkPerBlock = _mtkPerBlock;
        startBlock = _startBlock;
        BONUS_MULTIPLIER = _multiplier;

        poolInfo.push(
            PoolInfo({
                lpToken: _mtk,
                allocPoint: 10000,
                lastRewardBlock: _startBlock,
                rewardTokenPerShare: 0
            })
        );

        totalAllocation = 10000;
    }

    modifier validatePool(uint256 _pid) {
        require(_pid < poolInfo.length, "Pool id is Invalid");
        _;
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

    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function updateMultiplier(uint256 _multiplier) public onlyOwner {
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
        for (uint256 pid = 1; pid < length; ++pid) {
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

    function add(uint256 _allocPoint, IERC20 _lpToken) public onlyOwner {
        checkDuplicatePool(_lpToken);
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocation = totalAllocation.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                rewardTokenPerShare: 0
            })
        );
        updateStakingPool();
    }

    function updatePool(uint256 _pid) public validatePool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(mtkPerBlock).mul(pool.allocPoint).div(totalAllocation);
        mtk.mint(devaddr, tokenReward.div(10));
        mtk.mint(address(this), tokenReward);
        pool.rewardTokenPerShare = pool.rewardTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }
}
