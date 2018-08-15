const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = require('web3');
const web3 = new Web3(ganache.provider({gasLimit: 10000000}));

const {Project, ParticipantService} = require('../compile');

let accounts;
let participantService, project;

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


    project = await new web3.eth.Contract(JSON.parse(Project.interface))
        .deploy({ data: Project.bytecode, arguments: [participantService.options.address] })
        .send({from: accounts[0], gas: '3000000'});

    //creating participants
    await add2Participants(participantService);

});

describe('Project', () => {

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

// describe('Basic mediator functionality', () => {
//
//     it('contracts have deployed correctly', async () => {
//         const xidAddress = await mediator.methods.xidAddress().call();
//         assert.equal(xid.options.address, xidAddress);
//     });
//
//     it('mediator contract should have correct balance of XID', async () => {
//         const balance = await mediator.methods.myBalance().call();
//         assert.equal(balance, replenishAmount);
//     });
//
//     it('should create allowance for amount which not exceed mediator\s balance', async () => {
//         const tokensSent = 10;
//         await mediator.methods.approve(accounts[1], tokensSent)
//             .send({from: accounts[0], gas: '1000000'});
//         assert.equal(await mediator.methods.allowance(accounts[1]).call(), tokensSent);
//     });
//
// });