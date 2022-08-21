// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

interface ISoundEditionActions {
    /**
     * @dev Initializes the contract
     * @param owner Owner of contract (artist)
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param metadataModule Address of metadata module, address(0x00) if not used
     * @param baseURI Base URI
     * @param contractURI Contract URI for OpenSea storefront
     * @param fundingRecipient Address that receives primary and secondary royalties
     * @param royaltyBPS Royalty amount in bps (basis points)
     * @param editionMaxMintable The maximum amount of tokens that can be minted for this edition.
     * @param randomnessLockedAfterMinted Token supply after which randomness gets locked
     * @param randomnessLockedTimestamp Timestamp after which randomness gets locked
     */
    function initialize(
        address owner,
        string memory name,
        string memory symbol,
        IMetadataModule metadataModule,
        string memory baseURI,
        string memory contractURI,
        address fundingRecipient,
        uint16 royaltyBPS,
        uint32 editionMaxMintable,
        uint32 randomnessLockedAfterMinted,
        uint32 randomnessLockedTimestamp
    ) external;

    /**
     * @dev Mints `quantity` tokens to addrress `to`
     * Each token will be assigned a token ID that is consecutively increasing.
     * The caller must have the `MINTERROLE`, which can be granted via
     * {grantRole}. Multiple minters, such as different minter contracts,
     * can be authorized simultaneously.
     * @param to Address to mint to
     * @param quantity Number of tokens to mint
     */
    function mint(address to, uint256 quantity) external payable;

    /**
     * @dev Withdraws collected ETH royalties to the fundingRecipient
     */
    function withdrawETH() external;

    /**
     * @dev Withdraws collected ERC20 royalties to the fundingRecipient
     * @param tokens array of ERC20 tokens to withdraw
     */
    function withdrawERC20(address[] calldata tokens) external;
}
