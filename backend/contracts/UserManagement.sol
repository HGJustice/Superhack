// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract UserManagement {
  struct User {
    uint256 id;
    string userName;
    address addy;
    address[] friends;
  }

  error UserAlreadyCreated();
  error NoAccountCreated();
  error NotOwner();

  mapping(address => User) users;
  uint256 currentUserId = 1;

  event UserCreated(uint256 ud, string username, address userAddy);
  event FriendAdded(address newFriendAddy, string userName, address userAddy);

  function createUser(string calldata _username) external {
    if (users[msg.sender].addy != address(0)) {
      revert UserAlreadyCreated();
    }

    User memory newUser = User(
      currentUserId,
      _username,
      msg.sender,
      new address[](0)
    );

    users[msg.sender] = newUser;
    emit UserCreated(currentUserId, _username, msg.sender);
    currentUserId++;
  }

  function getUser(address userAddress) external view returns (User memory) {
    return users[userAddress];
  }

  function addFriend(address newFriend) external {
    if (users[newFriend].addy == address(0)) {
      revert NoAccountCreated();
    }
    User storage currentUser = users[msg.sender];
    if (users[msg.sender].addy == address(0)) {
      revert NoAccountCreated();
    }
    currentUser.friends.push(newFriend);
    emit FriendAdded(newFriend, currentUser.userName, currentUser.addy);
  }
}
