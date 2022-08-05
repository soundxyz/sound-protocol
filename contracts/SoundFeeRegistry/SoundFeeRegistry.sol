// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "openzeppelin/access/Ownable.sol";

/// @title SoundFeeRegistry
/// @author Sound.xyz
contract SoundFeeRegistry is Ownable {
    uint256 private constant MAX_BPS = 10_000;

    address public soundFeeAddress;

    /// @dev platform fee in bps (0 to 10,000)
    uint32 public platformBPSFee;

    error InvalidBPSFee();

    constructor(address soundFeeAddress_, uint32 platformBPSFee_) {
        soundFeeAddress = soundFeeAddress_;

        _verifyBPS(platformBPSFee_);
        platformBPSFee = platformBPSFee_;
    }

    function setSoundFeeAddress(address soundFeeAddress_) external onlyOwner {
        soundFeeAddress = soundFeeAddress_;
    }

    function setPlatformBPSFee(uint32 platformBPSFee_) external onlyOwner {
        _verifyBPS(platformBPSFee_);
        platformBPSFee = platformBPSFee_;
    }

    function _verifyBPS(uint32 fee) internal pure {
        if (fee > MAX_BPS) revert InvalidBPSFee();
    }
}
