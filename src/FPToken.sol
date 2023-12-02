// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FPToken is ERC20 {
    constructor() ERC20("Fake Pepe Token", "FPT") {}
}
