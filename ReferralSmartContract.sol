// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Investment {
    mapping(address => uint256) public balances;
    address public owner;
    uint256 public referralPercentage = 5; 

    event Invested(address indexed investor, uint256 amount, address indexed referral);

    constructor() {
        owner = msg.sender;
    }

   
    function invest() external payable {
        require(msg.value > 0, "Investment amount must be greater than zero.");

        uint256 investmentAmount = msg.value;

        balances[msg.sender] += investmentAmount;
        
        emit Invested(msg.sender, investmentAmount, address(0));
    }

  
    function investWithReferral(address referral) external payable {
        require(msg.value > 0, "Investment amount must be greater than zero.");
        require(referral != msg.sender, "You cannot refer yourself.");

        uint256 investmentAmount = msg.value;
        uint256 referralBonus = 0;

        if (referral != address(0)) {
            referralBonus = (investmentAmount * referralPercentage) / 100;
            payable(referral).transfer(referralBonus);
        }

        balances[msg.sender] += (investmentAmount - referralBonus);
        
        emit Invested(msg.sender, investmentAmount, referral);
    }

    
    function getBalance(address investor) external view returns (uint256) {
        return balances[investor];
    }

   
    function withdraw() external {
        require(msg.sender == owner, "Only the owner can withdraw.");
        require(address(this).balance > 0, "No funds available.");

        payable(owner).transfer(address(this).balance);
    }

   
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
