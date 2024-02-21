// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private supply;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) internal allowances;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        decimals = _decimals;
        symbol = _symbol;
    }

    function totalSupply() external view returns (uint256) {
        return supply;
    }

    function balanceOf(address owner) public view returns (uint256 balance) {
        return balances[owner];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(to != address(0), "invalid recipient");
        require(value <= balances[msg.sender], "insufficient balance");

        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(to != address(0), "invalid recipient");
        require(amount <= balances[from], "insufficient balance");
        require(
            amount <= allowances[from][msg.sender],
            "insufficient allowance"
        );

        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address account, uint256 amount) external {
        balances[account] += amount;
        supply += amount;
    }
}
