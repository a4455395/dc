pragma solidity ^0.4.24;

import "./IParticipantService.sol";

contract ParticipantManager is IParticipantService {
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
            func: func,
            participantAddress: _address,
            approvalAmount: 0,
            complete: false
            });
        requests.push(newRequest);
    }

    function finalizeRequest(uint index) public {
        Request storage request = requests[index];

        require(!request.complete);
        require((request.approvalAmount / participantAmount) * 100 > 50);

        if(request.func == FunctionEnum.addParticipant) {
            addParticipant(request.participantAddress);
        }
        request.complete = true;
    }

    function approveParticipantRequest(uint index) public onlyParticipant {
        Request storage request = requests[index];

        require(!request.voted[msg.sender]);

        request.approvalAmount++;
        request.voted[msg.sender] = true;
    }
}