// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { OwnableUpgradeable } from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";

/**
 * @title SoundFeeRegistryV1
 * @dev Exposes the Sound platform fee & receiver address.
 */
contract SoundFeeRegistryV1 is ISoundFeeRegistry, OwnableUpgradeable, UUPSUpgradeable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev This is the denominator, in basis points (BPS), for platform fees.
     */
    uint16 private constant _MAX_BPS = 10_000;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The sound protocol's address that receives platform fees.
     */
    address public override soundFeeAddress;

    /**
     * @dev The numerator of the platform fee.
     */
    uint16 public override platformFeeBPS;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    function initialize(address soundFeeAddress_, uint16 platformFeeBPS_)
        public
        onlyValidSoundFeeAddress(soundFeeAddress_)
        onlyValidPlatformFeeBPS(platformFeeBPS_)
        initializer
    {
        __Ownable_init_unchained();

        soundFeeAddress = soundFeeAddress_;
        platformFeeBPS = platformFeeBPS_;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundFeeRegistry
     */
    function setSoundFeeAddress(address soundFeeAddress_)
        external
        onlyOwner
        onlyValidSoundFeeAddress(soundFeeAddress_)
    {
        soundFeeAddress = soundFeeAddress_;
        emit SoundFeeAddressSet(soundFeeAddress_);
    }

    /**
     * @inheritdoc ISoundFeeRegistry
     */
    function setPlatformFeeBPS(uint16 platformFeeBPS_) external onlyOwner onlyValidPlatformFeeBPS(platformFeeBPS_) {
        platformFeeBPS = platformFeeBPS_;
        emit PlatformFeeSet(platformFeeBPS_);
    }

    /**
     * @inheritdoc ISoundFeeRegistry
     */
    function platformFee(uint128 requiredEtherValue) external view returns (uint128 fee) {
        // Won't overflow, as `requiredEtherValue` is 128 bits, and `platformFeeBPS` is 16 bits.
        unchecked {
            fee = (requiredEtherValue * platformFeeBPS) / _MAX_BPS;
        }
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Enables the owner to upgrade the contract.
     *      Required by `UUPSUpgradeable`.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Restricts the sound fee address to be address(0).
     * @param soundFeeAddress_ The sound fee address.
     */
    modifier onlyValidSoundFeeAddress(address soundFeeAddress_) {
        if (soundFeeAddress_ == address(0)) revert InvalidSoundFeeAddress();
        _;
    }

    /**
     * @dev Restricts the platform fee numerator to not excced the `_MAX_BPS`.
     * @param platformFeeBPS_ Platform fee amount in bps (basis points).
     */
    modifier onlyValidPlatformFeeBPS(uint16 platformFeeBPS_) {
        if (platformFeeBPS_ > _MAX_BPS) revert InvalidPlatformFeeBPS();
        _;
    }
}
