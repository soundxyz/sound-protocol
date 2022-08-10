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

/**
 * @title Sound Creator V1
 * @dev Factory for deploying Sound edition contracts.
 */
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

    /**
     * @dev Deploys a Sound edition contract.
     */
    function createSound(
        string memory name,
        string memory symbol,
        IMetadataModule metadataModule,
        string memory baseURI,
        string memory contractURI,
        uint32 editionMaxMintable
    ) external returns (address soundEdition) {
        // todo: if signature provided, pass it to SoundRegistry.register();
        // todo: implement module configurations

        // todo: research if we can get any gas savings by using a more minimal version of Clones lib
        soundEdition = Clones.clone(nftImplementation);

        ISoundEditionV1(soundEdition).initialize(
            msg.sender,
            name,
            symbol,
            metadataModule,
            baseURI,
            contractURI,
            editionMaxMintable
        );

        // todo: emit event
    }
}
