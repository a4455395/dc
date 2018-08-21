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

    // it('should add participant', async () => {
    //     const startAmount = await participantService.methods.participantAmount().call();
    //     await  addParticipant(participantService, [accounts[0]], accounts[1]);
    //     const endAmount = await participantService.methods.participantAmount().call();
    //     assert.equal(+startAmount + 1, endAmount);
    // });

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
            .startSprint()
            .send({from: client, gas: '3000000'});

        const sprint  = await project.methods.sprints(0).call();
        assert.ok(sprint.started);
    });

    it('client should be able to approve sprint', async () => {
        await project.methods
            .startSprint()
            .send({from: client, gas: '3000000'});

        await project.methods
            .approveLastSprint()
            .send({from: client, gas: '3000000'});

        const sprint  = await project.methods.sprints(0).call();
        assert.ok(sprint.customerApproved);
    });

    it('should finalize sprint', async () => {
        const initBalanceAccount2 = await web3.eth.getBalance(accounts[2]);
        await project.methods
            .startSprint()
            .send({from: client, gas: '3000000'});

        await project.methods
            .approveLastSprint()
            .send({from: client, gas: '3000000'});

        await project.methods
            .finalizeSprint()
            .send({from: accounts[0], gas: '30000000'});

        const resBalanceAccount2 = await web3.eth.getBalance(accounts[2]);

        let participantBalances = [
            await web3.eth.getBalance(accounts[0]),
            await web3.eth.getBalance(accounts[1]),
            await web3.eth.getBalance(accounts[2])
        ];

        participantBalances = participantBalances.map(b => web3.utils.fromWei(b, 'ether'));
        console.log(participantBalances);

        assert.ok(resBalanceAccount2 - initBalanceAccount2 === +rewardInWei * 0.8);
    });
});