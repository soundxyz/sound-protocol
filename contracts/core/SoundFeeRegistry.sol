// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";

/**
 * @title SoundFeeRegistry
 * @author Sound.xyz
 */
contract SoundFeeRegistry is ISoundFeeRegistry, OwnableRoles {
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
     * @dev The Sound protocol's address that receives platform fees.
     */
    address public override soundFeeAddress;

    /**
     * @dev The numerator of the platform fee.
     */
    uint16 public override platformFeeBPS;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(address soundFeeAddress_, uint16 platformFeeBPS_)
        onlyValidSoundFeeAddress(soundFeeAddress_)
        onlyValidPlatformFeeBPS(platformFeeBPS_)
    {
        soundFeeAddress = soundFeeAddress_;
        platformFeeBPS = platformFeeBPS_;

        _initializeOwner(msg.sender);
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
            fee = uint128((uint256(requiredEtherValue) * uint256(platformFeeBPS)) / uint256(_MAX_BPS));
        }
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Restricts the sound fee address to be address(0).
     * @param soundFeeAddress_ The sound fee address.
     */
    modifier onlyValidSoundFeeAddress(address soundFeeAddress_) {
        if (soundFeeAddress_ == address(0)) revert InvalidSoundFeeAddress();
        _;
    }

    /**
     * @dev Restricts the platform fee numerator to not exceed the `_MAX_BPS`.
     * @param platformFeeBPS_ Platform fee amount in bps (basis points).
     */
    modifier onlyValidPlatformFeeBPS(uint16 platformFeeBPS_) {
        if (platformFeeBPS_ > _MAX_BPS) revert InvalidPlatformFeeBPS();
        _;
    }
}
