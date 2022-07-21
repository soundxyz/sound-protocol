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
import "../SoundEdition/ISoundEditionV1.sol";

contract SoundRegistryV1 is
    EIP712,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using ECDSAUpgradeable for bytes32;

    struct SoundEditionData {
        bytes signature;
        address soundEdition;
    }

    /***********************************
                EVENTS
    ***********************************/

    event Registered(address indexed soundEdition);
    event Unregistered(address indexed soundEdition);

    event RegisteredBatch(address[] indexed soundEditions);
    event UnregisteredBatch(address[] indexed soundEditions);

    /***********************************
                CONSTANTS
    ***********************************/
    bytes32 public constant SIGNATURE_TYPEHASH =
        keccak256("RegistrationInfo(address contractAddress)");

    /***********************************
                STORAGE
    ***********************************/

    address public signingAuthority;
    mapping(address => bool) public registeredSoundEditions;

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
    function registerSoundEdition(address _soundEdition, bytes memory _signature)
        external
    {
        _registerSoundEdition(_soundEdition, _signature);

        emit Registered(_soundEdition);
    }

    /// @notice Registers multiple Sound NFT contracts.
    function registerSoundEditions(SoundEditionData[] memory nftData) external {
        address[] memory nftAddresses = new address[](nftData.length);

        for (uint256 i; i < nftData.length; ) {
            _registerSoundEdition(nftData[i].soundEdition, nftData[i].signature);

            nftAddresses[i] = nftData[i].soundEdition;

            unchecked {
                ++i;
            }
        }

        emit RegisteredBatch(nftAddresses);
    }

    /// @notice Unregisters a Sound NFT contract.
    function unregisterSoundEdition(address _soundEdition) external {
        _unregisterSoundEdition(_soundEdition);

        emit Unregistered(_soundEdition);
    }

    /// @notice Unregisters multiple Sound NFT contracts.
    function unregisterSoundEditions(address[] memory _soundEditions) external {
        address[] memory nftAddresses = new address[](_soundEditions.length);

        for (uint256 i; i < _soundEditions.length; ) {
            _unregisterSoundEdition(_soundEditions[i]);

            nftAddresses[i] = _soundEditions[i];

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
    function _registerSoundEdition(address _soundEdition, bytes memory _signature)
        internal
    {
        address nftOwner = OwnableUpgradeable(_soundEdition).owner();

        // If the caller is the NFT owner, the signature must be from the signing authority (ie: sound.xyz)
        if (msg.sender == nftOwner) {
            require(
                _getSigner(_soundEdition, _signature) == signingAuthority,
                "Unauthorized"
            );
        } else if (msg.sender == signingAuthority) {
            // If the caller is the signing authority, the signature must be from the NFT owner.
            require(
                _getSigner(_soundEdition, _signature) == nftOwner,
                "Unauthorized"
            );
        } else {
            revert("Unauthorized");
        }

        registeredSoundEditions[_soundEdition] = true;
    }

    /// @notice Unregisters a Sound NFT contract.
    function _unregisterSoundEdition(address _soundEdition) internal {
        require(
            msg.sender == OwnableUpgradeable(_soundEdition).owner() ||
                msg.sender == signingAuthority,
            "Unauthorized"
        );
        registeredSoundEditions[_soundEdition] = false;
    }

    function _getSigner(address _soundEdition, bytes memory _signature)
        internal
        view
        returns (address signer)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeparatorV4(),
                keccak256(abi.encode(SIGNATURE_TYPEHASH, _soundEdition))
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
