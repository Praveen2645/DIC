// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IProposal.sol";

contract TransferEmi is Ownable {
    IDICproposal emi;

    receive() external payable {}

    function setDicProposal(address _address) external onlyOwner {
        emi = IDICproposal(_address);
    }

    function transferEMIamountToInvestors(uint256 _itemNum) external payable returns (bool) {
        IDICproposal.Proposal[] memory proposals = emi.getProposals(_itemNum);
        address[] memory InvestorAddresses = new address[](proposals.length);
        uint[] memory Payments = new uint[](proposals.length);

        for (uint256 i = 0; i < proposals.length; ) {
            IDICproposal.Proposal memory proposal = proposals[i];
            if (proposal.approved && proposal.emisPaid < proposal.proposalDuration) {
                uint256 EMIToPay = emi.calculateEMI(
                    proposal.amount,
                    proposal.interestRate,
                    proposal.proposalDuration
                );
                uint256 penaltyReceive;
                InvestorAddresses[i] = proposal.investor;
                Payments[i] = EMIToPay + penaltyReceive;
                emi.IncreaseInvestorEmiNumber(_itemNum, i);
                unchecked {
                    i++;
                }
            }
        }

        for (uint256 i; i < InvestorAddresses.length; ) {
            (bool sent, ) = InvestorAddresses[i].call{value: Payments[i]}("");
            require(sent, "InvestorProposalForWatch__transferFailed()");
            unchecked {
                i++;
            }
            return true;
        }
        return true;
    }
}
