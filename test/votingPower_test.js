//https://github.com/ejwessel/GanacheTimeTraveler
const helper = require('./utils.js');

const VotingPower = artifacts.require("VotingPower");
const GovernanceToken = artifacts.require("OpenDeFiGovernance");

contract("VotingPower", accounts => {
    let token;
    let votingPowerInstance;
    const tokenName = "TestingToken";
    const tokenSymbol = 'OTT'
    beforeEach(async () => {
        snapShot = await helper.takeSnapshot();
        snapshotId = snapShot['result'];
        // deploying token contract and send 10000 to the first account
        token = await GovernanceToken.new(tokenName, tokenSymbol, 10000, accounts[0]);
        //75, 50, 25, 0
        votingPowerInstance = await VotingPower.new(token.address, "0x4B3219", 1000);
        
    });

    afterEach(async() => {
        await helper.revertToSnapshot(snapshotId);
    });

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
        let stakingBalance = await votingPowerInstance.totalStakedBy.call(accounts[0], {from: accounts[0]});
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

    //extension
    it("extension: should display the correct timestamp of last activity", async () =>{

        await token.approve(votingPowerInstance.address, 7, { from: accounts[0] });
        await votingPowerInstance.stake(7, { from: accounts[0] });

        let block = await web3.eth.getBlock('latest')
        let time = block['timestamp']
        console.log(time.toString());
        let timestamp = await votingPowerInstance.timestamp.call(accounts[0]);
        console.log(timestamp.toString());
        assert.strictEqual(timestamp.toString(), time.toString(), "timestamp not stored when staking");


        await votingPowerInstance.unstake(3, { from: accounts[0] });

        let block2 = await web3.eth.getBlock('latest')
        let time2 = block['timestamp']
        console.log(time2.toString());
        let timestamp2 = await votingPowerInstance.timestamp.call(accounts[0]);
        console.log(timestamp2.toString());
        assert.strictEqual(timestamp2.toString(), time2.toString(), "timestamp not stored when unstaking");

    });
    //test events

    it('events: should emit Staked event properly', async () => {
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        const res = await votingPowerInstance.stake(1000, { from: accounts[0] });        
        const log = res.logs.find(
          element => element.event.match('Staked') &&
            element.address.match(votingPowerInstance.address)
        )
        assert.strictEqual(log.args.user, accounts[ 0 ])
        assert.strictEqual(log.args.amount.toString(), '1000')
      })

      it('events: should emit UnStaked event properly', async () => {
        await token.approve(votingPowerInstance.address, 1000, { from: accounts[0] });
        await votingPowerInstance.stake(1000, { from: accounts[0] });   
        const res = await votingPowerInstance.unstake(500, { from: accounts[0] });
     
        const log = res.logs.find(
          element => element.event.match('Unstaked') &&
            element.address.match(votingPowerInstance.address)
        )
        assert.strictEqual(log.args.user, accounts[ 0 ])
        assert.strictEqual(log.args.amount.toString(), '500')
      })

})