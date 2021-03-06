/**
* @dev Public interface for the staking functions 
*/
interface ISTAKING{
    /**
    * @dev Stakes a certain amount of tokens, this will attempt to transfer the given amount from the caller.
    * It will count the actual number of tokens trasferred as being staked
    * MUST trigger Staked event.
    **/
    function stake(uint256 amount) external returns (uint256);

    /**
    * @dev Stakes a certain amount of tokens on behalf of address `user`, 
    * this will attempt to transfer the given amount from the caller.
    * caller must have approved this contract, previously. 
    * It will count the actual number of tokens trasferred as being staked
    * MUST trigger Staked event.
    * Returns the number of tokens actually staked
    **/
    function stakeFor(address user, uint256 amount) external returns (uint256);
    /**
    * @dev Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the caller, 
    * MUST trigger Unstaked event.
    */
    function unstake(uint256 amount) external;

    /**
    * @dev Unstakes a certain amount of tokens currently staked on behalf of address `user`, 
    * this SHOULD return the given amount of tokens to the caller
    * caller is responsible for returning tokens to `user` if applicable.
    * MUST trigger Unstaked event.
    */
    function unstakeFor(address user, uint256 amount, address recipient) external;

    /**
    * @dev Returns the current total of tokens staked for address addr.
    */
    function totalStakedFor(address addr) external view returns (uint256);

    /**
    * @dev Returns the current tokens staked by address `delegate` for address `user`.
    */
    function stakedFor(address user, address delegate) external view returns (uint256);

    /**
    * @dev Returns the number of current total tokens staked.
    */
    function totalStaked() external view returns (uint256);

    /**
    * @dev address of the token being used by the staking interface
    */
    function token() external view returns (address);
}