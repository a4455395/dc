pragma solidity ^0.4.24;

contract IParticipantService {
    mapping(address => bool) public participants;
    uint public participantAmount;
}