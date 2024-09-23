// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract StableCoin is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(_msgSender()) {
        _mint(_msgSender(), 100 * 10**uint(decimals()));
    }
    
    function mintEUR(
        uint _amount)
        public
        {
        _mint(_msgSender(), _amount);    
    }
    
}