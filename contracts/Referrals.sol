pragma solidity ^0.8.0;

contract Referrals{
    mapping (address => address[]) public referralDump;
    mapping (address => address) public referralTracker;

    address public Owner;

    constructor (){
        Owner = msg.sender;
    }

    modifier onlyOwner(){
        require(msg.sender == Owner);
        _;
    }

    function addReferral(address referrer, address referred) public onlyOwner returns(bool){
        require(referralTracker[referred] == address(0), "already been referred");
        referralDump[referrer].push(referred);
        referralTracker[referred] = referrer; 
        return true;
    }

    function getReferral(address referred) public view returns(address){
        return referralTracker[referred];
    }

    function transferOwner(address newOwner) public onlyOwner returns(bool){
        Owner = newOwner;
        return true;
    }
}