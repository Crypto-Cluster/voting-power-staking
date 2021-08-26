//https://github.com/ejwessel/GanacheTimeTraveler
const helper = require('./utils.js');

const VotingPower = artifacts.require("VotingPower");
const GovernanceToken = artifacts.require("OpenDeFiGovernance");
const MockStakingProxy = artifacts.require("MockStakingProxy");
const EvilStakingProxy = artifacts.require("EvilStakingProxy");

contract("VotingPower", accounts => {
    let token;
    let votingPowerInstance;
    let mockStakingProxyInstance;
    let evilStakingProxyInstance;
    const tokenName = "TestingToken";
    const tokenSymbol = 'OTT'
    beforeEach(async () => {
        snapShot = await helper.takeSnapshot();
        snapshotId = snapShot['result'];
        // deploying token contract and send 10000 to the first account
        token = await GovernanceToken.new(tokenName, tokenSymbol, 10000, accounts[0]);
        //75, 50, 25, 0
        votingPowerInstance = await VotingPower.new(token.address, "0x4B3219", 1000);
        mockStakingProxyInstance = await MockStakingProxy.new(token.address, votingPowerInstance.address, 1);
        await token.transfer(mockStakingProxyInstance.address, 500, { from: accounts[0] });
        evilStakingProxyInstance = await EvilStakingProxy.new(token.address, votingPowerInstance.address, 1);
        await token.transfer(evilStakingProxyInstance.address, 500, { from: accounts[0] });

    });

    afterEach(async() => {
        //await helper.revertToSnapshot(snapshotId);
    });

    //stake for self using mock rewards contract as proxy
    it("stake: should stake 1000 tokens using mock rewards contract as proxy", async () =>{
        await token.approve(mockStakingProxyInstance.address, 1000, { from: accounts[0] });
        await mockStakingProxyInstance.stake(1000, { from: accounts[0] });
        let stakingBalance = await votingPowerInstance.totalStakedFor.call(accounts[0], {from: accounts[0]});
        assert.equal(stakingBalance.toNumber(), 1000, "1000 is not staked");
        
    });
/*
    it("creation: should fail when epoch is 0 ", async () =>{

        let threw = false
        try {
            voting = await VotingPower.new(token.address, "0x4B3219", 0);
        } catch (e) {
            threw = true
        }
        assert.equal(threw, true, "did not throw when deploying VotingPower with epoch = 0");

    });

    it("stake: should report correct staking token address", async () =>{
        const tokenAddress = token.address;
        let token_addr = await votingPowerInstance.token.call( {from: accounts[0]});
        assert.equal(tokenAddress, token_addr, "incorrect token address");
    });

    it("stake: should stake 1000 tokens in contract", async () =>{
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });
        let stakingBalance = await votingPowerInstance.totalStakedFor.call(accounts[0], {from: accounts[0]});
        assert.equal(stakingBalance.toNumber(), 1000, "1000 is not staked");
    });

    it("stake: should report voting power 1000 after 1000 tokens staked", async () =>{
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });
        let power = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        assert.equal(power.toNumber(), 1000, "1000 is not the votingPower");
    });

    it("stake: should report voting power 500 after staking 1000 and unstaking 500 tokens", async () =>{
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });
        await votingPowerInstance.unstake(500, { from: accounts[0] });

        let power = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        assert.equal(power.toNumber(), 500, "500 is not the votingPower");
    });

    it("stake: should revert if insufficient tokens to unstake", async () =>{
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });
        let threw = false
        try {
            await votingPowerInstance.unstake(1001, { from: accounts[0] });
        } catch (e) {
            threw = true
        }
        assert.equal(threw, true, "did not throw when unstaking too many tokens");
    });

    it("stake: cannot unstake 0 tokens", async () =>{
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });
        let threw = false
        try {
            await votingPowerInstance.unstake(0, { from: accounts[0] });
        } catch (e) {
            threw = true
        }
        assert.equal(threw, true, "did not throw when unstaking 0 tokens");
    });

    it("stake: cannot stake 0 tokens", async () =>{
        
        let threw = false
        try {
            await votingPowerInstance.stake.call(0, { from: accounts[1] })
        } catch (e) {
            threw = true
        }
        assert.equal(threw, true);
    });

    it("stake: should correctly report totalStaked from multiple accounts", async () =>{
        await token.transfer(accounts[1], 1000, { from: accounts[0] });
        //stake
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });
        let stakingBalance = await votingPowerInstance.totalStaked.call({from: accounts[0]});
        assert.equal(stakingBalance.toNumber(), 1000, "1000 is not the total staked");
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[1] });
        await votingPowerInstance.stake(1000, { from: accounts[1] });
        let stakingBalance2 = await votingPowerInstance.totalStaked.call({from: accounts[1]});
        assert.equal(stakingBalance2.toNumber(), 2000, "2000 is not the total staked");
        //unstake
        await votingPowerInstance.unstake(500, { from: accounts[0] });
        let stakingBalance3 = await votingPowerInstance.totalStaked.call({from: accounts[1]});
        assert.equal(stakingBalance3.toNumber(), 1500, "1500 is not the total staked");
    });

    it("locked: should compute correct discounted voting power for locked tokens during each epoch", async () =>{
        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power.toNumber());
        assert.equal(power.toNumber(), 750, "epoch 0: 750 is not the votingPower");

        await helper.advanceTimeAndBlock(1000);
        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power2 = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power2.toNumber());
        assert.equal(power2.toNumber(), 500, "epoch 1: 500 is not the votingPower");

        await helper.advanceTimeAndBlock(1000);
        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power3 = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power3.toNumber());
        assert.equal(power3.toNumber(), 250, "epoch 2: 250 is not the votingPower");

        await helper.advanceTimeAndBlock(1000);
        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power4 = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power4.toNumber());
        assert.equal(power4.toNumber(), 1000, "epoch 3: 1000 is not the votingPower");
    });

    it("staked-locked: should compute correct discounted voting power for staked & locked tokens during each epoch", async () =>{

        await token.approve(votingPowerInstance.address, 7, { from: accounts[0] });
        await votingPowerInstance.stake(7, { from: accounts[0] });
        let power0 = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power0.toNumber());
        assert.equal(power0.toNumber(), 7, "before locking: 7 is not the votingPower");

        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power.toNumber());
        assert.equal(power.toNumber(), 757, "epoch 0: 757 is not the votingPower");

        await helper.advanceTimeAndBlock(1000);
        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power2 = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power2.toNumber());
        assert.equal(power2.toNumber(), 507, "epoch 1: 507 is not the votingPower");

        await helper.advanceTimeAndBlock(1000);
        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power3 = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power3.toNumber());
        assert.equal(power3.toNumber(), 257, "epoch 2: 257 is not the votingPower");

        await helper.advanceTimeAndBlock(1000);
        await token.newTokenLock('1000', 10, 1000, { from: accounts[ 0 ] })
        let power4 = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        console.log(power4.toNumber());
        assert.equal(power4.toNumber(), 1007, "epoch 3: 1007 is not the votingPower");
    });

    //stake for self using mock rewards contract as proxy
    it("stake: should stake 1000 tokens using mock rewards contract as proxy", async () =>{
        await token.approve(mockStakingProxyInstance.address, 1000, { from: accounts[0] });
        await mockStakingProxyInstance.stake(1000, { from: accounts[0] });
        let stakingBalance = await votingPowerInstance.totalStakedFor.call(accounts[0], {from: accounts[0]});
        assert.equal(stakingBalance.toNumber(), 1000, "1000 is not staked");
        
    });

    //stake for other using mock rewards contract as proxy

    //voting power is correct when using mock rewards contract as proxy

    //unstake for self using mock rewards contract as proxy - returns tokens to self

    //unstake for other using mock rewards contract as proxy - returns tokens to other

    //only depositor / proxy may witdraw


    //voting power is correct when using mock rewards contract as proxy, direct staking, and locked tokens

    //stakeFor returns amount of tokens deposited by the ISTAKINGPROXY contract (= amount actually staked)
    //consider the case where the proxy contract returns the correct amount and a case where it does not.

    //it is possible for the staking proxy contract to bookkeep so that stakers can get rewards

    
    //test events

    it('events: stake should emit Staked event properly', async () => {
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        const res = await votingPowerInstance.stake(1000, { from: accounts[0] });        
        const log = res.logs.find(
          element => element.event.match('Staked') &&
            element.address.match(votingPowerInstance.address)
        )
        assert.strictEqual(log.args.staker, accounts[ 0 ])
        // in this case the user is staking on their own behalf so staker=proxy
        assert.strictEqual(log.args.proxy, accounts[ 0 ]) 
        assert.strictEqual(log.args.amount.toString(), '1000')
      })

      it('events: unstake should emit UnStaked event properly', async () => {
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });   
        const res = await votingPowerInstance.unstake(500, { from: accounts[0] });
     
        const log = res.logs.find(
          element => element.event.match('Unstaked') &&
            element.address.match(votingPowerInstance.address)
        )
        //when self-staking staker==proxy==recipient
        assert.strictEqual(log.args.staker, accounts[ 0 ])
        assert.strictEqual(log.args.proxy, accounts[ 0 ])
        assert.strictEqual(log.args.amount.toString(), '500')
        assert.strictEqual(log.args.recipient, accounts[ 0 ])
      })

      //stakeFor should emit Staked event with proxy contract as delegate

      //unStakeFor should emit Staked event with proxy contract as delegate
*/
})