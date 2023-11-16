// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.20;
interface IDICproposal {
   
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
    
    struct Item {
        uint256 EstimatedValue;
        uint256 assetValue;
        uint256 minRangeLoanDuration;
        uint256 maxRangeLoanDuration;
        uint256 minRangeInterestRate;
        uint256 maxRangeInterestRate;
        uint256 remainingAmount;
        uint256 paidEmi;
        uint256 EmiAmount;
        uint256 EmiDate;
        address borrower;
    }

    function calculateEMI(
        uint256 principal,
        uint256 interest,
        uint256 month
    ) external pure returns (uint256);

    function getProposals(uint256 _itemNum)
        external
        view
        returns (Proposal[] memory);

    function getItems(uint256 _itemNum) external view returns (Item memory);

    function getPenalty() external view returns (uint256);

    function IncreaseInvestorEmiNumber(uint256 _itemNum, uint256 _proposalNum) external view;
    
}
