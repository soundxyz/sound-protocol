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
import "openzeppelin/utils/cryptography/draft-EIP712.sol";
import "../SoundNft/ISoundNftV1.sol";

contract SoundRegistryV1 is
    EIP712,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using ECDSAUpgradeable for bytes32;

    struct SoundNftData {
        bytes signature;
        address soundNft;
    }

    /***********************************
                EVENTS
    ***********************************/

    event Registered(address indexed soundNft);
    event Unregistered(address indexed soundNft);

    event RegisteredBatch(address[] indexed soundNfts);
    event UnregisteredBatch(address[] indexed soundNfts);

    /***********************************
                CONSTANTS
    ***********************************/
    bytes32 public constant SIGNATURE_TYPEHASH =
        keccak256("RegistrationInfo(address contractAddress)");

    /***********************************
                STORAGE
    ***********************************/

    address public signingAuthority;
    mapping(address => bool) public registeredSoundNfts;

    /***********************************
              PUBLIC FUNCTIONS
    ***********************************/

    constructor() EIP712("SoundRegistry", "1") {}

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

        emit Registered(_soundNft);
    }

    /// @notice Registers multiple Sound NFT contracts.
    function registerSoundNfts(SoundNftData[] memory nftData) external {
        address[] memory nftAddresses = new address[](nftData.length);

        for (uint256 i; i < nftData.length; ) {
            _registerSoundNft(nftData[i].soundNft, nftData[i].signature);

            nftAddresses[i] = nftData[i].soundNft;

            unchecked {
                ++i;
            }
        }

        emit RegisteredBatch(nftAddresses);
    }

    /// @notice Unregisters a Sound NFT contract.
    function unregisterSoundNft(address _soundNft) external {
        _unregisterSoundNft(_soundNft);

        emit Unregistered(_soundNft);
    }

    /// @notice Unregisters multiple Sound NFT contracts.
    function unregisterSoundNfts(address[] memory _soundNfts) external {
        address[] memory nftAddresses = new address[](_soundNfts.length);

        for (uint256 i; i < _soundNfts.length; ) {
            _unregisterSoundNft(_soundNfts[i]);

            nftAddresses[i] = _soundNfts[i];

            unchecked {
                i++;
            }
        }

        emit UnregisteredBatch(nftAddresses);
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
                _domainSeparatorV4(),
                keccak256(abi.encode(SIGNATURE_TYPEHASH, _soundNft))
            )
        );

        return digest.recover(_signature);
    }

    /// @notice Authorizes upgrades
    /// @dev DO NOT REMOVE!
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /***********************************
              VIEW FUNCTIONS
    ***********************************/

    /// @notice Returns the contract's {EIP712} domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
