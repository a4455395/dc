pragma solidity ^0.4.24;

import "./IParticipantService.sol";
import "./ParticipantService.sol";

contract Project {
    address public productOwner;
    Sprint[] public sprints;
    ShareRequest[] public shareRequests;
    IParticipantService participantManager;

    mapping(address => uint) public balances;
    mapping(address => uint) public blockedBalance;

    function() payable public {
        balances[msg.sender] += msg.value;
    }

    constructor(address participantManagerAddress) public {
        participantManager = IParticipantService(participantManagerAddress);
    }

    /// ---------------------------------------------
    /// ------------STRUCTS & MODIFIERS--------------
    /// ---------------------------------------------

    modifier onlyParticipant() {
        require(participantManager.participants(msg.sender), "You aren't participant");
        _;
    }

    modifier sufficientFunds(uint amount) {
        require(balances[msg.sender] - blockedBalance[msg.sender] >= amount);
        _;
    }

    modifier onlyLastSprintClient() {
        Sprint storage sprint = sprints[sprints.length-1];
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
        require((shareRequest.approvalAmount / participantManager.participantAmount()) * 100 > 50);

        for(uint i; i < shareRequest.shareHolders.length; i++) {
            sprint.shares[shareRequest.shareHolders[i]] =
            shareRequest.shares[i];
        }
        sprint.shareHolders = shareRequest.shareHolders;
        shareRequest.finalized = true;
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
        require(sprints.length == 0 || sprints[sprints.length-1].finalized);
        address[] memory initArr;

        Sprint memory newSprint = Sprint({
            name: name,
            createdAt: now,
            started: false,
            customerApproved: false,
            finalized: false,
            reward: reward,
            shareHolders: initArr,
            client: msg.sender
            });
        sprints.push(newSprint);
    }

    function startSprint() public onlyLastSprintClient {
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
        lastSprint.finalized = true;
        address client = lastSprint.client;
        blockedBalance[client] -= totalReward;
        balances[client] -= totalReward;
    }

    function approveLastSprint() public onlyLastSprintClient {
        Sprint storage lastSprint  = sprints[sprints.length-1];
        require(!lastSprint.finalized);
        require(lastSprint.started);

        lastSprint.customerApproved = true;
    }

    function deleteLastSprint() public onlyLastSprintClient {
        Sprint storage lastSprint  = sprints[sprints.length-1];
        require(!lastSprint.started);
        delete sprints[sprints.length-1];
        sprints.length--;
    }

    function getShareValue(uint sprintIndex, address participant)
    public view returns(uint) {
        return sprints[sprintIndex].shares[participant];
    }

    /// ---------------------------------------------
    /// --------------------ELSE---------------------
    /// ---------------------------------------------

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    function withdraw(uint amount) public sufficientFunds(amount) {
        msg.sender.transfer(amount);
        address(balances[msg.sender]).transfer(amount);
    }


    uint public data;
    function setData(uint _data) public onlyParticipant {
        data = _data;
    }

}