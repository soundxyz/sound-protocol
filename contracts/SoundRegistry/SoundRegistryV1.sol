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

import "openzeppelin-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

contract SoundRegistryV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using ECDSAUpgradeable for bytes32;

    /***********************************
                CONSTANTS
    ***********************************/
    bytes32 public constant SIGNATURE_TYPEHASH =
        keccak256("RegistrationInfo(address contractAddress,uint256 chainId)");
    bytes32 public immutable DOMAIN_SEPARATOR;

    /***********************************
                STORAGE
    ***********************************/

    address signingAuthority;
    mapping(address => bool) public registeredSoundNfts;

    /***********************************
              PUBLIC FUNCTIONS
    ***********************************/

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(uint256 chainId)"),
                block.chainid
            )
        );
    }

    function initialize(address _signingAuthority) public initializer {
        signingAuthority = _signingAuthority;
    }

    /// @notice Registers a Sound NFT contract.
    function registerSoundNft(bytes memory _signature, address _soundNft)
        external
        returns (bool success)
    {
        return _register(_signature, _soundNft);
    }

    /// @notice Registers multiple Sound NFT contracts.
    function registerSoundNfts(
        bytes[] memory _signatures,
        address[] memory _soundNfts
    ) external returns (bool success) {
        for (uint256 i; i < _signatures.length; i++) {
            if (!_register(_signatures[i], _soundNfts[i])) {
                return false;
            }
        }
        return true;
    }

    /// @notice Unregisters a Sound NFT contract.
    function unregister(address _soundNft) external returns (bool success) {
        return _unregister(_soundNft);
    }

    /***********************************
              PRIVATE FUNCTIONS
    ***********************************/

    /// @notice Registers a Sound NFT contract.
    function _register(bytes memory _signature, address _soundNft)
        internal
        returns (bool success)
    {
        require(_getSigner(_signature, _soundNft) == signingAuthority);

        // todo: verify _soundNft matches SoundNft interface

        registeredSoundNfts[_soundNft] = true;

        return true;
    }

    /// @notice Unregisters a Sound NFT contract.
    function _unregister(address _soundNft) internal returns (bool success) {
        // todo: verify msg.sender == _soundNft owner or signingAuthority
    }

    function _getSigner(bytes memory _signature, address _soundNft)
        internal
        view
        returns (address signer)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(SIGNATURE_TYPEHASH, _soundNft, block.chainid)
                )
            )
        );

        // Use the recover method to see what address was used to create
        // the signature on this data.
        // Note that if the digest doesn't exactly match what was signed we'll
        // get a random recovered address.
        return digest.recover(_signature);
    }

    /// @notice Authorizes upgrades
    /// @dev DO NOT REMOVE!
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
