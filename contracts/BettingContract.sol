pragma solidity ^0.8.0;

import "./Referrals.sol";

contract BettingContract{
    uint8 MATCH_FEE = 10;
    uint8 REFERRAL_FEE = 5;

    address payable public Owner;

    enum MatchStatus {NOT_STARTED, STARTED, CLOSED}
    MatchStatus public matchStatus = MatchStatus.NOT_STARTED;

    Referrals public ReferralModule;

    struct betDetails{
        uint256 amount;
        uint8 teamId;
    }

    struct teamDetails{
        uint8 teamId;
        bool winner;
    }

    mapping (address => betDetails) public UserDetails;
    mapping (string => teamDetails) public teamIds;
    mapping (uint8 => uint256) public amountOnTeam;
    mapping (uint8 => string) public teamIdToName;
    mapping (address => uint256) public referrerContribution;

    constructor (string memory _teamA, string memory _teamB, address referralContractAddress){
        Owner = payable(msg.sender);
        teamIdToName[1] = _teamA;
        teamIdToName[2] = _teamB;
        teamIds[_teamA] = teamDetails({teamId : 1, winner : false});
        teamIds[_teamB] = teamDetails({teamId : 2, winner : false});
        ReferralModule = Referrals(referralContractAddress);
    }

    modifier onlyOwner(){
        require(msg.sender == Owner);
        _;
    }

    function startMatch() public onlyOwner returns(bool){
        require(matchStatus == MatchStatus.NOT_STARTED, "Match has already Started");
        matchStatus = MatchStatus.STARTED;
        if (amountOnTeam[1] == 0){
            CloseBet(teamIdToName[2]);
        } else if (amountOnTeam[2] == 0){
            CloseBet(teamIdToName[1]);
        }
        return true;
    }

    function Bet(string memory team) public payable returns(bool){
        require(matchStatus == MatchStatus.NOT_STARTED, "Match has already started");
        betDetails memory userRecord = UserDetails[msg.sender];
        uint8 teamId = teamIds[team].teamId;
        require(userRecord.amount == 0, "You have already Invested");
        require(teamId != 0, "Team Doesn't Exist");
        // require(getRatio() > 3e17 || getRatio() < 3e18, "Bet is not Balanced, Wait for time and Invest");

        userRecord.amount = msg.value;
        userRecord.teamId = teamId;
        amountOnTeam[teamId] += msg.value;

        UserDetails[msg.sender] = userRecord;

        address referrer = ReferralModule.getReferral(msg.sender);

        if (referrer != address(0)){
            referrerContribution[referrer] += msg.value;
        }

        return true;
    }

    function CloseBet(string memory _winner) public onlyOwner returns(bool){
        require(matchStatus == MatchStatus.STARTED, "Match Isn't Started Yet");
        require(teamIds[_winner].teamId != 0, "Team Doesn't exist in Bet");
        teamIds[_winner].winner = true;
        matchStatus = MatchStatus.CLOSED;
        if (amountOnTeam[1] != 0 && amountOnTeam[2] != 0){
            if (teamIds[_winner].teamId == 1){
                Owner.transfer(amountOnTeam[2]*MATCH_FEE/1e2);
            } else {
                Owner.transfer(amountOnTeam[1]*MATCH_FEE/1e2);
            }
        }
        return true;
    }

    function showAmountToWithdraw(address userAddr) view public returns(uint256){
        require(matchStatus == MatchStatus.CLOSED, "Match Isn't Completed Yet");

        betDetails memory userRecord = UserDetails[userAddr];
        teamDetails memory teamRecord = teamIds[teamIdToName[userRecord.teamId]];

        if (teamRecord.winner){
            if (amountOnTeam[1] == 0 || amountOnTeam[2] == 0){
                return userRecord.amount;
            } else {
                if (userRecord.teamId + 1 == 2){
                    return userRecord.amount + (userRecord.amount*(amountOnTeam[2]*(100-MATCH_FEE-REFERRAL_FEE)*1e18/amountOnTeam[1]))/1e20;
                } else {
                    return userRecord.amount + (userRecord.amount*(amountOnTeam[1]*(100-MATCH_FEE-REFERRAL_FEE)*1e18/amountOnTeam[2]))/1e20;
                }
            }
        } else {
            return 0;
        }
    }

    function Withdraw() public payable returns(bool){
        require(matchStatus == MatchStatus.CLOSED, "Match Isn't Completed Yet");
        uint256 amountToWithdraw = showAmountToWithdraw(msg.sender);
        payable(msg.sender).transfer(amountToWithdraw);
        return true;
    }

    function getRatio() public view returns(uint256){
        if (amountOnTeam[1] == 0 && amountOnTeam[2] == 0){
            return 1e18;
        }
        return (amountOnTeam[1]*1e18/amountOnTeam[2]); // avoid overflow
    }

    function showAmountToReferrer(address referrer) public view returns(uint256){
        require(matchStatus == MatchStatus.CLOSED, "Match Isn't Completed Yet");
        require(referrerContribution[msg.sender] > 0, "Sorry, your referrals haven't participated in Match");
        require(amountOnTeam[1] > 0 && amountOnTeam[2] > 0, "Match is been closed due to Imbalanced pool");

        // percentage upto 2 decimals. ex - 6969
        uint256 referralPercent = referrerContribution[referrer]*1e4/(amountOnTeam[1] + amountOnTeam[2]);
        if (teamIds[teamIdToName[1]].winner){
            return referralPercent*amountOnTeam[2]*REFERRAL_FEE/1e6;
        } else {
            return referralPercent*amountOnTeam[1]*REFERRAL_FEE/1e6;
        }
    }
    
    function getReferralFee() public payable returns(bool){
        uint256 referrerCommition = showAmountToReferrer(msg.sender);
        if (referrerCommition > 0){
            payable(msg.sender).transfer(referrerCommition);
            return true;
        }
        return false;
    }

    function getBalance() public view returns(uint256){
        return address(this).balance;
    }
}