pragma solidity ^0.8.16;

import "../TestConfig.sol";
import { ISoundFeeRegistry, SoundFeeRegistryV1 } from "@core/SoundFeeRegistryV1.sol";
import { MockSoundFeeRegistryV2 } from "../mocks/MockSoundFeeRegistryV2.sol";

contract SoundFeeRegistryTests is TestConfig {
    event SoundFeeAddressSet(address soundFeeAddress);
    event PlatformFeeSet(uint16 platformFeeBPS);
    event Upgraded(address indexed implementation);

    function test_deployFeeRegistry(address soundFeeAddress, uint16 platformFeeBPS) public {
        // Deploy implementation, proxy, & initialize proxy
        SoundFeeRegistryV1 feeRegistryImp = new SoundFeeRegistryV1();
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(feeRegistryImp), bytes(""));
        feeRegistry = SoundFeeRegistryV1(address(registryProxy));

        if (soundFeeAddress == address(0)) {
            // Test revert on invalid sound fee address
            vm.expectRevert(ISoundFeeRegistry.InvalidSoundFeeAddress.selector);
            feeRegistry.initialize(soundFeeAddress, platformFeeBPS);
            return;
        }

        // Test revert if platform fee BPS is invalid
        if (platformFeeBPS > MAX_BPS) {
            vm.expectRevert(ISoundFeeRegistry.InvalidPlatformFeeBPS.selector);
            feeRegistry.initialize(soundFeeAddress, platformFeeBPS);
            return;
        }

        // Test success
        feeRegistry.initialize(soundFeeAddress, platformFeeBPS);

        assertEq(feeRegistry.soundFeeAddress(), soundFeeAddress);
        assertEq(feeRegistry.platformFeeBPS(), platformFeeBPS);
    }

    // =============================================================
    //                     setSoundFeeAddress()
    // =============================================================

    // Test if setSoundFeeAddress only callable by owner
    function test_setSoundFeeAddressRevertsForNonOwner() external {
        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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

    function test_ownerCanSuccessfullyUpgrade() public {
        MockSoundFeeRegistryV2 v2Implementation = new MockSoundFeeRegistryV2();

        vm.expectEmit(true, false, false, true);
        emit Upgraded(address(v2Implementation));
        feeRegistry.upgradeTo(address(v2Implementation));

        assertEq(MockSoundFeeRegistryV2(address(feeRegistry)).success(), "Upgrade to MockSoundFeeRegistryV2 success!");
    }

    function test_attackerCantUpgrade(address attacker) public {
        vm.assume(attacker != address(this));
        vm.assume(attacker != address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        feeRegistry.upgradeTo(address(666));
    }
}
