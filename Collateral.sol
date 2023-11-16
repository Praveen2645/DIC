// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// import "../../artifacts/@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
contract Collateral is Ownable {
    address EmiDeposit;
    //uint256 constant THIRTY_DAY_EPOCH = 2629743; // number of seconds in thirty days
   // uint256 constant CUSHION_PERIOD = 5 days;
    uint256 constant ONE_MINUTE = 60;
    uint256 constant CUSHION_PERIOD = 60 seconds;
    uint256 Penalty = 1; // penalty paid by the borrower for late payment, in % per day

    receive() external payable {}

    struct ItemDetails {
        uint256 tokenId;
        uint256 EstimatedValue;
        uint256 loanValue;
        uint256 minRangeLoanDuration;
        uint256 maxRangeLoanDuration;
        uint256 minRangeInterestRate;
        uint256 maxRangeInterestRate;
        address borrower;
    }

    struct Item {
        uint256 EstimatedValue;
        uint256 loanValue;
        uint256 minRangeLoanDuration;
        uint256 maxRangeLoanDuration;
        uint256 minRangeInterestRate;
        uint256 maxRangeInterestRate;
        uint256 remainingAmount;
        uint256 EmiToPay;
        uint256 EmiAmount;
        uint256 EmiDate;
        address borrower;
    }

    struct Proposal {
        uint256 item;
        uint256 amount;
        uint256 interestRate;
        uint256 proposalDuration;
        uint256 emisPaid;
        address investor;
        bool approved;
        bool active;
    }

    mapping(uint256 => Proposal[]) public itemNumberToProposals;
    mapping(uint256 => Item) private ItemNumberToItem;

    modifier onlyBorrower(uint256 _itemNum) {
        
        require(
            ItemNumberToItem[_itemNum].borrower == msg.sender,
            "Not Borrower"
        );
        _;
    }

    function setTransferEmi(address _address) external onlyOwner{
        EmiDeposit =_address;
    }

    function setProposal(ItemDetails memory itemDetails) external onlyOwner{
        require(
            ItemNumberToItem[itemDetails.tokenId].EstimatedValue == 0,
            "Invalid Id"
        );

        Item memory item = Item(
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

    function investorOffersProposal(
        uint256 _itemNum,
        uint256 _interestRate,
        uint256 _duration
    ) external payable {
        Item storage item = ItemNumberToItem[_itemNum];
        require(
            item.EstimatedValue != 0,
            "InvestorProposalForWatch__InvalidItemNum"
        );
        require(
            msg.value > 0 && msg.value <= item.EstimatedValue,
            "InvestorProposalForWatch__InvalidAmount"
        );
        require(
            _interestRate > 0 &&
                _interestRate >= item.minRangeInterestRate &&
                _interestRate <= item.maxRangeInterestRate,
            "InvestorProposalForWatch__InvalidInterestRate"
        );
        require(
            _duration >= item.minRangeLoanDuration &&
                _duration <= item.maxRangeLoanDuration,
            "InvestorProposalForWatch__InvalidDuration"
        );

        Proposal memory proposal = Proposal(
            _itemNum,
            msg.value,
            _interestRate,
            block.timestamp, //change later to _duration
            0,
            msg.sender,
            false,
            true
        );
        // uint256 index = itemNumberToProposals[_itemNum].length;
        itemNumberToProposals[_itemNum].push(proposal);
    }

    function approveProposal(
        uint256 _itemNum,
        uint256 _proposalNum
    ) external onlyBorrower(_itemNum) returns (bool) {
        Item storage item = ItemNumberToItem[_itemNum];
        require(
            _proposalNum < itemNumberToProposals[_itemNum].length,
            "InvestorProposalForWatch__InvalidProposal"
        );

        Proposal storage proposal = itemNumberToProposals[_itemNum][
            _proposalNum
        ];
        require(
            item.remainingAmount >= proposal.amount,
            "InvestorProposalForWatch__AmountLessThanProposal"
        );
        require(
            !proposal.approved,
            "InvestorProposalForWatch__AlreadyApproved"
        );

        item.remainingAmount -= proposal.amount;
        proposal.approved = true;
        return true;
    }

    function calculateTotalEmi(uint256 _itemNum) public view returns (uint256) {
        Proposal[] memory proposals = itemNumberToProposals[_itemNum];
        uint256 emi;
        for (uint256 i = 0; i < proposals.length; i++) {
            Proposal memory proposal = proposals[i];
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

    function depositEmi(uint256 _itemNum) external payable {
        Item memory item = getItem(_itemNum);
        
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
        require(sent, "transfer failed");
        uint256 balance = address(this).balance;
        (bool send, ) = EmiDeposit.call{value: balance}(" ");
        require(send, "transfer failed");
        item.EmiDate += ONE_MINUTE;
    }

    function nextEMITimestampToBePaid(
        uint256 _itemNum
    ) public view returns (uint256) {
        return ItemNumberToItem[_itemNum].EmiDate;
    }

    function calculateEMI(
        uint256 principal,
        uint256 interest,
        uint256 month
    ) internal pure returns (uint256) {
        uint256 EMI = ((principal * interest * (1 + interest) ** month)) /
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

    function getItem(uint256 _itemNum) public view returns (Item memory) {
        return ItemNumberToItem[_itemNum];
    }

    function IncreaseInvestorEmiNumber(uint _itemNum, uint _proposalNum) internal {
        require(msg.sender == EmiDeposit, "you are not allowed");
        Proposal storage proposal = itemNumberToProposals[_itemNum][_proposalNum];
        proposal.emisPaid++;
    }

    function getProposals(uint256 _itemNum) public view returns (Proposal[] memory){
        return itemNumberToProposals[_itemNum] ;
    }
}
