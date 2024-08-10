/* global BigInt */
import React, { useState } from 'react';
import { ethers } from 'ethers';
import MarketplaceABI from '../ABI/Marketplace.json';

const marketplaceAddress = '0x0A8C98cF8AD37c87fc1dE3615Dc0f0385A7b242f';

function BuyListing() {
  const [formData, setFormData] = useState({
    listingId: 0,
  });

  const handleInputChange = event => {
    setFormData({ ...formData, [event.target.name]: event.target.value });
  };

  async function fetchPythData() {
    const url =
      'https://hermes.pyth.network/v2/updates/price/latest?ids%5B%5D=0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace';

    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          accept: 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      console.log('Raw Pyth API response:', data);

      if (data && data.binary && Array.isArray(data.binary.data)) {
        return data.binary.data.map(item => '0x' + item);
      } else {
        console.error('Unexpected data structure:', data);
        throw new Error('Invalid or missing data from Pyth API');
      }
    } catch (error) {
      console.error('Error fetching Pyth data:', error);
      throw error;
    }
  }

  async function buyListingHandel(event) {
    event.preventDefault();

    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const pythData = await fetchPythData();

    const priceIds = [
      '0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace', // ETH/USD price id
    ];

    const marketplaceContract = new ethers.Contract(
      marketplaceAddress,
      MarketplaceABI,
      signer,
    );

    //get listing price - 5$
    const listing = await marketplaceContract.listings(formData.listingId);
    const listingPrice = Number(listing.price);
    console.log(listingPrice);

    //get current value of eth
    let ethPrice;
    const response = await fetch(
      'https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd',
    );
    const data = await response.json();
    ethPrice = data.ethereum.usd;
    console.log('Current ETH price:', ethPrice);

    //convert listing price to eth

    const amount = listingPrice / ethPrice;
    const roundedAmount = amount.toFixed(18);
    const valueToSend = ethers.parseEther(roundedAmount.toString());
    //send eth
    const buyTx = await marketplaceContract.buyListing(
      formData.listingId,
      pythData,
      { value: valueToSend },
    );

    await buyTx.wait();
  }

  return (
    <div>
      <form onSubmit={buyListingHandel}>
        <input
          type="number"
          name="listingId"
          value={formData.listingId}
          placeholder="listing id"
          onChange={handleInputChange}
        />

        <button type="submit">Buy Listing</button>
      </form>
    </div>
  );
}

export default BuyListing;
