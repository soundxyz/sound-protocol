// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

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
               ▓█████████████████████████████████████████████████████████▒               
               ▓██████████████████████████████████████████████████████████                
*/

import "../SoundEdition/ISoundEditionV1.sol";
import "chiru-labs/ERC721A-Upgradeable/ERC721AUpgradeable.sol";
import "openzeppelin/proxy/Clones.sol";

contract SoundCreatorV1 {
    /***********************************
                STORAGE
    ***********************************/

    address public nftImplementation;
    address public soundRegistry;

    /***********************************
              PUBLIC FUNCTIONS
    ***********************************/

    constructor(address _nftImplementation, address _soundRegistry) {
        nftImplementation = _nftImplementation;
        soundRegistry = _soundRegistry;
    }

    function createSound(string memory _name, string memory _symbol, ISoundNftV1.RegistrationInfo calldata _registrationInfo)
        external
        returns (address soundNft)
    {
        // todo: if signature provided, pass it to SoundRegistry.register();
        // todo: implement extension configurations

        // todo: research if we can get any gas savings by using a more minimal version of Clones lib
        soundNft = Clones.clone(nftImplementation);

        ISoundEditionV1(soundNft).initialize(
            msg.sender,
            _name,
            _symbol,
            _registrationInfo
        );

        // todo: emit event
    }

    /// @notice Informs other contracts which interfaces this contract supports
    /// @param _interfaceId The interface id to check
    /// @dev https://eips.ethereum.org/EIPS/eip-165
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(ERC721AUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }

    /// @notice Get royalty information for token
    /// @param _tokenId token id
    /// @param _salePrice Sale price for the token
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address fundingRecipient, uint256 royaltyAmount)
    {
        // todo
    }
}
