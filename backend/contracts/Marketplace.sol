// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import 'contracts/UserManagement.sol';
import 'contracts/AttentionToken.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Marketplace {
  UserManagement private userContract;
  AttentionToken private tokenContract;

  struct Listing {
    uint256 id;
    address tokenSeller;
    uint256 amount;
    uint256 price;
  }

  error AccountDoesNotExist();
  error InsufficientTokenBalance();
  error TokenDepositFailed();
  error InvalidListingID();
  error TokenTransferFailed();
  error EthTransferFailed();
  error InsufficientFunds();

  uint256 public currentListingId = 1;
  mapping(uint256 => Listing) public listings;
  mapping(address => uint256) public depositedTokens;

  event TokensDeposited(address user, uint256 amount);
  event ListingCreated(uint256 id, uint256 amount, address seller);
  event ListingBought(uint256 id, uint256 amount, address buyer);

  constructor(address userContractAddress, address tokenContractAddress) {
    userContract = UserManagement(userContractAddress);
    tokenContract = AttentionToken(tokenContractAddress);
  }

  modifier checkAccountExists() {
    UserManagement.User memory currentUser = userContract.getUser(msg.sender);
    if (currentUser.userAddress == address(0)) {
      revert AccountDoesNotExist();
    }
    _;
  }

  function depositTokens(uint256 _amount) external checkAccountExists {
    if (tokenContract.balanceOf(msg.sender) < _amount) {
      revert InsufficientTokenBalance();
    }
    IERC20 attentiontToken = IERC20(address(tokenContract));
    bool sent = attentiontToken.transferFrom(
      msg.sender,
      address(this),
      _amount
    );
    if (!sent) {
      revert TokenDepositFailed();
    }
    depositedTokens[msg.sender] = _amount;
    emit TokensDeposited(msg.sender, _amount);
  }

  function createListing(
    uint256 _amount,
    uint256 _price
  ) external checkAccountExists {
    if (depositedTokens[msg.sender] < _amount) {
      revert InsufficientTokenBalance();
    }
    Listing memory newListing = Listing(
      currentListingId,
      msg.sender,
      _amount,
      _price
    );

    listings[currentListingId] = newListing;
    emit ListingCreated(currentListingId, _amount, msg.sender);
  }

  function buyListing(uint256 _id) external payable {
    if (_id > currentListingId) {
      revert InvalidListingID();
    }
    Listing storage currentListing = listings[_id];

    bool tokenTransfer = IERC20(address(tokenContract)).transfer(
      msg.sender,
      currentListing.amount
    );
    if (!tokenTransfer) {
      revert TokenTransferFailed();
    }
    (bool ethTransfer, ) = currentListing.tokenSeller.call{ value: msg.value }(
      ''
    );
    if (!ethTransfer) {
      revert EthTransferFailed();
    }

    delete depositedTokens[currentListing.tokenSeller];
    delete listings[_id];
    emit ListingBought(_id, currentListing.amount, msg.sender);
  }
}
