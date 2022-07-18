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
import "../SoundNft/ISoundNftV1.sol";

contract SoundRegistryV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using ECDSAUpgradeable for bytes32;

    struct SoundNftData {
        bytes signature;
        address soundNft;
    }

    /***********************************
                EVENTS
    ***********************************/

    event RegisteredNfts(address[] indexed owner, address[] indexed nftAddress);
    event UnregisteredNfts(
        address[] indexed owner,
        address[] indexed nftAddress
    );

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
    {
        _registerSoundNft(_signature, _soundNft);

        address[] memory owners = new address[](1);
        owners[0] = OwnableUpgradeable(_soundNft).owner();

        address[] memory nftAddresses = new address[](1);
        nftAddresses[0] = _soundNft;

        emit RegisteredNfts(owners, nftAddresses);
    }

    /// @notice Registers multiple Sound NFT contracts.
    function registerSoundNfts(SoundNftData[] memory nftData) external {
        address[] memory owners = new address[](nftData.length);
        address[] memory nftAddresses = new address[](nftData.length);

        for (uint256 i; i < nftData.length; ) {
            _registerSoundNft(nftData[i].signature, nftData[i].soundNft);

            owners[i] = OwnableUpgradeable(nftData[i].soundNft).owner();
            nftAddresses[i] = nftData[i].soundNft;

            unchecked {
                ++i;
            }
        }

        emit RegisteredNfts(owners, nftAddresses);
    }

    /// @notice Unregisters a Sound NFT contract.
    function unregisterSoundNft(address _soundNft) external {
        _unregisterSoundNft(_soundNft);

        address[] memory owners = new address[](1);
        address[] memory nftAddresses = new address[](1);

        emit UnregisteredNfts(owners, nftAddresses);
    }

    /// @notice Unregisters multiple Sound NFT contracts.
    function unregisterSoundNfts(address[] memory _soundNfts) external {
        address[] memory owners = new address[](_soundNfts.length);
        address[] memory nftAddresses = new address[](_soundNfts.length);

        for (uint256 i; i < _soundNfts.length; ) {
            _unregisterSoundNft(_soundNfts[i]);

            owners[i] = OwnableUpgradeable(_soundNfts[i]).owner();
            nftAddresses[i] = _soundNfts[i];

            unchecked {
                i++;
            }
        }

        emit UnregisteredNfts(owners, nftAddresses);
    }

    /***********************************
              PRIVATE FUNCTIONS
    ***********************************/

    /// @notice Registers a Sound NFT contract.
    function _registerSoundNft(bytes memory _signature, address _soundNft)
        internal
    {
        require(_getSigner(_signature, _soundNft) == signingAuthority);

        require(
            ISoundNftV1(_soundNft).supportsInterface(
                type(ISoundNftV1).interfaceId
            )
        );

        registeredSoundNfts[_soundNft] = true;
    }

    /// @notice Unregisters a Sound NFT contract.
    function _unregisterSoundNft(address _soundNft) internal {
        require(
            msg.sender == OwnableUpgradeable(_soundNft).owner() ||
                msg.sender == signingAuthority
        );
        registeredSoundNfts[_soundNft] = false;
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
