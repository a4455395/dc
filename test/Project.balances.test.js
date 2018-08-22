const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = require('web3');
const web3 = new Web3(ganache.provider({gasLimit: 100000000}));

const {Project, ParticipantService} = require('../compile');

let accounts;
let participantService, project;
let client;
let rewardInWei = web3.utils.toWei('11', 'ether');

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

const createSprint = async (client, reward) => {
    await project.methods
        .createSprint('First sprint', reward)
        .send({from: client, gas: '3000000'});
};

beforeEach(async () => {
    // Get a list of all accounts
    accounts = await web3.eth.getAccounts();

    participantService = await new web3.eth.Contract(JSON.parse(ParticipantService.interface))
        .deploy({ data: ParticipantService.bytecode, arguments: [] })
        .send({from: accounts[0], gas: '3000000'});


    project = await new web3.eth.Contract(JSON.parse(Project.interface))
        .deploy({ data: Project.bytecode, arguments: [participantService.options.address] })
        .send({from: accounts[0], gas: '3000000'});

    //creating participants
    await  addParticipant(participantService, accounts.slice(0,1), accounts[1]);
    await  addParticipant(participantService, accounts.slice(0,2), accounts[2]);

    client = accounts[3];
});

describe('Balances', () => {

    beforeEach(async () => {
        await web3.eth.sendTransaction({
            from: client,
            to: project.options.address,
            value: rewardInWei
        });
    });

    it('contract should have balance', async () => {
        const balance = await project.methods.getBalance().call();
        assert.equal(balance, rewardInWei);
    });

    it('client should have balance', async () => {
        const balance = await project.methods.balances(client).call();
        assert.equal(balance, rewardInWei);
    });

    it('client should can creating sprint with sufficient funds', async () => {
        await createSprint(client, rewardInWei);

        const sprint = await project.methods.sprints(0).call();
        assert.equal(sprint.name, 'First sprint');
        assert.equal(sprint.reward, rewardInWei);
    });

    it('should fail while while creating sprint with insufficient funds', async () => {
        try {
            const reward =  web3.utils.toWei('12', 'ether');
            await createSprint(client, reward);
            assert(false);
        } catch (e) {
            assert(true);
        }
    });
});
