# voting-power-staking
Computes voting power of token holders through staking mechanisms

Computes voting power based on staked and locked tokens.
The deployer is responsible for supplying a token_ implementing ERC20 and ILOCKER. 
The deployer is trusted to know & have verified the token code token code is appropriate.
A scaling factor is specified as a uint8 array of bytes which serves to 
reduce or increase the voting power of a class of token holder (locked tokens). 
The scaling factor changes over time, and is looked up based on the current epoch

## constructor(address token_, bytes memory scaling_, uint256 epoch_)
initialize the contract
### token_ is the token that is staked to get voting power
### scaling_ is an array of uint8 (bytes) percentage discounts for each epoch
### epoch_ is the duration of one epoch in seconds

## function votingPower(address who) public view returns (uint256) 
Returns the voting power for `who`
### who indicates the address whose votingPower to compute
### returns the voting power for who
    
## function stake(uint256 amount) public nonReentrant
Stakes a certain amount of tokens, this will attempt to transfer the given amount from the caller.
It will count the actual number of tokens trasferred as being staked
MUST trigger Staked event.
    
## function unstake(uint256 amount) public nonReentrant
Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the caller, 
MUST trigger Unstaked event.
    
## function totalStakedBy(address addr) public view returns (uint256)
Returns the current total of tokens staked for address addr.

## function totalStaked() public view returns (uint256)
Returns the number of current total tokens staked.
   
## function token() public view returns (address){
address of the token being used by the staking interface
