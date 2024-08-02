// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract UserManagement {
  struct User {
    uint256 id;
    string userName;
    address userAddress;
    address[] friends;
  }

  error UserAlreadyCreated();
  error AccountDoesNotExist();
  error NotOwner();

  mapping(address => User) users;
  uint256 currentUserId = 1;

  event UserCreated(uint256 ud, string username, address userAddy);
  event FriendAdded(address newFriendAddy, string userName, address userAddy);

  function createUser(string calldata _username) external {
    if (users[msg.sender].userAddress != address(0)) {
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

  function getUser(address _userAddress) external view returns (User memory) {
    return users[_userAddress];
  }

  function addFriend(address _newFriend) external {
    if (users[_newFriend].userAddress == address(0)) {
      revert AccountDoesNotExist();
    }
    if (users[msg.sender].userAddress == address(0)) {
      revert AccountDoesNotExist();
    }
    User storage currentUser = users[msg.sender];
    currentUser.friends.push(_newFriend);
    emit FriendAdded(_newFriend, currentUser.userName, currentUser.userAddress);
  }
}
