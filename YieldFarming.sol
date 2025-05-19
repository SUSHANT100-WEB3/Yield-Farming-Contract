// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol"; // For SafeCast if needed
// Interface for fetching ERC-20 metadata (decimals)
interface IERC20Metadata is IERC20 {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

// Custom errors for gas optimization
error ZeroAmount();
error InsufficientStake();
error NotOwner();
error NoRewardsToClaim();
error InsufficientRewardBalance();

/// @title Yield Farming Platform
/// @notice Gas-optimized yield farming contract
contract YieldFarming is ReentrancyGuard {
    using SafeCast for uint256;

    // Packed storage variables
    struct StakerInfo {
        uint128 stakedAmount;    // Reduced from uint256 to uint128
        uint128 rewardDebt;      // Reduced from uint256 to uint128
        uint32 lastUpdate;       // Reduced from uint256 to uint32 (sufficient for timestamps)
    }

    // Immutable variables (saves gas)
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    uint256 public immutable rewardRatePerSecond;
    uint8 public immutable stakingTokenDecimals;
    address public immutable owner;

    // Storage variables
    mapping(address => StakerInfo) private _stakers;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardRefilled(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRatePerSecond
    ) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRatePerSecond = _rewardRatePerSecond;
        owner = msg.sender;

        // Try fetching decimals
        try IERC20Metadata(_stakingToken).decimals() returns (uint8 decimals) {
            stakingTokenDecimals = decimals;
        } catch (bytes memory) {
            stakingTokenDecimals = 18; // Default to 18 decimals if fetching fails
        }
    }

    /// @notice Stake tokens to start earning rewards
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        StakerInfo storage staker = _stakers[msg.sender];
        _updateRewards(msg.sender, staker);

        stakingToken.transferFrom(msg.sender, address(this), amount);
        staker.stakedAmount += uint128(amount);

        emit Staked(msg.sender, amount);
    }

    /// @notice Unstake tokens and optionally claim rewards
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        StakerInfo storage staker = _stakers[msg.sender];
        if (staker.stakedAmount < amount) revert InsufficientStake();

        _updateRewards(msg.sender, staker);

        staker.stakedAmount -= uint128(amount);
        stakingToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /// @notice Claim accumulated rewards
    function claimRewards() external nonReentrant {
        StakerInfo storage staker = _stakers[msg.sender];
        _updateRewards(msg.sender, staker);

        uint256 reward = staker.rewardDebt;
        if (reward == 0) revert NoRewardsToClaim();
        if (rewardToken.balanceOf(address(this)) < reward) revert InsufficientRewardBalance();

        staker.rewardDebt = 0;
        rewardToken.transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    /// @notice Emergency unstake without claiming rewards
    function emergencyWithdraw() external nonReentrant {
        StakerInfo storage staker = _stakers[msg.sender];
        uint256 amount = staker.stakedAmount;
        if (amount == 0) revert ZeroAmount();

        staker.stakedAmount = 0;
        staker.rewardDebt = 0;
        staker.lastUpdate = uint32(block.timestamp);

        stakingToken.transfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, amount);
    }

    /// @notice Admin can refill reward tokens
    function refillRewards(uint256 amount) external onlyOwner {
        rewardToken.transferFrom(msg.sender, address(this), amount);
        emit RewardRefilled(msg.sender, amount);
    }

    /// @notice Update rewards for a staker
    function _updateRewards(address user, StakerInfo storage staker) internal {
        if (staker.stakedAmount > 0) {
            uint256 timeDiff = block.timestamp - staker.lastUpdate;
            uint256 rewardMultiplier = 10 ** stakingTokenDecimals;
            uint256 pendingReward = (timeDiff * rewardRatePerSecond * staker.stakedAmount) / rewardMultiplier;
            staker.rewardDebt += uint128(pendingReward);
        }
        staker.lastUpdate = uint32(block.timestamp);
    }

    /// @notice View pending rewards without claiming
    function pendingRewards(address user) external view returns (uint256) {
        StakerInfo storage staker = _stakers[user];
        uint256 pendingReward = staker.rewardDebt;

        if (staker.stakedAmount > 0) {
            uint256 timeDiff = block.timestamp - staker.lastUpdate;
            uint256 rewardMultiplier = 10 ** stakingTokenDecimals;
            pendingReward += (timeDiff * rewardRatePerSecond * staker.stakedAmount) / rewardMultiplier;
        }

        return pendingReward;
    }

    /// @notice View staking token decimals
    function getStakingTokenDecimals() external view returns (uint8) {
        return stakingTokenDecimals;
    }
}
