pragma solidity ^0.4.24;

contract ParticipantManagerInterface {
    mapping(address => bool) public participants;
    uint public participantAmount;
}