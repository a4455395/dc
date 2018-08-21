pragma solidity ^0.4.24;

contract IParticipantService {
    mapping(address => bool) public participants;
    uint public participantAmount;
}

contract ParticipantService is IParticipantService {
    Request[] public requests;

    constructor() public {
        addParticipant(msg.sender);
    }

    enum FunctionEnum {
        addParticipant,
        deleteParticipant
    }

    struct Request {
        FunctionEnum func;
        address participantAddress;
        uint approvalAmount;
        bool complete;
        mapping(address => bool) voted;
    }

    modifier onlyParticipant() {
        require(participants[msg.sender], "You aren't participant");
        _;
    }

    function addParticipant(address _participant) internal {
        participants[_participant] = true;
        participantAmount++;
    }

    function deleteParticipant(address _participant) internal {
        participants[_participant] = false;
        participantAmount--;
    }

    function createRequest(FunctionEnum func, address _address)
    public onlyParticipant {
        Request memory newRequest = Request({
            func : func,
            participantAddress : _address,
            approvalAmount : 0,
            complete : false
            });
        requests.push(newRequest);
    }

    function finalizeRequest(uint index) public {
        Request storage request = requests[index];

        require(!request.complete);
        require((uint(request.approvalAmount * 100) / participantAmount) > 50);

        if (request.func == FunctionEnum.addParticipant) {
            addParticipant(request.participantAddress);
        }
        request.complete = true;
    }

    function approveRequest(uint index) public onlyParticipant {
        Request storage request = requests[index];

        require(!request.voted[msg.sender]);

        request.approvalAmount++;
        request.voted[msg.sender] = true;
    }
}

