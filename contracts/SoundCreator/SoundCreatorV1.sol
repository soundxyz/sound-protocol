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
import "../SoundFeeRegistry/SoundFeeRegistry.sol";

/// @title Sound Creator V1
/// @dev Factory for deploying Sound edition contracts.
contract SoundCreatorV1 {
    /***********************************
                STORAGE
    ***********************************/

    address public nftImplementation;
    address public soundRegistry;
    SoundFeeRegistry public soundFeeRegistry;

    /***********************************
              PUBLIC FUNCTIONS
    ***********************************/

    constructor(
        address _nftImplementation,
        address _soundRegistry,
        SoundFeeRegistry _soundFeeRegistry
    ) {
        nftImplementation = _nftImplementation;
        soundRegistry = _soundRegistry;
        soundFeeRegistry = _soundFeeRegistry;
    }

    /// @dev Deploys a Sound edition contract.
    function createSound(
        string memory _name,
        string memory _symbol,
        IMetadataModule _metadataModule,
        string memory _baseURI,
        string memory _contractURI,
        address _fundingRecipient,
        uint32 _royaltyBPS
    ) external returns (address soundEdition) {
        // todo: if signature provided, pass it to SoundRegistry.register();
        // todo: implement module configurations

        // todo: research if we can get any gas savings by using a more minimal version of Clones lib
        soundEdition = Clones.clone(nftImplementation);

        ISoundEditionV1(soundEdition).initialize(
            msg.sender,
            _name,
            _symbol,
            _metadataModule,
            _baseURI,
            _contractURI,
            _fundingRecipient,
            _royaltyBPS,
            soundFeeRegistry
        );

        // todo: emit event
    }
}
