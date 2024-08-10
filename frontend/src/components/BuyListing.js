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

    const marketplaceContract = new ethers.Contract(
      marketplaceAddress,
      MarketplaceABI,
      signer,
    );

    const listing = await marketplaceContract.listings(formData.listingId);
    const listingPrice = listing.price;

    //convert 5 dollars into eth
    const currentEthPrice = await marketplaceContract.getEthPrice(pythData);
    console.log('ETH price:', currentEthPrice.toString());

    // Assuming the price is returned in wei and represents USD with 8 decimal places
    const ethPriceInUsd = Number(ethers.formatUnits(currentEthPrice, 8));
    console.log('ETH price in USD:', ethPriceInUsd);

    const valueToSend = 0;

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
