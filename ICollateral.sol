// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICollateral {

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
}
