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

const add2Participants = async participantService => {
    await  addParticipant(participantService, accounts.slice(0,1), accounts[1]);
    await  addParticipant(participantService, accounts.slice(0,2), accounts[2]);
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
    await add2Participants(participantService);

    client = accounts[3];
});

describe('Deployment check', () => {

    it('contracts deployed successfully', async () => {
        const pSAdress = await project.methods.participantService().call();
        assert.equal(pSAdress, participantService.options.address);
    });
});

const approveShareRequest = async (index, address) => {
    await project.methods.approveShareRequest(index)
        .send({from: address, gas: '300000'});
};

describe('Sprints', () => {
    beforeEach(async () => {
        await web3.eth.sendTransaction({
            from: client,
            to: project.options.address,
            value: rewardInWei
        });
        await createSprint(client, rewardInWei);

        await project.methods
            .createShareRequest(0, accounts.slice(0,3), [10,10,80])
            .send({from: accounts[0], gas: '3000000'});

        await approveShareRequest(0, accounts[0]);
        await approveShareRequest(0, accounts[1]);

        await project.methods.finalizeShareRequest(0)
            .send({from: accounts[0], gas: '3000000'});
    });

    it('client should be able to start sprint', async () => {
        await project.methods
            .startSprint(0)
            .send({from: client, gas: '3000000'});

        const sprint  = await project.methods.sprints(0).call();
        assert.ok(sprint.started);
    });

    it('client should be able to approve sprint', async () => {
        await project.methods
            .startSprint(0)
            .send({from: client, gas: '3000000'});

        await project.methods
            .approveSprint(0)
            .send({from: client, gas: '3000000'});

        const sprint  = await project.methods.sprints(0).call();
        assert.ok(sprint.approved);
    });

    it('should finalize sprint', async () => {
        const initBalanceAccount2 = await web3.eth.getBalance(accounts[2]);
        await project.methods
            .startSprint(0)
            .send({from: client, gas: '3000000'});

        await project.methods
            .approveSprint(0)
            .send({from: client, gas: '3000000'});

        await project.methods
            .finalizeSprint(0)
            .send({from: accounts[0], gas: '30000000'});

        const resBalanceAccount2 = await web3.eth.getBalance(accounts[2]);

        const pendings = accounts.slice(0,3)
            .map(async account => {
                const inWei =  await web3.eth.getBalance(account);
                return web3.utils.fromWei(inWei, 'ether')
            });

        const participantBalances = await Promise.all(pendings);
        console.log(participantBalances);

        assert.ok(resBalanceAccount2 - initBalanceAccount2 === +rewardInWei * 0.8);
    });
});