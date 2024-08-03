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
  // bytes32 immutable priceFeedId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

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
  event ListingCreated(uint256 id, uint256 amount, address seller);
  event ListingDeleted(
    uint256 id,
    address tokenSeller,
    uint256 amount,
    uint256 price
  );
  event DepositedTokensWithdrawn(address tokenOwner, uint256 amount);
  event ListingBought(uint256 id, uint256 amount, address buyer);
  event AdminWithdrawnFees(address owner);

  constructor(
    address userContractAddress,
    address tokenContractAddress,
    address pythContractAddy
  ) {
    userContract = UserManagement(userContractAddress);
    tokenContract = AttentionToken(tokenContractAddress);
    pyth = IPyth(pythContractAddy);
    owner = msg.sender;
  }

  modifier checkAccountExists() {
    UserManagement.User memory currentUser = userContract.getUser(msg.sender);
    if (currentUser.userAddress == address(0)) {
      revert AccountDoesNotExist();
    }
    _;
  }

  function depositTokens(uint256 _amount) external checkAccountExists {
    if (_amount == 0) {
      revert AmountMustBePositive();
    }
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
  ) external checkAccountExists {
    if (_amount == 0) {
      revert AmountMustBePositive();
    }
    if (tokenBalance[msg.sender] < _amount) {
      revert InsufficientTokenBalance();
    }
    Listing memory newListing = Listing(
      currentListingId,
      msg.sender,
      _amount,
      _price
    );

    listings[currentListingId] = newListing;
    tokenBalance[msg.sender] -= _amount;
    emit ListingCreated(currentListingId, _amount, msg.sender);
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
  ) external checkAccountExists {
    if (_amount == 0) {
      revert AmountMustBePositive();
    }
    if (tokenBalance[msg.sender] < _amount) {
      revert InsufficientTokenBalance();
    }
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

  function buyListing(uint256 _listingId) external payable checkAccountExists {
    if (_listingId >= currentListingId || _listingId == 0) {
      revert InvalidListingID();
    }
    Listing storage currentListing = listings[_listingId];
    //use pyth network price oracle to check listing price >= msg.value
    bool tokenTransfer = IERC20(address(tokenContract)).transfer(
      msg.sender,
      currentListing.amount
    );
    if (!tokenTransfer) {
      revert TokenTransferFailed();
    }
    uint256 feesDeducted = msg.value - 0.001 ether;
    (bool ethTransfer, ) = currentListing.tokenSeller.call{
      value: feesDeducted
    }('');
    if (!ethTransfer) {
      revert EthTransferFailed();
    }

    emit ListingBought(_listingId, currentListing.amount, msg.sender);
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

  function exampleMethod(bytes[] calldata priceUpdate) public payable {
    // Submit a priceUpdate to the Pyth contract to update the on-chain price.
    // Updating the price requires paying the fee returned by getUpdateFee.
    // WARNING: These lines are required to ensure the getPrice call below succeeds. If you remove them, transactions may fail with "0x19abf40e" error.
    uint fee = pyth.getUpdateFee(priceUpdate);
    pyth.updatePriceFeeds{ value: fee }(priceUpdate);
    // Read the current price from a price feed.
    // Each price feed (e.g., ETH/USD) is identified by a price feed ID.
    // The complete list of feed IDs is available at https://pyth.network/developers/price-feed-ids
    bytes32 priceFeedId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // ETH/USD
    PythStructs.Price memory price = pyth.getPrice(priceFeedId);
  }
}
