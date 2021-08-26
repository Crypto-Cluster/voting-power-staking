/*
THIS IS AN UNAUDITED MOCK CONTRACT FOR TESTING
DO NOT USE IN PRODUCTION!
*/
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../ISTAKING.sol";
import "../ISTAKINGPROXY.sol";


//note: evil because skims 1 token in proxyTransfer function
contract EvilStakingProxy is ISTAKINGPROXY{

    address token;
    address staking;
    mapping (address => uint256) public stakeTimes;
    mapping (address => uint256) public stakeAmounts;

    uint256 tokenReward; // per token per second

    mapping (address => uint256) public accruedRewards;

    //assume staking token is also used to pay rewards
    constructor(address token_, address staking_, uint256 reward_){
        token = token_;
        staking = staking_;
        tokenReward = reward_;
    }

    //user staking function
    function stake(uint256 amount) external{
        //bookkeeping to do beforehand
        accruedRewards[msg.sender] = accruedRewards[msg.sender] + stakeAmounts[msg.sender]*(block.timestamp - stakeTimes[msg.sender]);
        stakeAmounts[msg.sender] = stakeAmounts[msg.sender]+ ISTAKING(token).stakeFor(msg.sender, amount);
        //bookkeeping
        stakeTimes[msg.sender] = block.timestamp;        
    }

    function proxyTransfer(address from, uint256 amount) external override{
        require(msg.sender == staking);
        IERC20(token).transferFrom(from, staking, (amount-1));
        //do bookkeeping here?
    }

    function unstake(uint256 amount) external {
        //do bookkeeping
        accruedRewards[msg.sender] = accruedRewards[msg.sender] + stakeAmounts[msg.sender]*(block.timestamp - stakeTimes[msg.sender]);
        ISTAKING(staking).unstakeFor(msg.sender, amount, msg.sender);
        stakeAmounts[msg.sender] = stakeAmounts[msg.sender] - amount;
        stakeTimes[msg.sender] = block.timestamp;        
    }

    function claim() external{
        uint256 amt = accruedRewards[msg.sender];
        accruedRewards[msg.sender] = 0;
        IERC20(token).transfer(msg.sender, amt);
    }


}