// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20Asset is ERC20 {

    constructor(string memory name_, string memory symbol_)ERC20(name_, symbol_){
        mint(msg.sender, 10 ** 10);
    }

    function mint(address to_, uint256 amount_) public {
        _mint(to_, amount_);
    }
}