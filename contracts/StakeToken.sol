// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakeToken is ERC20 {

    constructor() ERC20("BusayoStakeCoin", "BSC") {
        _mint(msg.sender, 1000000 * 10 ** decimals());    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}