// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Loan{

using SafeMath for uint256;
uint256 private constant PRECISION = 8;

function calculateFormula(uint Amount,uint interestRate,uint month) public pure returns(uint){//50000,10,6
//
uint preodicInterestRate = (interestRate* 10**PRECISION) / 1200; 
console.log("periodic interest rate is :", preodicInterestRate);//833333 => 0.00833333
uint LoanAmount = Amount * 10**PRECISION; //5000000000000 
console.log("loan amount is :", LoanAmount);
uint Month = month;//6
//MONTHLY PAYMENT
//b = [{(1+preodicInterestRate)^Month}-1]
//c = [{preodicInterestRate(1+preodicInterestRate)^Month}]


uint commonPart = 1 + preodicInterestRate;
console.log("common part is:", commonPart);//833334

uint partA = ((commonPart)**Month-1); 
console.log("part A is:", partA);

uint partB = (preodicInterestRate**Month);
console.log("part B is:",partB);

uint monthlyPayment = SafeMath.div(LoanAmount.mul(partB),partA);
console.log("monthly payment is:", monthlyPayment);

return monthlyPayment; //39999.76000083

}

// function calculate(uint LoanAmount,uint partA, uint partB) internal pure returns(uint){
// uint256 monthly = SafeMath.div(LoanAmount.mul(partB),partA);
// }

// function calculate(uint256 partA,uint256 partB)internal pure returns(uint){
// uint256 Amount = 40000;
// uint256 a = Amount * 10**PRECISION; //4000000000000
// console.log("loan Amount:",a);
// uint256 months = 6;
// uint256[] memory interestAmount = new uint256[](10);
// uint256[] memory principal =  new uint256[](10);
// uint256 interest = 12;
// uint256 r = (interest* 10**PRECISION) / 1200;
// console.log(" monthly Interest Rate is:",r);

// uint256 monthlyPayment = SafeMath.div(a.mul(partA),partB);
// console.log("monthlyPayent is:", monthlyPayment);

// }
}
