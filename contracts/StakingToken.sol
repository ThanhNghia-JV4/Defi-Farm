//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RewardToken.sol";
import "./StakeToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingToken is Ownable, ERC20{
    using SafeERC20 for StakeToken; 

   RewardToken public rewardToken; // reward Token
   StakeToken public stakeToken;

    uint256 private rewardTokensPerBlock; // reward tokens gotten per block
    uint256 private constant BIG_INT_FORMATTER = 1e12; 
    // BIG_INT_FORMATTER <=> eth
    // Each person staking
    struct StakerInfo {
        uint256 amount; // amount of staked token
        uint256 rewardDebt; // reward not entitled to user
        uint256 rewards; //  rewards user will get
    }

    // Pool information
    struct Pool {
        StakeToken stakeToken; // Token to be staked
        uint256 tokensStaked; // Total number of tokens staked
        uint256 lastRewardedBlock; // Last block number the user had their rewards calculated
        uint256 accumulatedRewardsPerShare; // Accumulated rewards per share times BIG_INT_FORMATTER
    }

    Pool[] public pools; // Array of pools

    // Mapping poolId => staker address => PoolStaker
    mapping(uint256 => mapping(address => StakerInfo)) public stakerInfo;

    // Events
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount);
    event CollectRewards(address indexed user, uint256 indexed poolId, uint256 amount);
    event PoolCreated(uint256 poolId); 

    // Constructor
    constructor(address _rewardTokenAddress, uint256 _rewardTokensPerBlock) ERC20("Bare Token", "BTK"){
        rewardToken = RewardToken(_rewardTokenAddress);
        rewardTokensPerBlock = _rewardTokensPerBlock;
    }

    /**
     * Create the Staking pool
     */
    function createStakingPool(StakeToken _stakeToken) external onlyOwner {
        Pool memory pool;
        pool.stakeToken =  _stakeToken; //address cuar t hay address token ? 
        
        pools.push(pool);
        uint256 poolId = pools.length - 1;
        emit PoolCreated(poolId);
    }

    /**
     * Deposit to pool
     */
    function deposit(uint256 _poolId, uint256 _amount) payable external{
        require(_amount > 0, "Deposit amount can't be zero");
        Pool storage pool = pools[_poolId];
        StakerInfo storage staker = stakerInfo[_poolId][msg.sender];

        // Update pool stakers and if anyone is collecting reward at this block, they collect their reward
        collectRewards(_poolId);

        // Update current staker 
        staker.amount = staker.amount + _amount; //adds up if staker comes to stakes extra
        staker.rewardDebt = staker.amount * pool.accumulatedRewardsPerShare / BIG_INT_FORMATTER;

        // Update pool
        pool.tokensStaked = pool.tokensStaked + _amount;

        // Deposit tokens
        emit Deposit(msg.sender, _poolId, _amount);
        pool.stakeToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
    }

    /**
     * Withdraw all tokens from an existing pool
     */
    function withdraw(uint256 _poolId,  uint256 _amount) public {

        require(_amount > 0, "Withdraw amount can't be zero");
        Pool storage pool = pools[_poolId];
        StakerInfo storage staker = stakerInfo[_poolId][msg.sender];
       

        // Pay rewards
        collectRewards(_poolId);

        // Update staker
        staker.amount = 0; //staker is withdrawing hence amount is 0
        staker.rewardDebt = staker.amount * pool.accumulatedRewardsPerShare / BIG_INT_FORMATTER;

        // Update pool
        pool.tokensStaked = pool.tokensStaked - _amount;

        // Withdraw tokens
        emit Withdraw(msg.sender, _poolId, _amount);
        pool.stakeToken.safeTransfer(
            address(msg.sender),
            _amount
        );
    }

    /**
     * Collect rewards from a given pool id, 
     */
     // lấy ID nhóm làm tham số. Chức năng tính toán phần thưởng cho người dùng dựa trên cổ phần của họ và phần thưởng tích lũy trên mỗi cổ phần, sau đó chuyển phần thưởng từ hợp đồng cho người dùng.
    function collectRewards(uint256 _poolId) public {
        updatePoolRewards(_poolId); 
        Pool storage pool = pools[_poolId];
        StakerInfo storage staker = stakerInfo[_poolId][msg.sender];
        uint256 rewardsToHarvest = (staker.amount * pool.accumulatedRewardsPerShare / BIG_INT_FORMATTER) - staker.rewardDebt;
        if (rewardsToHarvest == 0) {
            staker.rewardDebt = staker.amount * pool.accumulatedRewardsPerShare / BIG_INT_FORMATTER;
            return;
        }
        staker.rewards = 0;
        staker.rewardDebt = staker.amount * pool.accumulatedRewardsPerShare / BIG_INT_FORMATTER;
        emit CollectRewards(msg.sender, _poolId, rewardsToHarvest);
        rewardToken.mint(msg.sender, rewardsToHarvest);
    }
    // Tỷ lệ lãi suất = ((Số lượng token thưởng được mỗi khối * Kích thước khối) / Tổng số token đang được đầu tư) * 100%
    // Ví dụ: nếu rewardTokensPerBlock là 10 và tokensStaked là 1000, và kích thước khối là 1 giây, thì tỷ lệ lãi suất sẽ là:

    // ((10 tokens/block * 1 block/second) / 1000 tokens) * 100% = 1% / giây.
    /**
     * Update pool's accumulatedRewardsPerShare and lastRewardedBlock
     */
    function updatePoolRewards(uint256 _poolId) public {
        Pool storage pool = pools[_poolId];
        if (pool.tokensStaked == 0) {
            pool.lastRewardedBlock = block.number;
            return;
        }
        uint256 blocksSinceLastReward = block.number - pool.lastRewardedBlock;
        uint256 rewards = blocksSinceLastReward * rewardTokensPerBlock;
        pool.accumulatedRewardsPerShare = pool.accumulatedRewardsPerShare + (rewards * BIG_INT_FORMATTER / pool.tokensStaked);
        pool.lastRewardedBlock = block.number;
    }
}