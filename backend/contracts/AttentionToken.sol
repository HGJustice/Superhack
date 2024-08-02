// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import 'contracts/UserManagement.sol';

contract AttentionToken is ERC20 {
  UserManagement private userContract;

  error AccountDoesNotExist();

  event AttentionTokenized(address user, uint256 amount);

  constructor(address userContractAddy) ERC20('AttentionToken', 'AoT') {
    userContract = UserManagement(userContractAddy);
  }

  function tokenizeAttention(uint256 _timeOfMediaition) external {
    UserManagement.User memory currentUser = userContract.getUser(msg.sender);
    if (currentUser.userAddress == address(0)) {
      revert AccountDoesNotExist();
    }

    _mint(msg.sender, _timeOfMediaition);

    emit AttentionTokenized((msg.sender), _timeOfMediaition);
  }
}
