// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "chiru-labs/ERC721A-Upgradeable/interfaces/IERC721AUpgradeable.sol";
import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "../modules/Metadata/IMetadataModule.sol";

/*
                 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                
               ▒███████████████████████████████████████████████████████████               
               ▒███████████████████████████████████████████████████████████               
 ▒▓▓▓▓▓▓▓▓▓▓▓▓▓████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒ 
 █████████████████████████████▓              ████████████████████████████████████████████ 
 █████████████████████████████▓              ████████████████████████████████████████████ 
 █████████████████████████████▓               ▒▒▒▒▒▒▒▒▒▒▒▒▒██████████████████████████████ 
 █████████████████████████████▓                            ▒█████████████████████████████ 
 █████████████████████████████▓                             ▒████████████████████████████ 
 █████████████████████████████████████████████████████████▓                              
 ███████████████████████████████████████████████████████████                              
 ███████████████████████████████████████████████████████████▒                             
                              ███████████████████████████████████████████████████████████▒
                              ▓██████████████████████████████████████████████████████████▒
                               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████████████████████▒
 █████████████████████████████                             ▒█████████████████████████████▒
 ██████████████████████████████                            ▒█████████████████████████████▒
 ██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒              ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒███████████████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒ 
               ▓██████████████████████████████████████████████████████████▒               
               ▓██████████████████████████████████████████████████████████                
*/

/**
 * @title ISoundEditionV1
 * @author Sound.xyz
 */
interface ISoundEditionV1 is IERC721AUpgradeable, IERC2981Upgradeable {
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
     */
    function initialize(
        address owner,
        string memory name,
        string memory symbol,
        IMetadataModule metadataModule,
        string memory baseURI,
        string memory contractURI,
        address guardian
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
     * @dev Informs other contracts which interfaces this contract supports.
     * https://eips.ethereum.org/EIPS/eip-165
     * @param interfaceId The interface id to check.
     */
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override(IERC721AUpgradeable, IERC165Upgradeable)
        returns (bool);

    /**
     *  @dev Sets metadata module
     */
    function setMetadataModule(IMetadataModule metadataModule) external;

    /**
     *  @dev Sets global base URI
     */
    function setBaseURI(string memory baseURI) external;

    /**
     *   @dev Sets contract URI
     */
    function setContractURI(string memory _contractURI) external;

    /**
     *   @dev Freezes metadata by preventing any more changes to base URI
     */
    function freezeMetadata() external;
}
