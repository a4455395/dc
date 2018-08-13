pragma solidity ^0.4.24;

import "./ParticipantManagerInterface.sol";

contract ParticipantManager is ParticipantManagerInterface {
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