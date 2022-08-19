// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

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
import "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/proxy/Clones.sol";
import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Sound Creator V1
 * @dev Factory for deploying Sound edition contracts.
 */
contract SoundCreatorV1 is OwnableUpgradeable, UUPSUpgradeable {
    event SoundEditionCreated(address indexed soundEdition, address indexed creator);
    event SoundEditionImplementationSet(address newImplementation);

    error ImplementationAddressCantBeZero();

    address public soundEditionImplementation;

    /**
     * @dev Initialize the creator proxy with the edition implementation.
     */
    function initialize(address _soundEditionImplementation)
        public
        implementationNotZero(_soundEditionImplementation)
        initializer
    {
        __Ownable_init_unchained();

        soundEditionImplementation = _soundEditionImplementation;
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
        uint32 editionMaxMintable,
        uint32 randomnessLockedAfterMinted,
        uint32 randomnessLockedTimestamp
    ) external returns (address soundEdition) {
        // Create Sound Edition proxy
        soundEdition = Clones.clone(soundEditionImplementation);
        // Initialize proxy
        ISoundEditionV1(soundEdition).initialize(
            msg.sender,
            name,
            symbol,
            metadataModule,
            baseURI,
            contractURI,
            editionMaxMintable,
            randomnessLockedAfterMinted,
            randomnessLockedTimestamp
        );

        emit SoundEditionCreated(soundEdition, msg.sender);
    }

    /**
     * @dev Changes the SoundEdition implementation contract address.
     */
    function setEditionImplementation(address newImplementation)
        external
        onlyOwner
        implementationNotZero(newImplementation)
    {
        soundEditionImplementation = newImplementation;

        emit SoundEditionImplementationSet(soundEditionImplementation);
    }

    modifier implementationNotZero(address implementation) {
        if (implementation == address(0)) {
            revert ImplementationAddressCantBeZero();
        }
        _;
    }

    /**
     * @dev This must be included on all UUPS logic contracts. The onlyOwner on it guards against unauthorized upgrades.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
