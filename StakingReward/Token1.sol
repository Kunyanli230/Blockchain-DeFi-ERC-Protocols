// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token1 is ERC20 {
    constructor(uint initialSupply) ERC20("Gold1", "GLD1") {
        _mint(msg.sender, initialSupply);
        }

        function mint(address to, uint amount) public {
            _mint (to, amount);
        }
}