# voting-power-staking
Computes voting power of token holders through staking mechanisms



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
