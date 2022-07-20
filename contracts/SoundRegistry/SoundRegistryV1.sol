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

import "forge-std/Test.sol";

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
        keccak256("RegistrationInfo(address contractAddress)");
    bytes32 public immutable DOMAIN_SEPARATOR;

    /***********************************
                STORAGE
    ***********************************/

    address public signingAuthority;
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
        __Ownable_init();

        signingAuthority = _signingAuthority;
    }

    /// @notice Changes the signing authority of the registry.
    /// @param _signingAuthority The new signing authority.
    function changeSigningAuthority(address _signingAuthority) external {
        require(
            msg.sender == signingAuthority || msg.sender == owner(),
            "Unauthorized"
        );

        signingAuthority = _signingAuthority;
    }

    /// @notice Registers a Sound NFT contract.
    function registerSoundNft(address _soundNft, bytes memory _signature)
        external
    {
        _registerSoundNft(_soundNft, _signature);

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
            _registerSoundNft(nftData[i].soundNft, nftData[i].signature);

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
    function _registerSoundNft(address _soundNft, bytes memory _signature)
        internal
    {
        address nftOwner = OwnableUpgradeable(_soundNft).owner();

        // If the caller is the NFT owner, the signature must be from the signing authority (ie: sound.xyz)
        if (msg.sender == nftOwner) {
            require(
                _getSigner(_soundNft, _signature) == signingAuthority,
                "Unauthorized"
            );
        } else if (msg.sender == signingAuthority) {
            // If the caller is the signing authority, the signature must be from the NFT owner.
            require(
                _getSigner(_soundNft, _signature) == nftOwner,
                "Unauthorized"
            );
        } else {
            revert("Unauthorized");
        }

        // TODO: figure out why this isn't working
        // require(
        //     ISoundNftV1(_soundNft).supportsInterface(
        //         type(ISoundNftV1).interfaceId
        //     ),
        //     "Wrong contract type"
        // );

        registeredSoundNfts[_soundNft] = true;
    }

    /// @notice Unregisters a Sound NFT contract.
    function _unregisterSoundNft(address _soundNft) internal {
        require(
            msg.sender == OwnableUpgradeable(_soundNft).owner() ||
                msg.sender == signingAuthority,
            "Unauthorized"
        );
        registeredSoundNfts[_soundNft] = false;
    }

    function _getSigner(address _soundNft, bytes memory _signature)
        internal
        view
        returns (address signer)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(SIGNATURE_TYPEHASH, _soundNft))
            )
        );

        return digest.recover(_signature);
    }

    /// @notice Authorizes upgrades
    /// @dev DO NOT REMOVE!
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
