pragma solidity ^0.8.16;

import "../TestConfig.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundFeeRegistry, SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";

contract SoundFeeRegistryTests is TestConfig {
    event SoundFeeAddressSet(address soundFeeAddress);

    event PlatformFeeSet(uint16 platformFeeBPS);

    function test_deployFeeRegistry(address soundFeeAddress, uint16 platformFeeBPS) public {
        if (soundFeeAddress == address(0)) {
            vm.expectRevert(ISoundFeeRegistry.InvalidSoundFeeAddress.selector);
            new SoundFeeRegistry(soundFeeAddress, platformFeeBPS);
            return;
        }
        if (platformFeeBPS > MAX_BPS) {
            vm.expectRevert(ISoundFeeRegistry.InvalidPlatformFeeBPS.selector);
            new SoundFeeRegistry(soundFeeAddress, platformFeeBPS);
            return;
        }

        SoundFeeRegistry soundFeeRegistry = new SoundFeeRegistry(soundFeeAddress, platformFeeBPS);

        assertEq(soundFeeRegistry.soundFeeAddress(), soundFeeAddress);
        assertEq(soundFeeRegistry.platformFeeBPS(), platformFeeBPS);
    }

    // =============================================================
    //                     setSoundFeeAddress()
    // =============================================================

    // Test if setSoundFeeAddress only callable by owner
    function test_setSoundFeeAddressRevertsForNonOwner() external {
        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        feeRegistry.setSoundFeeAddress(address(10));
    }

    function test_setSoundFeeAddress(address newSoundFeeAddress) external {
        if (newSoundFeeAddress == address(0)) {
            vm.expectRevert(ISoundFeeRegistry.InvalidSoundFeeAddress.selector);
            feeRegistry.setSoundFeeAddress(newSoundFeeAddress);
            return;
        }

        vm.expectEmit(false, false, false, true);
        emit SoundFeeAddressSet(newSoundFeeAddress);
        feeRegistry.setSoundFeeAddress(newSoundFeeAddress);

        assertEq(feeRegistry.soundFeeAddress(), newSoundFeeAddress);
    }

    // =============================================================
    //                      setPlatformFeeBPS()
    // =============================================================

    // Test if setPlatformFeeBPS only callable by owner
    function test_setPlatformFeeBPSRevertsForNonOwner() external {
        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        feeRegistry.setPlatformFeeBPS(10);
    }

    function test_setPlatformFeeBPS(uint16 newPlatformFeeBPS) external {
        if (newPlatformFeeBPS > MAX_BPS) {
            vm.expectRevert(ISoundFeeRegistry.InvalidPlatformFeeBPS.selector);
            feeRegistry.setPlatformFeeBPS(newPlatformFeeBPS);
            return;
        }

        vm.expectEmit(false, false, false, true);
        emit PlatformFeeSet(newPlatformFeeBPS);
        feeRegistry.setPlatformFeeBPS(newPlatformFeeBPS);

        assertEq(feeRegistry.platformFeeBPS(), newPlatformFeeBPS);

        uint128 requiredEtherValue = 1 ether;
        assertEq(feeRegistry.platformFee(requiredEtherValue), (requiredEtherValue * newPlatformFeeBPS) / MAX_BPS);
    }
}
