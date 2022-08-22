// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "openzeppelin/access/Ownable.sol";

/**
 * @title SoundFeeRegistry
 * @author Sound.xyz
 */
contract SoundFeeRegistry is Ownable {
    // ================================
    // CONSTANTS
    // ================================

    /**
     * @dev This is the denominator, in basis points (BPS), for platform fees
     */
    uint16 private constant MAX_BPS = 10_000;

    // ================================
    // STORAGE
    // ================================

    /**
     * @dev The sound protocol's address that receives platform fees.
     */
    address public soundFeeAddress;

    /**
     * @dev The numerator of the platform fee.
     */
    uint16 public platformFeeBPS;

    // ================================
    // EVENTS & ERRORS
    // ================================

    /**
     * @notice Emitted when the `soundFeeAddress` is changed.
     */
    event SoundFeeAddressSet(address soundFeeAddress);

    /**
     * @notice Emitted when the `platformFeeBPS` is changed.
     */
    event PlatformFeeSet(uint16 platformFeeBPS);

    /**
     * The platform fee numerator must not exceed `MAX_BPS`.
     */
    error InvalidPlatformFeeBPS();

    // ================================
    // PUBLIC & EXTERNAL WRITABLE FUNCTIONS
    // ================================

    constructor(address soundFeeAddress_, uint16 platformFeeBPS_) onlyValidPlatformFeeBPS(platformFeeBPS_) {
        soundFeeAddress = soundFeeAddress_;

        platformFeeBPS = platformFeeBPS_;
    }

    /**
     * @dev Sets the `soundFeeAddress`.
     * Calling conditions:
     * - The caller must be the owner of the contract.
     */
    function setSoundFeeAddress(address soundFeeAddress_) external onlyOwner {
        soundFeeAddress = soundFeeAddress_;
        emit SoundFeeAddressSet(soundFeeAddress_);
    }

    /**
     * @dev Sets the `platformFeePBS`.
     * Calling conditions:
     * - The caller must be the owner of the contract.
     */
    function setPlatformFeeBPS(uint16 platformFeeBPS_) external onlyOwner onlyValidPlatformFeeBPS(platformFeeBPS_) {
        platformFeeBPS = platformFeeBPS_;
        emit PlatformFeeSet(platformFeeBPS_);
    }

    // ================================
    // MODIFIERS
    // ================================

    /**
     * @dev Restricts the platform fee numerator to not excced the `MAX_BPS`.
     */
    modifier onlyValidPlatformFeeBPS(uint16 platformFeeBPS_) {
        if (platformFeeBPS_ > MAX_BPS) revert InvalidPlatformFeeBPS();
        _;
    }
}
