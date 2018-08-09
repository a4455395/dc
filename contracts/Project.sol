pragma solidity ^0.4.24;

contract ParticipantManager {
    mapping(address => bool) public participants;
    address[] public participantArray;
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
        participantArray.push(_participant);
    }

    function deleteParticipant(address _participant) internal {
        participants[_participant] = false;
        participantAmount--;

        for(uint i = 0; i < participantArray.length; i++) {
            if(participantArray[i] == _participant) {
                removeParticipantInArray(i);
                break;
            }
        }
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

    function vote(uint index) public onlyParticipant {
        ParticipantRequest storage request = participantRequests[index];

        require(!request.voted[msg.sender]);

        request.approvalAmount++;
        request.voted[msg.sender] = true;
    }

    function removeParticipantInArray(uint index) internal {
        if (index >= participantArray.length) {
            return;
        }

        for (uint i = index; i < participantArray.length - 1; i++) {
            participantArray[i] = participantArray[i+1];
        }
        participantArray.length--;
    }
}

contract Project is ParticipantManager {

    address public productOwner;
    Sprint[] public sprints;
    SetShareRequest[] public shareRequests;

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
    }

    struct ParticipantShare {
        address participant;
        uint share;
    }

    struct SetShareRequest {
        uint sprintIndex;
        ParticipantShare[] participantShares;
        mapping(address => bool) approved;
        uint approvalAmount;
        bool finalized;
    }

    modifier onlyClient() {
        require(participants[msg.sender], "You aren't participant");
        _;
    }

    /// ---------------------------------------------
    /// -------------------PUBLIC--------------------
    /// ---------------------------------------------

    function createSprint(string name, uint reward) public onlyClient {
        require(address(this).balance >= reward, "Unsufficient funds");

        Sprint memory newSprintMemory = Sprint({
            name: name,
            createdAt: now,
            started: false,
            customerApproved: false,
            finalized: false,
            reward: reward
            });
        sprints.push(newSprintMemory);

        //if newSprint is not a first one, copy shares from previous;
        if(sprints.length > 1) {
            uint lastIndex = sprints.length - 1;
            copySprintShares(lastIndex - 1, lastIndex);
            //making equal shares
        } else {
            equalShares(sprints.length - 1);
        }
    }

    // possible to set share only for last sprint
    function createSetShareRequest(uint sprintIndex, uint[] shares)
    public onlyParticipant {
        require(sprintIndex < participantAmount);
        require(shares.length == participantAmount);
        uint totalShare;
        uint i;
        for(i = 0; i< shares.length; i++) {
            totalShare+=shares[i];
        }
        require(totalShare <= 100);
        ParticipantShare[] memory pShareArr;
        SetShareRequest memory newRequestMemory = SetShareRequest({
            sprintIndex: sprintIndex,
            approvalAmount: 0,
            finalized: false,
            participantShares: pShareArr
            });
        shareRequests.push(newRequest);
        SetShareRequest storage newRequest = shareRequests[shareRequests.length-1];
        ParticipantShare memory participantShare;
        for(i = 0; i < shares.length; i++) {
            participantShare = ParticipantShare({
                participant: participantArray[i],
                share: shares[i]
                });
            newRequest.participantShares.push(participantShare);
        }
    }

    function approveShareRequest(uint shareRequestIndex) public onlyParticipant {
        require(shareRequestIndex < shareRequests.length);
        SetShareRequest storage shareRequest = shareRequests[shareRequestIndex];
        require(!shareRequest.approved[msg.sender]);

        shareRequest.approvalAmount++;
        shareRequest.approved[msg.sender] = true;
    }

    function finalizeShareRequest(uint shareRequestIndex) public {
        SetShareRequest storage shareRequest = shareRequests[shareRequestIndex];
        require((shareRequest.approvalAmount / participantAmount) * 100 > 50);
        Sprint storage sprint = sprints[shareRequest.sprintIndex];
        for(uint i; i < shareRequest.participantShares.length; i++) {
            ParticipantShare storage pShare = shareRequest.participantShares[i];
            sprint.shares[pShare.participant] = pShare.share;
        }
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    /// ---------------------------------------------
    /// -------------------INTERNAL------------------
    /// ---------------------------------------------

    function copySprintShares(uint fromSprintIndex, uint toSprintIndex) internal {
        Sprint storage fromSprint = sprints[fromSprintIndex];
        Sprint storage toSprint = sprints[toSprintIndex];
        address participant;

        for(uint i = 0; i < participantArray.length; i++) {
            participant = participantArray[i];
            toSprint.shares[participant] = fromSprint.shares[participant];
        }
    }

    function equalShares(uint sprintIndex) internal {
        Sprint storage sprint = sprints[sprintIndex];
        address participant;
        uint equalShare = 100 / participantAmount;
        uint remainder = 100 - participantAmount * equalShare;
        for(uint i = 0; i < participantArray.length; i++) {
            participant = participantArray[i];
            sprint.shares[participant] = equalShare;
        }
        sprint.shares[participant] += remainder;
    }
}