contract Project {
    address public productOwner;
    Sprint[] public sprints;
    ShareRequest[] public shareRequests;
    IParticipantService public participantService;

    mapping(address => uint) public balances;
    mapping(address => uint) public blockedBalance;

    function() payable public {
        balances[msg.sender] += msg.value;
    }

    constructor(address participantServiceAddress) public {
        participantService = IParticipantService(participantServiceAddress);
    }

    /// ---------------------------------------------
    /// ------------STRUCTS & MODIFIERS--------------
    /// ---------------------------------------------

    modifier onlyParticipant() {
        require(participantService.participants(msg.sender), "You aren't participant");
        _;
    }

    modifier sufficientFunds(uint amount) {
        require(balances[msg.sender] - blockedBalance[msg.sender] >= amount);
        _;
    }

    modifier onlyLastSprintClient() {
        Sprint storage sprint = sprints[sprints.length - 1];
        require(msg.sender == sprint.client);
        _;
    }

    /// ---------------------------------------------
    /// ---------------SHARE REQUESTS----------------
    /// ---------------------------------------------

    //for every share holder it is his share with the same index
    struct ShareRequest {
        uint sprintIndex;
        address[] shareHolders;
        uint[] shares;
        mapping(address => bool) approved;
        uint approvalAmount;
        bool finalized;
    }

    // possible to set share only for last sprint
    function createShareRequest(
        uint sprintIndex,
        address[] shareHolders,
        uint[] shares
    ) public onlyParticipant {

        require(sprintIndex < sprints.length);
        require(!sprints[sprintIndex].started);
        require(shareHolders.length == shares.length);

        uint totalShare;
        uint i;
        for (i = 0; i < shares.length; i++) {
            totalShare += shares[i];
        }
        require(totalShare <= 100);

        ShareRequest memory newRequest = ShareRequest({
            sprintIndex : sprintIndex,
            approvalAmount : 0,
            finalized : false,
            shareHolders : shareHolders,
            shares : shares
            });
        shareRequests.push(newRequest);
    }

    function approveShareRequest(uint shareRequestIndex) public onlyParticipant {
        require(shareRequestIndex < shareRequests.length);
        ShareRequest storage shareRequest = shareRequests[shareRequestIndex];
        require(!shareRequest.approved[msg.sender]);

        shareRequest.approvalAmount++;
        shareRequest.approved[msg.sender] = true;
    }

    function finalizeShareRequest(uint shareRequestIndex) public {
        ShareRequest storage shareRequest = shareRequests[shareRequestIndex];
        Sprint storage sprint = sprints[shareRequest.sprintIndex];

        require(!sprint.started);
        require(!shareRequest.finalized);
        require(uint(shareRequest.approvalAmount * 100) / participantService.participantAmount() > 50);

        for (uint i; i < shareRequest.shareHolders.length; i++) {
            sprint.shares[shareRequest.shareHolders[i]] =
            shareRequest.shares[i];
        }
        sprint.shareHolders = shareRequest.shareHolders;
        shareRequest.finalized = true;
    }

    function getShareRequestShares(uint shareRequestIndex)
    public view returns (uint[]) {
        return shareRequests[shareRequestIndex].shares;
    }

    function getShareRequestAddresses(uint shareRequestIndex)
    public view returns (address[]) {
        return shareRequests[shareRequestIndex].shareHolders;
    }

    /// ---------------------------------------------
    /// -------------------SPRINT--------------------
    /// ---------------------------------------------

    struct Sprint {
        string name;
        uint createdAt;
        address client;
        bool customerApproved;
        bool started;
        bool finalized;
        //shares in persantage 1-100% because in current version
        // float type wasn't implemented
        mapping(address => uint) shares;
        uint reward;
        address[] shareHolders;
    }

    function createSprint(string name, uint reward) public
    sufficientFunds(reward) {
        require(sprints.length == 0 || sprints[sprints.length - 1].finalized);
        address[] memory initArr;

        Sprint memory newSprint = Sprint({
            name : name,
            createdAt : now,
            started : false,
            customerApproved : false,
            finalized : false,
            reward : reward,
            shareHolders : initArr,
            client : msg.sender
            });
        sprints.push(newSprint);
    }

    function startSprint() public onlyLastSprintClient sufficientFunds(sprints[sprints.length - 1].reward) {
        Sprint storage lastSprint = sprints[sprints.length - 1];
        require(lastSprint.shareHolders.length > 0,
            "Team members haven't voted for shares yet");
        require(!lastSprint.started);

        lastSprint.started = true;
        blockedBalance[lastSprint.client] += lastSprint.reward;
    }

    function finalizeSprint() public {
        Sprint storage lastSprint = sprints[sprints.length - 1];
        require(!lastSprint.finalized);
        require(lastSprint.customerApproved);
        uint share;
        address recipient;
        uint reward;
        uint totalReward = lastSprint.reward;
        for (uint i = 0; i < lastSprint.shareHolders.length; i++) {
            recipient = lastSprint.shareHolders[i];
            share = lastSprint.shares[recipient];
            reward = (totalReward / 100) * share;
            recipient.transfer(reward);
        }
        lastSprint.finalized = true;
        address client = lastSprint.client;
        blockedBalance[client] -= totalReward;
        balances[client] -= totalReward;
    }

    function approveLastSprint() public onlyLastSprintClient {
        Sprint storage lastSprint = sprints[sprints.length - 1];
        require(!lastSprint.finalized);
        require(lastSprint.started);

        lastSprint.customerApproved = true;
    }

    function deleteLastSprint() public onlyLastSprintClient {
        Sprint storage lastSprint = sprints[sprints.length - 1];
        require(!lastSprint.started);
        delete sprints[sprints.length - 1];
        sprints.length--;
    }

    function getSprintShare(uint sprintIndex, address participant)
    public view returns (uint) {
        return sprints[sprintIndex].shares[participant];
    }

    /// ---------------------------------------------
    /// --------------------ELSE---------------------
    /// ---------------------------------------------

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdraw(uint amount) public sufficientFunds(amount) {
        msg.sender.transfer(amount);
        address(balances[msg.sender]).transfer(amount);
    }
}