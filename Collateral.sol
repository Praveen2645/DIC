// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// import "../../artifacts/@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "Icollateral.sol";


contract Collateral is Ownable {

    address EmiDeposit;
//    uint256 constant THIRTY_DAY_EPOCH = 2629743; // number of seconds in thirty days
//    uint256 constant CUSHION_PERIOD = 5 days;
    uint256 constant ONE_MINUTE = 60;
    uint256 constant CUSHION_PERIOD = 60 seconds;
    uint256 Penalty = 1; //penalty paid by the borrower for late payment, in % per day

    receive() external payable {}


    mapping(uint256 itemNumber => ICollateral.Proposal[]) public itemNumberToProposals;
    mapping(uint256 itemNumber => ICollateral.Item) public ItemNumberToItem;

    modifier onlyBorrower(uint256 _itemNum) {
        require(
            ItemNumberToItem[_itemNum].borrower == msg.sender,
            "Not Borrower"
        );
        _;
    }

//this function sets the contract address of the TransferEmi contract
    function setTransferEmi(address _address) external onlyOwner{
        EmiDeposit =_address;
    }

//this function helps to set the proposals 
    function setProposal(ICollateral.ItemDetails memory itemDetails) external onlyOwner{
        require(
            ItemNumberToItem[itemDetails.tokenId].EstimatedValue == 0,
            "Invalid Id"
        );

        ICollateral.Item memory item = ICollateral.Item(
            itemDetails.EstimatedValue,
            itemDetails.loanValue,
            itemDetails.minRangeLoanDuration,
            itemDetails.maxRangeLoanDuration,
            itemDetails.minRangeInterestRate,
            itemDetails.maxRangeInterestRate,
            itemDetails.EstimatedValue,
            0,
            0,
            0,
            itemDetails.borrower
        );
        ItemNumberToItem[itemDetails.tokenId] = item;
    }
  

// this function helps the investors to offer proposals for the proposal
    function investorOffersProposal(
        uint256 _itemNum,
        uint256 _interestRate,
        uint256 _duration
    ) external payable {
        ICollateral.Item storage item = ItemNumberToItem[_itemNum];
        require(
            item.EstimatedValue != 0,
            "Invalid Item Num"
        );
        require(
            msg.value > 0 && msg.value <= item.EstimatedValue,
            "Invalid Amount"
        );
        require(
            _interestRate > 0 &&
                _interestRate >= item.minRangeInterestRate &&
                _interestRate <= item.maxRangeInterestRate,
            "Invalid Interest Rate"
        );
        require(
            _duration >= item.minRangeLoanDuration &&
                _duration <= item.maxRangeLoanDuration,
            "Invalid Duration"
        );

        ICollateral.Proposal memory proposal = ICollateral.Proposal(
            _itemNum,
            msg.value,
            _interestRate,
            _duration, 
            0,
            msg.sender,
            false,
            true
        );
        // uint256 index = itemNumberToProposals[_itemNum].length;
        itemNumberToProposals[_itemNum].push(proposal);
    }

//this funciton helps the borrower to approves the proposals offer by the investors
    function approveProposal(
        uint256 _itemNum,
        uint256 _proposalNum
    ) external onlyBorrower(_itemNum) returns (bool) {
        ICollateral.Item storage item = ItemNumberToItem[_itemNum];
        require(
            _proposalNum < itemNumberToProposals[_itemNum].length,
            "Invalid Proposal"
        );

        ICollateral.Proposal storage proposal = itemNumberToProposals[_itemNum][
            _proposalNum
        ];
        require(
            item.remainingAmount >= proposal.amount,
            "you reached to your borrowing limit"
        );
        require(
            !proposal.approved,
            "Already Approved"
        );
        item.remainingAmount -= proposal.amount;
        
        proposal.approved = true;
        item.EmiDate = block.timestamp + ONE_MINUTE;
        return true;
    }

//this function helps to set the Emi Amount
    function setEmiAmount(uint _amount, uint _item) external {
        ItemNumberToItem[_item].EmiAmount = _amount;
    }


// this function calculate the monthly emi 
    function calculateMonthlyEmi(uint256 _itemNum) public view returns (uint256) {
        ICollateral.Proposal[] memory proposals = itemNumberToProposals[_itemNum];
        uint256 emi;
        for (uint256 i = 0; i < proposals.length; i++) {
            ICollateral.Proposal memory proposal = proposals[i];
            if (proposal.approved) {
                emi += calculateEMI(
                    proposal.amount,
                    proposal.interestRate,
                    proposal.proposalDuration
                );
            }
        }
        return emi;
    }

//this function helps the borrowers to pay the EMI 
     function depositEmi(uint256 _itemNum) external payable {
        ICollateral.Item memory item = getItem(_itemNum);
        
        require(
            
            block.timestamp < item.EmiDate + ONE_MINUTE,
            "Period is Expired"
        );
        uint256 amount = item.EmiAmount;
        uint256 penalty;
        if (block.timestamp > item.EmiDate + CUSHION_PERIOD) {
            uint256 timeElapsed = (block.timestamp -
                (item.EmiDate + CUSHION_PERIOD)) / 86400; // time elapsed in a day
            penalty = calculatePenalty(item.EstimatedValue, timeElapsed);
        }

        // Check if the sent ether covers the required amount and penalty
        if (penalty != 0 && msg.value < amount + penalty) {
            revert();
        }
        require(msg.value >= amount, "Amount is Less");

        (bool sent, ) = msg.sender.call{value: msg.value - (amount + penalty)}(
            " "
        );
        require(sent, "failed");
        
        uint256 balance = address(this).balance;
        
        // (bool send, ) = EmiDeposit.call{value: balance}(" ");
        // require(send, "transfer failed");

        // payable (msg.sender).transfer( msg.value - (amount + penalty));
        payable(EmiDeposit).transfer(balance);
        item.EmiDate += ONE_MINUTE;
    }

    function withdrawPropoaslIfNotApproved(uint256 _itemNum, uint256 _proposalNum) external returns (bool){
 require(_proposalNum < itemNumberToProposals[_itemNum].length, "Invalid Proposal Number");

 ICollateral.Proposal storage proposal = itemNumberToProposals[_itemNum][_proposalNum];
 require(msg.sender == proposal.investor,"only investor allow to withdraw");
 require(!proposal.approved,"proposal already approved");

 (bool sent, ) = payable(msg.sender).call{
 value: proposal.amount
 }("");
 require(sent, "failed to transfer amount");

 proposal.active =false;
 return true;
 
 }

//function to refund the investor in case the paper work for propsal fails even in case of approval.
    function refundToInvestor(uint256 _itemNum, uint256 _proposalNum) external onlyOwner returns (bool) {
    require(_proposalNum < itemNumberToProposals[_itemNum].length, "Invalid Proposal Number");
    ICollateral.Proposal storage proposal = itemNumberToProposals[_itemNum][_proposalNum];
    (bool sent, ) = payable(proposal.investor).call{value: proposal.amount}("");
    require(sent, "Failed to transfer amount back to the investor");
    proposal.approved = false;
    proposal.active = false;
    return true;
}

//function to transfer approved proposal money to borrower
    function transferMoneyToBorrower() external{}

    function nextEMITimestampToBePaid(
        uint256 _itemNum
    ) public view returns (uint256) {
        return ItemNumberToItem[_itemNum].EmiDate;
    }

    function calculateEMI(
        uint256 principal,
        uint256 interest,
        uint256 month
    ) internal  pure returns (uint256) {
        
        uint256 EMI = ((principal* interest * (1 + interest) ** month)) /
            (((1 + interest) ** month) - 1);
        return EMI;
    }

    function getPenalty() internal view returns (uint256) {
        return Penalty;
    }

    function calculatePenalty(
        uint256 principal,
        uint256 timeElapsed
    ) internal view returns (uint256) {
        uint256 penalty = getPenalty();
        return (principal * penalty) / (timeElapsed * 100); // time elapsed in days
    }

    function getItem(uint256 _itemNum) public view returns (ICollateral.Item memory) {
        return ItemNumberToItem[_itemNum];
    }

    function IncreaseInvestorEmiNumber(uint _itemNum, uint _proposalNum) internal {
        require(msg.sender == EmiDeposit, "you are not allowed");
        ICollateral.Proposal storage proposal = itemNumberToProposals[_itemNum][_proposalNum];
        proposal.emisPaid++;
    }

    function getProposals(uint256 _itemNum) public view returns (ICollateral.Proposal[] memory){
        return itemNumberToProposals[_itemNum] ;
    }
    
}

// [1,1000000000000000000,1,1,12,12,24,"0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"]   
//1 eth = 171220
//500000000000000000
