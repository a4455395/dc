const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = require('web3');
const web3 = new Web3(ganache.provider({gasLimit: 10000000}));

const {ParticipantService} = require('../compile');

let accounts;
let participantService;

const addParticipant = async (participantService, currentP, newP) => {
    await new web3.eth.Contract(JSON.parse(ParticipantService.interface))
        .deploy({ data: ParticipantService.bytecode, arguments: [] })
        .send({from: accounts[0], gas: '3000000'});
    await participantService.methods.createRequest(0, newP,)
        .send({from: currentP[0], gas: '1000000'});
    let index = await participantService.methods.participantAmount().call();
    index--;
    currentP.forEach(async p => {
        await participantService.methods.approveRequest(index)
            .send({from: p, gas: '3000000'});
    });

    await participantService.methods.finalizeRequest(index)
        .send({from: currentP[0], gas: '3000000'});
};

const add2Participants = async participantService => {
    await  addParticipant(participantService, accounts.slice(0,1), accounts[1]);
    await  addParticipant(participantService, accounts.slice(0,2), accounts[2]);
};

beforeEach(async () => {
    // Get a list of all accounts
    accounts = await web3.eth.getAccounts();

    participantService = await new web3.eth.Contract(JSON.parse(ParticipantService.interface))
        .deploy({ data: ParticipantService.bytecode, arguments: [] })
        .send({from: accounts[0], gas: '3000000'});

});

describe('Project', () => {

    it('contracts deployed successfully', async () => {
        assert.ok(participantService.options.address);
    });

    it('should add participant', async () => {
        const startAmount = await participantService.methods.participantAmount().call();
        await  addParticipant(participantService, [accounts[0]], accounts[1]);
        const endAmount = await participantService.methods.participantAmount().call();
        assert.equal(+startAmount + 1, endAmount);
    });

});