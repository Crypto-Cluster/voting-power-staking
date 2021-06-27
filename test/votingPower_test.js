const VotingPower = artifacts.require("VotingPower");
const GovernanceToken = artifacts.require("OpenDeFiGovernance");
contract("VotingPower", accounts => {
    let token;
    let votingPowerInstance;
    const tokenName = "TestingToken";
    const tokenSymbol = 'OTT'
    beforeEach(async () => {
        // deploying token contract and send 10000 to the first account
        token = await GovernanceToken.new(tokenName, tokenSymbol, 10000, accounts[0]);
        votingPowerInstance = await VotingPower.new(token.address);
        
    });

    it("stake: should stake 1000 tokens in contract", async () =>{
        await votingPowerInstance.stake.call(1000, { from: accounts[0] })
        let stakingBalance = await votingPowerInstance.votingPower.call(accounts[0], {from: accounts[0]});
        assert.equal(stakingBalance.toNumber(), 1000, "1000 is not staked");
    });

    it("stake: stake 0, transaction should be reversed", async () =>{
        
        let threw = false
        try {
            await votingPowerInstance.stake.call(0, { from: accounts[1] })
        } catch (e) {
            threw = true
        }
        assert.equal(threw, true);
    });

})