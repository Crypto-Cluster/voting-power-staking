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




contract VotingPower is ReentrancyGuard{
    IERC20 _token;
    mapping (address => uint256) private _stakedTokens;
    uint256 private _totalStaked;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    using SafeERC20 for IERC20;
    
    constructor(address token_){
        _token = IERC20(token_);
    }

    /**
    * @dev Returns the voting power for `who`
    **/
    function votingPower(address who) public view returns (uint256) {
        return _votingPowerStaked(who) + _votingPowerLocked(who);
    }

    function _votingPowerStaked(address who) internal view returns (uint256) {
        return _stakedTokens[who];
    }

    function _votingPowerLocked(address who) internal view returns (uint256) {
        return ITOKENLOCK(address(_token)).balanceLocked(who);
    }

    /**
    * @dev Stakes a certain amount of tokens, this will attempt to transfer the given amount from the caller.
    * It will count the actual number of tokens trasferred as being staked
    * MUST trigger Staked event.
    **/
    function stake(uint256 amount) public nonReentrant{
        require(amount > 0, "Cannot stake 0");
        uint256 previousAmount = IERC20(_token).balanceOf(address(this));
        _token.safeTransferFrom( msg.sender, address(this), amount);
        uint256 transferred = IERC20(_token).balanceOf(address(this)) - previousAmount;
        _stakedTokens[msg.sender] = _stakedTokens[msg.sender] + transferred;
        _totalStaked = _totalStaked + transferred;
        emit Staked(msg.sender, transferred);
    }

    /**
    * @dev Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the caller, 
    * if unstaking is currently not possible the function MUST revert.
    * MUST trigger Unstaked event.
    */
    function unstake(uint256 amount) public nonReentrant{
        require(amount > 0, "Cannot UnStake 0");
        require(amount <= _stakedTokens[msg.sender], "INSUFFICENT TOKENS TO UNSTAKE");
        _token.safeTransfer( msg.sender, amount);
        _stakedTokens[msg.sender] = _stakedTokens[msg.sender] - amount;
        _totalStaked = _totalStaked - amount;
        emit Unstaked(msg.sender, amount);
    }

    /**
    * @dev Returns the current total of tokens staked for address addr.
    */
    function totalStakedBy(address addr) public view returns (uint256){
        return _stakedTokens[addr];
    }
    /**
    * @dev Returns the current total of tokens staked.
    */
    function totalStaked() public view returns (uint256){
        return _totalStaked;
    }
    /**
    * @dev Address of the token being used by the staking interface
    */
    function token() public view returns (address){
        return address(_token);
    }
   
    

}
