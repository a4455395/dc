pragma solidity ^0.4.24;

contract ParticipantManager {
    mapping(address => bool) public participants;
    uint public participantAmount;
    ParticipantRequest[] public participantRequests;

    constructor() public {
        addParticipant(msg.sender);
    }

    enum ManageParticipantFunction {
        addParticipant,
        deleteParticipant
    }

    struct ParticipantRequest {
        ManageParticipantFunction func;
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

    function createPrticipantRequest(ManageParticipantFunction func, address _address)
    public onlyParticipant {
        ParticipantRequest memory newRequest = ParticipantRequest({
            func: func,
            participantAddress: _address,
            approvalAmount: 0,
            complete: false
            });
        participantRequests.push(newRequest);
    }

    function executeParticipantRequest(uint index) public {
        ParticipantRequest storage request = participantRequests[index];

        require(!request.complete);
        require((request.approvalAmount / participantAmount) * 100 > 50);

        if(request.func == ManageParticipantFunction.addParticipant) {
            addParticipant(request.participantAddress);
        }
        request.complete = true;
    }

    function approveParticipantRequest(uint index) public onlyParticipant {
        ParticipantRequest storage request = participantRequests[index];

        require(!request.voted[msg.sender]);

        request.approvalAmount++;
        request.voted[msg.sender] = true;
    }
}

contract Project is ParticipantManager {

    address public productOwner;
    Sprint[] public sprints;
    ShareRequest[] public shareRequests;

    constructor(address _productOwner) public {
        productOwner = _productOwner;
    }

    function() payable public {  }

    /// ---------------------------------------------
    /// ------------STRUCTS & MODIFIERS--------------
    /// ---------------------------------------------

    struct Sprint {
        string name;
        uint createdAt;
        bool customerApproved;
        bool started;
        bool finalized;
        //shares in persantage 1-100% because in current version
        // float type wasn't implemented
        mapping(address => uint) shares;
        uint reward;
        address[] shareHolders;
    }

    //for every share holder it is his share with the same index
    struct ShareRequest {
        uint sprintIndex;
        address[] shareHolders;
        uint[] shares;
        mapping(address => bool) approved;
        uint approvalAmount;
        bool finalized;
    }

    modifier onlyClient() {
        require(productOwner == msg.sender, "You aren't participant");
        _;
    }

    /// ---------------------------------------------
    /// -------------------PUBLIC--------------------
    /// ---------------------------------------------

    function createSprint(string name, uint reward) public onlyClient {
        require(address(this).balance >= reward, "Unsufficient funds");
        require(sprints.length == 0 || sprints[sprints.length-1].finalized);
        address[] memory initArr;

        Sprint memory newSprint = Sprint({
            name: name,
            createdAt: now,
            started: false,
            customerApproved: false,
            finalized: false,
            reward: reward,
            shareHolders: initArr
            });
        sprints.push(newSprint);
    }

    function getShareValue(uint sprintIndex, address participant)
    public view returns(uint) {
        return sprints[sprintIndex].shares[participant];
    }

    // possible to set share only for last sprint
    function createShareRequest(
        uint sprintIndex,
        address[] shareHolders,
        uint[] shares
    ) public onlyParticipant {

        require(sprintIndex < sprints.length);
        require(shareHolders.length == shares.length);

        uint totalShare;
        uint i;
        for(i = 0; i< shares.length; i++) {
            totalShare+=shares[i];
        }
        require(totalShare <= 100);

        ShareRequest memory newRequest = ShareRequest({
            sprintIndex: sprintIndex,
            approvalAmount: 0,
            finalized: false,
            shareHolders: shareHolders,
            shares: shares
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
        require((shareRequest.approvalAmount / participantAmount) * 100 > 50);

        for(uint i; i < shareRequest.shareHolders.length; i++) {
            sprint.shares[shareRequest.shareHolders[i]] =
            shareRequest.shares[i];
        }
        sprint.shareHolders = shareRequest.shareHolders;
        shareRequest.finalized = true;
    }

    function startSprint() public onlyClient {
        Sprint storage lastSprint  = sprints[sprints.length-1];
        require(lastSprint.shareHolders.length > 0,
            "Team members haven't voted for shares yet");
        require(!lastSprint.started);

        lastSprint.started = true;
    }

    function finalizeSprint() public {
        Sprint storage lastSprint  = sprints[sprints.length-1];
        require(!lastSprint.finalized);
        require(lastSprint.customerApproved);
        uint share;
        address recipient;
        uint reward;
        uint totalReward = lastSprint.reward;
        for(uint i=0; i < lastSprint.shareHolders.length; i++) {
            recipient = lastSprint.shareHolders[i];
            share = lastSprint.shares[recipient];
            reward = (totalReward / 100) * share;
            recipient.transfer(reward);
        }
    }

    function approveLastSprint() public onlyClient {
        Sprint storage lastSprint  = sprints[sprints.length-1];
        require(!lastSprint.finalized);
        require(lastSprint.started);

        lastSprint.customerApproved = true;
    }

    function deleteLastSprint() public onlyClient {
        Sprint storage lastSprint  = sprints[sprints.length-1];
        require(!lastSprint.started);
        delete sprints[sprints.length-1];
        sprints.length--;
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }
}