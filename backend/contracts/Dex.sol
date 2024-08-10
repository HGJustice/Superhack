// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract DEX {
  uint256 public totalLiquidity;
  mapping(address => uint256) public liguidityProvided;

  IERC20 token;
  event EthToTokenSwap(address swapper, uint256 tokenOutput, uint256 ethInput);

  event TokenToEthSwap(address swapper, uint256 tokensInput, uint256 ethOutput);

  event LiquidityProvided(
    address liquidityProvider,
    uint256 liquidityMinted,
    uint256 ethInput,
    uint256 tokensInput
  );

  event LiquidityRemoved(
    address liquidityRemover,
    uint256 liquidityWithdrawn,
    uint256 tokensOutput,
    uint256 ethOutput
  );

  constructor(address token_addr) {
    token = IERC20(token_addr);
  }

  function init(uint256 tokens) public payable returns (uint256) {
    require(totalLiquidity == 0, 'DEX already has liquidity');
    totalLiquidity = address(this).balance;
    liguidityProvided[msg.sender] = totalLiquidity;
    require(
      token.transferFrom(msg.sender, address(this), tokens),
      'transfer of tokens failed'
    );
    return totalLiquidity;
  }

  function price(
    uint256 xInput,
    uint256 xReserves,
    uint256 yReserves
  ) public pure returns (uint256 yOutput) {
    uint256 xinputWithFee = xInput * 997;
    uint256 numerator = xinputWithFee * yReserves;
    uint256 denemonator = (xReserves * 1000) + xinputWithFee;
    return (numerator / denemonator);
  }

  function getLiquidity(address lp) public view returns (uint256) {
    return liguidityProvided[lp];
  }

  function ethToToken() public payable returns (uint256) {
    require(msg.value > 0, 'cannot swap 0 ETH');
    uint256 ethReserve = address(this).balance - msg.value;
    uint256 token_reserve = token.balanceOf(address(this));

    uint256 tokenOutput = price(msg.value, ethReserve, token_reserve);

    require(token.transfer(msg.sender, tokenOutput), 'swap didnt work');
    emit EthToTokenSwap(msg.sender, tokenOutput, msg.value);
    return tokenOutput;
  }

  function tokenToEth(uint256 tokenInput) public returns (uint256) {
    require(tokenInput > 0, 'cannot swap 0 tokens');
    uint256 tokenReserves = token.balanceOf(address(this));
    uint256 ethOutput = price(tokenInput, tokenReserves, address(this).balance);

    require(
      token.transferFrom(msg.sender, address(this), tokenInput),
      'swap didnt work'
    );
    (bool sent, ) = msg.sender.call{ value: ethOutput }('');
    require(sent, 'transfer didnt work');
    emit TokenToEthSwap(msg.sender, tokenInput, ethOutput);
    return ethOutput;
  }

  function deposit() public payable returns (uint256) {
    require(msg.value > 0, 'gotta deposit more then once');
    uint256 ethReserves = address(this).balance - msg.value;
    uint256 tokenReserves = token.balanceOf(address(this));

    uint256 tokensDeposited = ((msg.value * tokenReserves) / ethReserves) - 1;

    uint256 liquidityMinted = (msg.value * tokenReserves) / ethReserves;
    liguidityProvided[msg.sender] += liquidityMinted;
    totalLiquidity += liquidityMinted;

    require(token.transferFrom(msg.sender, address(this), tokensDeposited));
    emit LiquidityProvided(
      msg.sender,
      liquidityMinted,
      msg.value,
      tokensDeposited
    );
    return tokensDeposited;
  }

  function withdraw(uint256 amount) public returns (uint256, uint256) {
    require(
      liguidityProvided[msg.sender] >= amount,
      'not enough liquidity to withdraw'
    );

    uint256 ethReserves = address(this).balance;
    uint256 tokenReserves = token.balanceOf(address(this));

    uint256 ethWithdrawn = (amount * ethReserves) / totalLiquidity;
    uint256 tokenAmount = (amount * tokenReserves) / totalLiquidity;

    liguidityProvided[msg.sender] -= amount;
    totalLiquidity -= amount;

    (bool sent, ) = address(msg.sender).call{ value: ethWithdrawn }('');
    require(sent, 'withdraw failed');

    require(
      token.transfer(address(msg.sender), tokenAmount),
      'Token transfer failed'
    );

    emit LiquidityRemoved(msg.sender, amount, ethWithdrawn, tokenAmount);

    return (ethWithdrawn, tokenAmount);
  }
}
