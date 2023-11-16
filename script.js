const { expect } = require("chai")
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
//const { ethers } = require("hardhat");
//const { JSONRPC_ERR_CHAIN_DISCONNECTED } = require("web3");

const itemDetails = {
    tokenId: 1,
    EstimatedValue: ethers.parseEther('10'),
    loanValue: ethers.parseEther('1', 'ether'),
    minRangeLoanDuration: 1,
    maxRangeLoanDuration: 12,
    minRangeInterestRate: 12,
    maxRangeInterestRate: 24,
    borrower: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8', // Replace with the actual borrower's address
};

describe("Collateral", function () {
    async function deployCollateral() {
        const [owner, proposer, investor] = await ethers.getSigners();
        const collateral = await ethers.deployContract("Collateral")
        await collateral.waitForDeployment()
        return { collateral, owner, proposer, investor }
    }

    describe("Set Proposal", function () {

        async function setProposal() {
            const { collateral } = await loadFixture(deployCollateral)
            await collateral.setProposal(itemDetails)
        }

        it("Should revert the error caller is not the owner", async function () {
            const { collateral, proposer } = await loadFixture(deployCollateral)
            await expect(
                collateral.connect(proposer).setProposal(itemDetails)
            ).to.be.revertedWith('Ownable: caller is not the owner');
        })

        it("should revert the error Invalid Id", async function () {
            const { collateral } = await loadFixture(deployCollateral)
            await loadFixture(setProposal)
            await expect(
                collateral.setProposal(itemDetails)
            ).to.be.revertedWith('Invalid Id');
        })

        describe("Investor Offer Proposal", function () {

            async function investorOffersProposal() {
                const { collateral, investor, owner } = await loadFixture(deployCollateral);
                await loadFixture(setProposal)
                await collateral.connect(investor).investorOffersProposal(1, 12, 3, {
                    value: ethers.parseEther("1.0")
                })
            }
            // it("should add the offers to the proposal", async function () {
            //     const { collateral, investor } = await loadFixture(deployCollateral)
            //     await collateral.connect(investor).investorOffersProposal(1, 12, 3, {

            //         value: ethers.parseEther("1.0")
            //     })
            //     const proposals = await collateral.getProposals(1)
            //     // console.log({proposals})
            // })

            it("should revert when offering an invalid item number", async function () {
                const { collateral, investor } = await loadFixture(deployCollateral);
                await loadFixture(setProposal)
                await expect(
                    collateral.connect(investor).investorOffersProposal(2, 12, 3, {
                        value: ethers.parseEther("1.0"),
                    })
                ).to.be.revertedWith('InvestorProposalForWatch__InvalidItemNum');
            });

            it("should revert when offering a proposal with a lower interest rate", async function () {
                const { collateral, investor } = await loadFixture(deployCollateral);
                await loadFixture(setProposal)
                await expect(
                    collateral.connect(investor).investorOffersProposal(1, 10, 3, {
                        value: ethers.parseEther("1.0"),
                    })
                ).to.be.revertedWith('InvestorProposalForWatch__InvalidInterestRate');
            });

            it("should revert when offering a proposal with a higher interest rate", async function () {
                const { collateral, investor } = await loadFixture(deployCollateral);
                await loadFixture(setProposal)
                await expect(
                    collateral.connect(investor).investorOffersProposal(1, 30, 3, {
                        value: ethers.parseEther("1.0"),
                    })
                ).to.be.revertedWith('InvestorProposalForWatch__InvalidInterestRate');
            });

            it("should revert when offering an less loan duration", async function () {
                const { collateral, investor } = await loadFixture(deployCollateral);
                await loadFixture(setProposal)
                await expect(
                    collateral.connect(investor).investorOffersProposal(1, 12, 0, {
                        value: ethers.parseEther("1.0"),
                    })
                ).to.be.revertedWith('InvestorProposalForWatch__InvalidDuration');
            });

            it("should revert when offering a proposal with a longer duration", async function () {
                const { collateral, investor } = await loadFixture(deployCollateral);
                await loadFixture(setProposal)
                await expect(
                    collateral.connect(investor).investorOffersProposal(1, 12, 13, {
                        value: ethers.parseEther("1.0"),
                    })
                ).to.be.revertedWith('InvestorProposalForWatch__InvalidDuration');
            });

            it("should revert when offering a proposal with a Invalid amount", async function () {
                const { collateral, investor } = await loadFixture(deployCollateral);
                await loadFixture(setProposal)
                await expect(
                    collateral.connect(investor).investorOffersProposal(1, 12, 12, {
                        value: ethers.parseEther("20.0"),
                    })
                ).to.be.revertedWith("InvestorProposalForWatch__InvalidAmount");
            });

            describe("approve proposal", function () {
                async function approveProposal() {
                    const { collateral, proposer, owner } = await loadFixture(deployCollateral);
                    await loadFixture(investorOffersProposal)
                    await collateral.connect(proposer).approveProposal(1, 0)
                    await collateral.getProposals(1);
                }

                it("should revert when not called by the proposer", async function () {
                    const { collateral, owner } = await loadFixture(deployCollateral);
                    await loadFixture(investorOffersProposal)
                    await expect(
                        collateral.connect(owner).approveProposal(1, 0)
                    ).to.be.revertedWith("Not Borrower")
                });

                it("should revert when approving an invalid item number", async function () {
                    const { collateral, proposer, owner, investor } = await loadFixture(deployCollateral);
                    await loadFixture(investorOffersProposal)
                    await expect(
                        collateral.connect(proposer).approveProposal(2, 0)
                    ).to.be.revertedWith('Not Borrower');
                });

                it("should revert when approving an invalid proposal number", async function () {
                    const { collateral, proposer } = await loadFixture(deployCollateral);
                    await loadFixture(investorOffersProposal)
                    await expect(
                        collateral.connect(proposer).approveProposal(1, 1)
                    ).to.be.revertedWith('InvestorProposalForWatch__InvalidProposal');
                });

                it("should revert when remaining amount is insufficient", async function () {
                    const { collateral, proposer, investor } = await loadFixture(deployCollateral);
                    await loadFixture(investorOffersProposal)
                    await collateral.connect(investor).investorOffersProposal(1, 12, 3, {
                        value: ethers.parseEther("10.0")
                    })
                    const proposals = await collateral.getProposals(1);
                    console.log({ proposals })
                    collateral.connect(proposer).approveProposal(1, 0)
                    console.log("After", { proposals },)
                    await expect(
                        collateral.connect(proposer).approveProposal(1, 1)
                    ).to.be.revertedWith('InvestorProposalForWatch__AmountLessThanProposal');
                });

                it("should revert when trying to approve an already approved proposal", async function () {
                    const { collateral, proposer } = await loadFixture(deployCollateral);
                    await loadFixture(investorOffersProposal)
                    await collateral.connect(proposer).approveProposal(1, 0);
                    await expect(
                        collateral.connect(proposer).approveProposal(1, 0)
                    ).to.be.revertedWith('InvestorProposalForWatch__AlreadyApproved');
                });

                describe("deposit Emi", function () {

                    async function depositEmi() {
                        const { collateral, proposer } = await loadFixture(deployCollateral);
                        await loadFixture(approveProposal)
                        await collateral.connect(proposer).depositEmi(1, {
                            value: ethers.parseEther("1.0")
                        })

                    }
                    it("should revert when the period is expired", async function () {
                        const { collateral, proposer } = await loadFixture(deployCollateral);

                        await loadFixture(approveProposal)

                        await expect(
                            collateral.connect(proposer).depositEmi(1, {
                                value: ethers.parseEther("1.0"),
                            })
                        ).to.be.revertedWith('Period is Expired');
                    });

                })

                // describe("next EMI timestamp to be paid", function(){
                //     async function nextEMITimestampToBePaid() {
                //     const {collateral, proposer} = await loadFixture(deployCollateral);
                //     await loadFixture(depositEmi)
                //     await collateral.connect(proposer).nextEMITimestampToBePaid(1)
                //     }
                // })    

                describe("get item", function () {
                    async function getItem() {
                        const { collateral, proposer } = await loadFixture(deployCollateral);
                        await loadFixture(setProposal);
                        await collateral.connect(proposer).getItem(1);
                    }
                })
                it("should return the item details", async function () {
                    const { collateral, proposer } = await loadFixture(deployCollateral);
                    await loadFixture(setProposal);

                    async function getItem() {
                        return await collateral.connect(proposer).getItem(1);
                    }

                    const item = await getItem(itemDetails);

                    expect(item).to.exist; // Check if the item is defined

                    expect(item.tokenId).to.equal(itemDetails.tokenId);
                    expect(item.EstimatedValue).to.equal(itemDetails.EstimatedValue);
                    expect(item.loanValue).to.equal(itemDetails.loanValue);
                    expect(item.minRangeLoanDuration).to.equal(itemDetails.minRangeLoanDuration);
                    expect(item.maxRangeLoanDuration).to.equal(itemDetails.maxRangeLoanDuration);
                    expect(item.minRangeInterestRate).to.equal(itemDetails.minRangeInterestRate);
                    expect(item.maxRangeInterestRate).to.equal(itemDetails.maxRangeInterestRate);
                    expect(item.borrower).to.equal(itemDetails.borrower);
                });

            });


            // describe("Get Item", function () {
            //     it("should return the item details", async function () {
            //         const { collateral, proposer } = await deployCollateral();
            //         const itemDetails = {
            //             tokenId: 1,
            //             EstimatedValue: ethers.parseEther('10'),
            //             loanValue: ethers.parseEther('1', 'ether'),
            //             minRangeLoanDuration: 1,
            //             maxRangeLoanDuration: 12,
            //             minRangeInterestRate: 12,
            //             maxRangeInterestRate: 24,
            //             borrower: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
            //         };

            //         // Set the proposal
            //         await collateral.setProposal(itemDetails);


            //         // Call the getItem function
            //         const item = await collateral.connect(proposer).getItem(1);

            //         // Check if the item is defined
            //         expect(item).to.exist;

            //         // Check if the returned values match the expected values
            //         expect(item.tokenId).to.equal(itemDetails.tokenId);
            //         expect(item.EstimatedValue).to.equal(itemDetails.EstimatedValue);
            //         expect(item.loanValue).to.equal(itemDetails.loanValue);
            //         expect(item.minRangeLoanDuration).to.equal(itemDetails.minRangeLoanDuration);
            //         expect(item.maxRangeLoanDuration).to.equal(itemDetails.maxRangeLoanDuration);
            //         expect(item.minRangeInterestRate).to.equal(itemDetails.minRangeInterestRate);
            //         expect(item.maxRangeInterestRate).to.equal(itemDetails.maxRangeInterestRate);
            //         expect(item.borrower).to.equal(itemDetails.borrower);
            //     });
            // });

            describe("Get Proposals", function () {
                it("should return an array of proposals", async function () {
                    const { collateral, proposer } = await deployCollateral();
                    const itemDetails = {
                        tokenId: 1,
                        EstimatedValue: ethers.parseEther('10'),
                        loanValue: ethers.parseEther('1', 'ether'),
                        minRangeLoanDuration: 1,
                        maxRangeLoanDuration: 12,
                        minRangeInterestRate: 12,
                        maxRangeInterestRate: 24,
                        borrower: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
                    };

                    // Set the proposal
                    await collateral.setProposal(itemDetails);

                    // Investor offers a proposal
                    await collateral.connect(proposer).investorOffersProposal(1, 12, 3, {
                        value: ethers.parseEther("1.0")
                    });

                    // Get proposals for the item
                    const proposals = await collateral.getProposals(1);

                    // Check if the proposals array is not undefined or null
                    expect(proposals).to.exist;

                    // Check if the length of the proposals array is as expected
                    expect(proposals.length).to.equal(1);

                    // Check if the proposal details match the expected values
                    const [proposal] = proposals;
                    expect(proposal.item).to.equal(1);
                    expect(proposal.amount).to.equal(ethers.parseEther("1.0"));
                    expect(proposal.interestRate).to.equal(12);

                });
            });



            describe("calculate Total Emi", function () {
                async function calculateTotalEmi() {
                    const { collateral, investor, owner } = await loadFixture(deployCollateral);
                    await loadFixture(setProposal);
                    await loadFixture(approveProposal);
                    await collateral.connect(investor).calculateTotalEmi(1, 0);
                }

                it("should return 0 when there are no approved proposals", async function () {
                    const { collateral } = await loadFixture(deployCollateral);
                    const totalEmi = await collateral.calculateTotalEmi(1);
                    expect(totalEmi).to.equal(0);
                });

                it("should return the total EMI", async function () {
                    const { collateral, investor,borrower } = await loadFixture(deployCollateral);
                    await collateral.setProposal(itemDetails);
                    await collateral.connect(investor).investorOffersProposal(1, 12, 3, {
                        value: 10
                    });
                    await collateral.connect(borrower).approveProposal(1, 0); 
                
                    const totalEmi = await collateral.calculateTotalEmi(1);
                    //expect(totalEmi).to.equal(120); 
                    expect(totalEmi).to.equal(ethers.parseEther('120'));
                });
                

            });
        });


    });
});











