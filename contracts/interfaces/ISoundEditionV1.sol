// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { IERC165Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC165Upgradeable.sol";
import { ISoundEditionEventsAndErrors } from "./edition/ISoundEditionEventsAndErrors.sol";
import { ISoundEditionOwnerActions } from "./edition/ISoundEditionOwnerActions.sol";
import { IMetadataModule } from "./IMetadataModule.sol";

/**
 * @title ISoundEditionV1
 * @author Sound.xyz
 */
interface ISoundEditionV1 is
    ISoundEditionEventsAndErrors,
    ISoundEditionOwnerActions,
    IERC721AUpgradeable,
    IERC2981Upgradeable
{
    /// Getter for minter role hash
    function MINTER_ROLE() external returns (bytes32);

    /// Getter for admin role hash
    function ADMIN_ROLE() external returns (bytes32);

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

    /**
     * @dev Informs other contracts which interfaces this contract supports.
     * https://eips.ethereum.org/EIPS/eip-165
     * @param interfaceId The interface id to check.
     */
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override(IERC721AUpgradeable, IERC165Upgradeable)
        returns (bool);

    /// @dev Returns the base token URI for the collection
    function baseURI() external view returns (string memory);

    /// @dev Returns the total amount of tokens minted in the contract
    function totalMinted() external view returns (uint256);

    function randomnessLockedAfterMinted() external view returns (uint32);

    function randomnessLockedTimestamp() external view returns (uint32);

    function mintRandomness() external view returns (bytes32);

    function getMembersOfRole(bytes32 role) external view returns (address[] memory);
}
