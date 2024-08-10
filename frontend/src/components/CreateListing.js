import React, { useState } from 'react';
import { ethers } from 'ethers';
import TokenABI from '../ABI/AttentionToken.json';
import MarketplaceABI from '../ABI/Marketplace.json';

const tokenAddress = '0x36c891e695a061d540a61ad3cAB96Df2E1B98F29';
const marketplaceAddress = '0x0A8C98cF8AD37c87fc1dE3615Dc0f0385A7b242f';

function CreateListing() {
  const [formData, setFormData] = useState({
    amountTokens: 0,
    price: 0,
  });

  const handleInputChange = event => {
    setFormData({ ...formData, [event.target.name]: event.target.value });
  };

  async function createListingHandel(event) {
    event.preventDefault();

    const provider = new ethers.BrowserProvider(window.ethereum);

    const signer = await provider.getSigner();

    const tokenContract = new ethers.Contract(tokenAddress, TokenABI, signer);
    const marketplaceContract = new ethers.Contract(
      marketplaceAddress,
      MarketplaceABI,
      signer,
    );
    const approveTx = await tokenContract.approve(
      marketplaceAddress,
      formData.amountTokens,
    );
    await approveTx.wait();

    const depositTx = await marketplaceContract.depositTokens(
      formData.amountTokens,
    );
    await depositTx.wait();

    const createListingTx = await marketplaceContract.createListing(
      formData.amountTokens,
      formData.price,
    );
    await createListingTx.wait();
  }

  return (
    <div>
      <form onSubmit={createListingHandel}>
        <input
          type="number"
          name="amountTokens"
          value={formData.amountTokens}
          placeholder="amount to create listing"
          onChange={handleInputChange}
        />
        <input
          type="number"
          name="price"
          value={formData.price}
          placeholder="price $"
          onChange={handleInputChange}
        />
        <button type="submit">Create Listing</button>
      </form>
    </div>
  );
}

export default CreateListing;
