pragma solidity ^0.8.4;


import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
* @dev Inteface for the token lock features in this contract
*/
interface ITOKENLOCK {
    /**
     * @dev Emitted when the token lock is initialized  
     * `tokenHolder` is the address the lock pertains to
     *  `amountLocked` is the amount of tokens locked 
     *  `time` is the (initial) time at which tokens were locked
     *  `unlockPeriod` is the time interval at which tokens become unlockedPerPeriod
     *  `unlockedPerPeriod` is the amount of token unlocked earch unlockPeriod
     */
    event  NewTokenLock(address tokenHolder, uint256 amountLocked, uint256 time, uint256 unlockPeriod, uint256 unlockedPerPeriod);
    /**
     * @dev Emitted when the token lock is updated  to be more strict
     * `tokenHolder` is the address the lock pertains to
     *  `amountLocked` is the amount of tokens locked 
     *  `time` is the (initial) time at which tokens were locked
     *  `unlockPeriod` is the time interval at which tokens become unlockedPerPeriod
     *  `unlockedPerPeriod` is the amount of token unlocked earch unlockPeriod
     */
    event  UpdateTokenLock(address tokenHolder, uint256 amountLocked, uint256 time, uint256 unlockPeriod, uint256 unlockedPerPeriod);
    
    /**
     * @dev Lock `baseTokensLocked_` held by the caller with `unlockedPerEpoch_` tokens unlocking each `unlockEpoch_`
     *
     *
     * Emits an {NewTokenLock} event indicating the updated terms of the token lockup.
     *
     * Requires msg.sender to:
     *
     * - Must not be a prevoius lock for this address. If so, it must be first cleared with a call to {clearLock}.
     * - Must have at least a balance of `baseTokensLocked_` to lock
     * - Must provide non-zero `unlockEpoch_`
     * - Must have at least `unlockedPerEpoch_` tokens to unlock 
     *  - `unlockedPerEpoch_` must be greater than zero
     */
    
    function newTokenLock(uint256 baseTokensLocked_, uint256 unlockEpoch_, uint256 unlockedPerEpoch_) external;
    
    /**
     * @dev Reset the lock state
     *
     * Requirements:
     *
     * - msg.sender must not have any tokens locked, currently
     */
    function clearLock() external;
    
    /**
     * @dev Returns the amount of tokens that are unlocked i.e. transferrable by `who`
     *
     */
    function balanceUnlocked(address who) external view returns (uint256 amount);
    /**
     * @dev Returns the amount of tokens that are locked and not transferrable by `who`
     *
     */
    function balanceLocked(address who) external view returns (uint256 amount);

    /**
     * @dev Reduce the amount of token unlocked each period by `subtractedValue`
     * 
     * Emits an {UpdateTokenLock} event indicating the updated terms of the token lockup.
     * 
     * Requires: 
     *  - msg.sender must have tokens currently locked
     *  - `subtractedValue` is greater than 0
     *  - cannot reduce the unlockedPerEpoch to 0
     *
     *  NOTE: As a side effect resets the baseTokensLocked and lockTime for msg.sender 
     */
    function decreaseUnlockAmount(uint256 subtractedValue) external;
    /**
     * @dev Increase the duration of the period at which tokens are unlocked by `addedValue`
     * this will have the net effect of slowing the rate at which tokens are unlocked
     * 
     * Emits an {UpdateTokenLock} event indicating the updated terms of the token lockup.
     * 
     * Requires: 
     *  - msg.sender must have tokens currently locked
     *  - `addedValue` is greater than 0
     * 
     *  NOTE: As a side effect resets the baseTokensLocked and lockTime for msg.sender 
     */
    function increaseUnlockTime(uint256 addedValue) external;
    /**
     * @dev Increase the number of tokens locked by `addedValue`
     * i.e. locks up more tokens.
     * 
     *      
     * Emits an {UpdateTokenLock} event indicating the updated terms of the token lockup.
     * 
     * Requires: 
     *  - msg.sender must have tokens currently locked
     *  - `addedValue` is greater than zero
     *  - msg.sender must have sufficient unlocked tokens to lock
     * 
     *  NOTE: As a side effect resets the baseTokensLocked and lockTime for msg.sender 
     *
     */
    function increaseTokensLocked(uint256 addedValue) external;

}

/** 
* @dev Computes voting power based on staked and locked tokens.
* The deployer is responsible for supplying a token_ implementing ERC20 and ILOCKER. 
* The deployer is trusted to know & have verified the token code token code is appropriate.
* A scaling factor is specified as a uint8 array of bytes which serves to 
* reduce or increase the voting power of a class of token holder (locked tokens). 
* The scaling factor changes over time, and is looked up based on the current epoch
*/
contract VotingPower is ReentrancyGuard{
    //the token used for staking. Implements ILOCKER. It is trusted & known code.
    IERC20 _token;
    //store the number of tokens staked by each address
    mapping (address => uint256) private stakedTokens;
    //store the time of last staking change for an address. For extensibility; coordination with another contract
    mapping (address => uint256) public timestamp;
    //keep track of the sum of staked tokens
    uint256 private _totalStaked;
    
    //events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

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
    * @param scaling_ is an array of uint8 (bytes) percentage discounts for each epoch
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
        return stakedTokens[who];
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
    function stake(uint256 amount) public nonReentrant{
        require(amount > 0, "Cannot Stake 0");
        uint256 previousAmount = IERC20(_token).balanceOf(address(this));
        _token.safeTransferFrom( msg.sender, address(this), amount);
        uint256 transferred = IERC20(_token).balanceOf(address(this)) - previousAmount;
        stakedTokens[msg.sender] = stakedTokens[msg.sender] + transferred;
        _totalStaked = _totalStaked + transferred;
        timestamp[msg.sender] = block.timestamp;
        emit Staked(msg.sender, transferred);
    }

    /**
    * @dev Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the caller, 
    * MUST trigger Unstaked event.
    */
    function unstake(uint256 amount) public nonReentrant{
        require(amount > 0, "Cannot UnStake 0");
        require(amount <= stakedTokens[msg.sender], "INSUFFICENT TOKENS TO UNSTAKE");
        _token.safeTransfer( msg.sender, amount);
        stakedTokens[msg.sender] = stakedTokens[msg.sender] - amount;
        _totalStaked = _totalStaked - amount;
        timestamp[msg.sender] = block.timestamp;
        emit Unstaked(msg.sender, amount);
    }

    /**
    * @dev Returns the current total of tokens staked for address addr.
    */
    function totalStakedBy(address addr) public view returns (uint256){
        return stakedTokens[addr];
    }
    /**
    * @dev Returns the number of current total tokens staked.
    */
    function totalStaked() public view returns (uint256){
        return _totalStaked;
    }
    /**
    * @dev address of the token being used by the staking interface
    */
    function token() public view returns (address){
        return address(_token);
    }
   
    

}
