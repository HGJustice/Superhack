// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import 'contracts/UserManagement.sol';
import 'contracts/AttentionToken.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@pythnetwork/pyth-sdk-solidity/IPyth.sol';
import '@pythnetwork/pyth-sdk-solidity/PythStructs.sol';

contract Marketplace {
  UserManagement private userContract;
  AttentionToken private tokenContract;
  IPyth private pyth;
  bytes32 immutable priceFeedId =
    0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

  struct Listing {
    uint256 id;
    address tokenSeller;
    uint256 amount;
    uint256 price;
  }

  error AccountDoesNotExist();
  error AmountMustBePositive();
  error InsufficientTokenBalance();
  error NotOwner();
  error TokenDepositFailed();
  error InvalidListingID();
  error TokenTransferFailed();
  error EthTransferFailed();
  error InsufficientFunds();

  uint256 public currentListingId = 1;
  mapping(uint256 => Listing) public listings;
  mapping(address => uint256) public tokenBalance;
  address owner;

  event TokensDeposited(address user, uint256 amount);
  event ListingCreated(
    uint256 id,
    uint256 amount,
    uint256 price,
    address seller
  );
  event ListingDeleted(
    uint256 id,
    address tokenSeller,
    uint256 amount,
    uint256 price
  );
  event DepositedTokensWithdrawn(address tokenOwner, uint256 amount);
  event ListingBought(uint256 id, uint256 amount, uint256 price, address buyer);
  event AdminWithdrawnFees(address owner);
  event newPrice(int64 amoount);

  constructor(address userContractAddress, address tokenContractAddress) {
    userContract = UserManagement(userContractAddress);
    tokenContract = AttentionToken(tokenContractAddress);
    pyth = IPyth(0xA2aa501b19aff244D90cc15a4Cf739D2725B5729);
    owner = msg.sender;
  }

  modifier checkAccountExists() {
    UserManagement.User memory currentUser = userContract.getUser(msg.sender);
    if (currentUser.userAddress == address(0)) {
      revert AccountDoesNotExist();
    }
    _;
  }

  modifier checkAmount(uint256 _amount) {
    if (_amount == 0) {
      revert AmountMustBePositive();
    }
    _;
  }

  modifier checkBalanceToAmount(uint256 _amount) {
    if (tokenBalance[msg.sender] < _amount) {
      revert InsufficientTokenBalance();
    }
    _;
  }

  function depositTokens(
    uint256 _amount
  ) external checkAccountExists checkAmount(_amount) {
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
    tokenBalance[msg.sender] += _amount;
    emit TokensDeposited(msg.sender, _amount);
  }

  function createListing(
    uint256 _amount,
    uint256 _price
  )
    external
    checkAccountExists
    checkAmount(_amount)
    checkBalanceToAmount(_amount)
  {
    Listing memory newListing = Listing(
      currentListingId,
      msg.sender,
      _amount,
      _price
    );

    listings[currentListingId] = newListing;
    tokenBalance[msg.sender] -= _amount;
    emit ListingCreated(currentListingId, _amount, _price, msg.sender);
    currentListingId++;
  }

  function deleteListing(uint256 _listingId) external {
    if (_listingId > currentListingId || _listingId == 0) {
      revert InvalidListingID();
    }
    Listing memory currentListing = listings[_listingId];
    if (currentListing.tokenSeller != msg.sender) {
      revert NotOwner();
    }
    tokenBalance[msg.sender] += currentListing.amount;

    delete listings[_listingId];
    emit ListingDeleted(
      _listingId,
      msg.sender,
      currentListing.amount,
      currentListing.price
    );
  }

  function withdrawDepositedTokens(
    uint256 _amount
  )
    external
    checkAccountExists
    checkAmount(_amount)
    checkBalanceToAmount(_amount)
  {
    tokenBalance[msg.sender] -= _amount;
    bool tokenTransfer = IERC20(address(tokenContract)).transfer(
      msg.sender,
      _amount
    );
    if (!tokenTransfer) {
      revert TokenTransferFailed();
    }
    emit DepositedTokensWithdrawn(msg.sender, _amount);
  }

  function buyListing(
    uint256 _listingId,
    bytes[] calldata priceUpdate
  ) external payable checkAccountExists {
    if (_listingId >= currentListingId || _listingId == 0) {
      revert InvalidListingID();
    }

    Listing storage currentListing = listings[_listingId];

    // Get the current ETH/USD price
    int256 ethPrice = getEthPrice(priceUpdate);
    require(ethPrice > 0, 'Invalid ETH price');

    // Convert the listing price from USD to ETH
    // Assuming the price is in cents and Pyth price has 8 decimals
    uint256 listingPriceInEth = (currentListing.price * 1e26) /
      uint256(ethPrice);

    // Check if enough ETH was sent
    require(msg.value >= listingPriceInEth, 'Not enough ETH sent');

    bool tokenTransfer = IERC20(address(tokenContract)).transfer(
      msg.sender,
      currentListing.amount
    );
    if (!tokenTransfer) {
      revert TokenTransferFailed();
    }

    // Calculate the amount to send to the seller (subtracting the fee)
    uint256 fee = 0.001 ether;
    require(listingPriceInEth > fee, 'Listing price too low');
    uint256 amountToSeller = listingPriceInEth - fee;

    (bool ethTransfer, ) = currentListing.tokenSeller.call{
      value: amountToSeller
    }('');
    if (!ethTransfer) {
      revert EthTransferFailed();
    }

    // Refund excess ETH to the buyer
    if (msg.value > listingPriceInEth) {
      (bool refundTransfer, ) = msg.sender.call{
        value: msg.value - listingPriceInEth
      }('');
      require(refundTransfer, 'Refund transfer failed');
    }

    emit ListingBought(
      _listingId,
      currentListing.amount,
      currentListing.price,
      msg.sender
    );
    delete listings[_listingId];
  }

  function withdrawFees() external {
    if (msg.sender != owner) {
      revert NotOwner();
    }
    (bool ethTransfer, ) = address(msg.sender).call{
      value: address(this).balance
    }('');
    if (!ethTransfer) {
      revert EthTransferFailed();
    }
    emit AdminWithdrawnFees(msg.sender);
  }

  function getEthPrice(
    bytes[] calldata priceUpdate
  ) public payable returns (int256) {
    uint256 fee = pyth.getUpdateFee(priceUpdate);
    pyth.updatePriceFeeds{ value: fee }(priceUpdate);

    bytes32 priceFeedId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // ETH/USD
    PythStructs.Price memory price = pyth.getPrice(priceFeedId);

    require(price.price > 0, 'Invalid price');
    return price.price;
  }

  receive() external payable {}
}
