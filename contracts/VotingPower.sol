pragma solidity ^0.8.4;


import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ISTAKING.sol";
import "./ISTAKINGPROXY.sol";
import "./ITOKENLOCK.sol";


struct Stake{
    uint256 totalStake;
    mapping (address => uint256) stakedAmount;
}

/** 
* @dev Computes voting power based on staked and locked tokens.
* The deployer is responsible for supplying a token_ implementing ERC20 and ILOCKER. 
* The deployer is trusted to know & have verified the token code token code is appropriate.
* A scaling factor is specified as a uint8 array of bytes which serves to 
* reduce or increase the voting power of a class of token holder (locked tokens). 
* The scaling factor changes over time, and is looked up based on the current epoch
*/
contract VotingPower is ReentrancyGuard, ISTAKING{
    //the token used for staking. Implements ILOCKER. It is trusted & known code.
    IERC20 _token;
    //store the number of tokens staked by each address
    mapping (address => Stake) public stakes;

    //keep track of the sum of staked tokens
    uint256 private _totalStaked;
    
    //events
    //TODO: what does this mean?
    event Staked(address indexed staker, address proxy, uint256 amount);
    event Unstaked(address indexed staker, address proxy, uint256 amount, address recipient);

    using SafeERC20 for IERC20;

    //locked tokens have their voting power scaled by this percentage.
    bytes voteScalingPercent;
    //the time at which this contract was deployed (unix time)
    uint256 creationTime;
    //the time each voting epoch lasts in seconds
    uint256 epochLength;

    /**
    * @dev initialize the contract
    * @param token_ is the token that is staked to get voting power
    * @param scaling_ is an array of uint8 (bytes) percent voting power discounts for each epoch
    * @param epoch_ is the duration of one epoch in seconds
    **/
    constructor(address token_, bytes memory scaling_, uint256 epoch_){
        require(epoch_ > 0);
        _token = IERC20(token_);
        creationTime = block.timestamp;
        voteScalingPercent = scaling_;
        epochLength = epoch_;
    }

    /**
    * @dev Returns the voting power for `who`
    * @param who the address whose votingPower to compute
    * @return the voting power for who
    **/
    function votingPower(address who) public view returns (uint256) {
        return _votingPowerStaked(who) + _votingPowerLocked(who);
    }

    /**
    * @dev Returns the voting power for `who` due to staked tokens
    * @param who the address whose votingPower to compute
    * @return the voting power for who    
    **/
    function _votingPowerStaked(address who) internal view returns (uint256) {
        return stakes[who].totalStake;
    }
    /**
    * @dev Returns the voting power for `who` due to locked tokens
    * @param who the address whose votingPower to compute
    * @return the voting power for who    
    * Locked tokens scaled discounted voting power as defined by voteScalingPercent
    **/
    function _votingPowerLocked(address who) internal view returns (uint256) {
        uint256 epoch = _currentEpoch();
        if(epoch >= voteScalingPercent.length){
            return ITOKENLOCK(address(_token)).balanceLocked(who);
        }
        return ITOKENLOCK(address(_token)).balanceLocked(who) * (uint8)(voteScalingPercent[epoch])/100.0;
    }
    /**
    * @dev Returns the current epoch used to look up the scaling factor
    * @return the current epoch
    **/
    function _currentEpoch() internal view returns (uint256) {
        return (block.timestamp - creationTime)/epochLength;
    }

    /**
    * @dev Stakes a certain amount of tokens, this will attempt to transfer the given amount from the caller.
    * It will count the actual number of tokens trasferred as being staked
    * MUST trigger Staked event.
    **/
    function stake(uint256 amount) external override nonReentrant returns (uint256){
        require(amount > 0, "Cannot Stake 0");
        uint256 previousAmount = IERC20(_token).balanceOf(address(this));
        _token.safeTransferFrom( msg.sender, address(this), amount);
        uint256 transferred = IERC20(_token).balanceOf(address(this)) - previousAmount;
        require(transferred > 0);
        stakes[msg.sender].totalStake = stakes[msg.sender].totalStake + transferred;
        stakes[msg.sender].stakedAmount[msg.sender] = stakes[msg.sender].stakedAmount[msg.sender] + transferred;
        _totalStaked = _totalStaked + transferred;
        emit Staked(msg.sender, msg.sender, transferred);
        return transferred;
    }

    /**
    * @dev Stakes a certain amount of tokens on behalf of address `user`, 
    * this will attempt to transfer the given amount from the caller.
    * caller must have approved this contract, previously. 
    * It will count the actual number of tokens trasferred as being staked
    * MUST trigger Staked event.
    * Returns the number of tokens actually staked
    **/
    function stakeFor(address user, uint256 amount) external override nonReentrant returns (uint256){
        require(amount > 0, "Cannot Stake 0");
        uint256 previousAmount = IERC20(_token).balanceOf(address(this));
        //_token.safeTransferFrom( msg.sender, address(this), amount);
        ISTAKINGPROXY(msg.sender).proxyTransfer(user, amount);
        //verify that amount that the proxy contract transferred the amount
        uint256 transferred = IERC20(_token).balanceOf(address(this)) - previousAmount;
        require(transferred > 0);
        stakes[user].totalStake = stakes[user].totalStake + transferred;
        stakes[user].stakedAmount[msg.sender] = stakes[user].stakedAmount[msg.sender] + transferred;
        _totalStaked = _totalStaked + transferred;
        emit Staked(user, msg.sender, transferred);
        return transferred;
    }
    /**
    * @dev Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the caller, 
    * MUST trigger Unstaked event.
    */
    function unstake(uint256 amount) external override nonReentrant{
        require(amount > 0, "Cannot UnStake 0");
        require(amount <= stakes[msg.sender].stakedAmount[msg.sender], "INSUFFICENT TOKENS TO UNSTAKE");
        _token.safeTransfer( msg.sender, amount);
        stakes[msg.sender].totalStake = stakes[msg.sender].totalStake - amount;
        stakes[msg.sender].stakedAmount[msg.sender] = stakes[msg.sender].stakedAmount[msg.sender] - amount;
        _totalStaked = _totalStaked - amount;
        emit Unstaked(msg.sender, msg.sender, amount, msg.sender);
    }

    /**
    * @dev Unstakes a certain amount of tokens currently staked on behalf of address `user`, 
    * this SHOULD return the given amount of tokens to the caller
    * caller is responsible for returning tokens to `user` if applicable.
    * MUST trigger Unstaked event.
    */
    function unstakeFor(address user, uint256 amount, address recipient) external override nonReentrant{
        require(amount > 0, "Cannot UnStake 0");
        require(amount <= stakes[user].stakedAmount[msg.sender], "INSUFFICENT TOKENS TO UNSTAKE");
        //_token.safeTransfer( msg.sender, amount);
        _token.safeTransfer( recipient, amount);
        stakes[user].totalStake = stakes[user].totalStake - amount;
        stakes[user].stakedAmount[msg.sender] = stakes[user].stakedAmount[msg.sender] - amount;
        _totalStaked = _totalStaked - amount;
        emit Unstaked(user, msg.sender, amount, recipient);
    }

    /**
    * @dev Returns the current total of tokens staked for address addr.
    */
    function totalStakedFor(address addr) external override view returns (uint256){
        return stakes[addr].totalStake;
    }

    /**
    * @dev Returns the current tokens staked by address `delegate` for address `user`.
    */
    function stakedFor(address user, address delegate) external override view returns (uint256){
        return stakes[user].stakedAmount[delegate];
    }
    /**
    * @dev Returns the number of current total tokens staked.
    */
    function totalStaked() external override view returns (uint256){
        return _totalStaked;
    }
    /**
    * @dev address of the token being used by the staking interface
    */
    function token() external override view returns (address){
        return address(_token);
    }
   
    

}


