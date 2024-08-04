// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Dex is ERC20 {
  IERC20 public liquidityToken;

  constructor() ERC20('ZenSwap', 'ZEN') {}
}
