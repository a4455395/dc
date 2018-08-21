const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = require('web3');
const web3 = new Web3(ganache.provider({gasLimit: 10000000}));

const {Project, ParticipantService} = require('../compile');

let accounts;
let participantService, project;
let client;

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


const approveShareRequest = async (index, address) => {
    await project.methods.approveShareRequest(index)
        .send({from: address, gas: '300000'});
};

describe('Share requests', () => {
    beforeEach(async () => {
        client = accounts[3];
        await web3.eth.sendTransaction({
            from: client,
            to: project.options.address,
            value: web3.utils.toWei('11', 'ether')
        });
        const reward =  web3.utils.toWei('11', 'ether');
        await createSprint(client, reward);
    });

    it('participant should can create valid shareRequest', async () => {
        await project.methods
            .createShareRequest(0, accounts.slice(0,3), [10,10,80])
            .send({from: accounts[0], gas: '3000000'});

        const shares = await project.methods.getShareRequestShares(0).call();
        const shareHolders = await project.methods.getShareRequestAddresses(0).call();
        assert.equal(shareHolders[0], accounts[0]);
        assert.equal(shares[0], 10);
    });

    it('participant should can approve share request', async () => {
        await project.methods
            .createShareRequest(0, accounts.slice(0,3), [10,10,80])
            .send({from: accounts[0], gas: '3000000'});

        await approveShareRequest(0, accounts[0]);
        await approveShareRequest(0, accounts[1]);

        const shareRequest = await project.methods.shareRequests(0).call();
        assert.equal(2, shareRequest.approvalAmount);
    });

    it('should can fanalize share request', async () => {
        await project.methods
            .createShareRequest(0, accounts.slice(0,3), [10,10,80])
            .send({from: accounts[0], gas: '3000000'});

        await approveShareRequest(0, accounts[0]);
        await approveShareRequest(0, accounts[1]);

        await project.methods.finalizeShareRequest(0)
            .send({from: accounts[0], gas: '3000000'});

        const share = await project.methods.getSprintShare(0, accounts[2]).call();
        assert.equal(share, 80);
    });
});



