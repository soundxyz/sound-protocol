pragma solidity ^0.8.15;

import "./TestConfig.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/SoundRegistry/SoundRegistryV1.sol";

contract SoundRegistryTests is TestConfig {
    event Registered(address indexed soundEdition);
    event Unregistered(address indexed soundEdition);

    event RegisteredBatch(address[] indexed soundEditions);
    event UnregisteredBatch(address[] indexed soundEditions);

    // Tests that the registry is initialized with the correct owner & signing authority.
    function test_initializedWithOwner() public {
        address signingAuthority = vm.addr(5678);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signingAuthority);

        assertEq(registry.owner(), address(this));
        assertEq(registry.signingAuthority(), signingAuthority);
    }

    // Tests that unauthorized accounts can't change the signing authority.
    function test_unauthorizedChangeSigningAuthority(address unauthorizedSigner)
        public
    {
        address signingAuthority = vm.addr(5678);

        // Don't test authorized signers
        vm.assume(
            unauthorizedSigner != signingAuthority &&
                unauthorizedSigner != address(this)
        );

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signingAuthority);

        vm.expectRevert(bytes("Unauthorized"));
        vm.prank(unauthorizedSigner);
        registry.changeSigningAuthority(unauthorizedSigner);
    }

    // Tests that the signing authority can be changed by the owner and current signing authority.
    function test_changeSigningAuthority() public {
        address originalAuthority = vm.addr(5678);
        address newAuthority = vm.addr(1234);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(originalAuthority);

        registry.changeSigningAuthority(newAuthority);

        assertEq(registry.signingAuthority(), newAuthority);

        vm.prank(newAuthority);
        registry.changeSigningAuthority(originalAuthority);

        assertEq(registry.signingAuthority(), originalAuthority);
    }

    // Tests that an unauthorized account can't register with a valid signature.
    function test_validRegistrationSignatureFromUnauthorizedAccount() public {
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);
        address unauthorizedSigner = vm.addr(345);

        address soundEdition = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        bytes memory authoritySignature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition
        );

        // Tests valid signature from unauthorized caller
        vm.expectRevert(bytes("Unauthorized"));
        vm.prank(unauthorizedSigner);
        registry.registerSoundEdition(soundEdition, authoritySignature);
    }

    // Tests that the owner can't register an NFT using their own signature.
    function test_ownerCantRegisterWithOwnSignature() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);

        vm.prank(nftOwner);
        address soundEdition = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(address(123));

        bytes memory ownerSignature = getRegistrationSignature(
            registry,
            nftOwnerPk,
            soundEdition
        );

        // Tests wrong signature from owner (should be signing authority's signature)
        vm.expectRevert(bytes("Unauthorized"));
        registry.registerSoundEdition(soundEdition, ownerSignature);
    }

    // Tests that the signing authority can't register an NFT using their own signature.
    function test_signingAuthorityCantRegisterWithOwnSignature() public {
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        address soundEdition = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(address(123));

        bytes memory signature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition
        );

        // Tests wrong signature from owner (should be signing authority's signature)
        vm.expectRevert(bytes("Unauthorized"));
        vm.prank(signerAuthority);
        registry.registerSoundEdition(soundEdition, signature);
    }

    // Tests signing authority can register an NFT.
    function test_signingAuthorityCanRegisterNft() public {
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);

        vm.prank(nftOwner);
        address soundEdition = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by NFT owner
        bytes memory signature = getRegistrationSignature(
            registry,
            nftOwnerPk,
            soundEdition
        );

        vm.expectEmit(true, true, true, true);
        emit Registered(soundEdition);

        vm.prank(signerAuthority);
        registry.registerSoundEdition(soundEdition, signature);

        assertEq(registry.registeredSoundEditions(soundEdition), true);
    }

    // Tests NFT owner can register their NFT.
    function test_ownerCanRegisterNft() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        vm.prank(nftOwner);
        address soundEdition = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition
        );

        vm.expectEmit(true, true, true, true);
        emit Registered(soundEdition);

        vm.prank(nftOwner);
        registry.registerSoundEdition(soundEdition, signature);

        assertEq(registry.registeredSoundEditions(soundEdition), true);
    }

    // Tests registering multiple NFTs.
    function test_registerSoundEditions() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        vm.startPrank(nftOwner);
        address soundEdition1 = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);
        address soundEdition2 = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);
        address soundEdition3 = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);
        vm.stopPrank();

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature1 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition1
        );
        bytes memory signature2 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition2
        );
        bytes memory signature3 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition3
        );

        SoundRegistryV1.SoundEditionData[]
            memory data = new SoundRegistryV1.SoundEditionData[](3);
        data[0].soundEdition = soundEdition1;
        data[0].signature = signature1;
        data[1].soundEdition = soundEdition2;
        data[1].signature = signature2;
        data[2].soundEdition = soundEdition3;
        data[2].signature = signature3;

        // Test event
        address[] memory nfts = new address[](3);
        nfts[0] = soundEdition1;
        nfts[1] = soundEdition2;
        nfts[2] = soundEdition3;
        vm.expectEmit(true, true, true, true);
        emit RegisteredBatch(nfts);

        vm.prank(nftOwner);
        registry.registerSoundEditions(data);

        assertEq(registry.registeredSoundEditions(soundEdition1), true);
        assertEq(registry.registeredSoundEditions(soundEdition2), true);
        assertEq(registry.registeredSoundEditions(soundEdition3), true);
    }

    // Tests that unauthorized accounts can't unregister a Sound NFT.
    function test_unauthorizedUnregisterSoundEdition(address unauthorizedAccount)
        public
    {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        vm.assume(
            unauthorizedAccount != nftOwner &&
                unauthorizedAccount != signerAuthority
        );

        vm.prank(nftOwner);
        address soundEdition = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition
        );

        vm.prank(nftOwner);
        registry.registerSoundEdition(soundEdition, signature);

        // Tests unauthorized account can't unregister NFT
        vm.expectRevert(bytes("Unauthorized"));
        vm.prank(unauthorizedAccount);
        registry.unregisterSoundEdition(soundEdition);
    }

    // Tests unregistering a Sound NFT.
    function test_unregisterSoundEdition() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        vm.prank(nftOwner);
        address soundEdition = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition
        );

        vm.prank(nftOwner);
        registry.registerSoundEdition(soundEdition, signature);

        assertEq(registry.registeredSoundEditions(soundEdition), true);

        // Test event
        vm.expectEmit(true, true, true, true);
        emit Unregistered(soundEdition);

        vm.prank(nftOwner);
        registry.unregisterSoundEdition(soundEdition);

        assertEq(registry.registeredSoundEditions(soundEdition), false);
    }

    // Tests unregistering multiple Sound NFTs.
    function test_unregisterSoundEditions() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        vm.startPrank(nftOwner);
        address soundEdition1 = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);
        address soundEdition2 = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);
        address soundEdition3 = soundCreator.createSound(SONG_NAME, SONG_SYMBOL);
        vm.stopPrank();

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature1 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition1
        );
        bytes memory signature2 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition2
        );
        bytes memory signature3 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundEdition3
        );

        SoundRegistryV1.SoundEditionData[]
            memory data = new SoundRegistryV1.SoundEditionData[](3);
        data[0].soundEdition = soundEdition1;
        data[0].signature = signature1;
        data[1].soundEdition = soundEdition2;
        data[1].signature = signature2;
        data[2].soundEdition = soundEdition3;
        data[2].signature = signature3;

        vm.prank(nftOwner);
        registry.registerSoundEditions(data);

        assertEq(registry.registeredSoundEditions(soundEdition1), true);
        assertEq(registry.registeredSoundEditions(soundEdition2), true);
        assertEq(registry.registeredSoundEditions(soundEdition3), true);

        // Test event
        address[] memory nfts = new address[](3);
        nfts[0] = soundEdition1;
        nfts[1] = soundEdition2;
        nfts[2] = soundEdition3;
        vm.expectEmit(true, true, true, true);
        emit UnregisteredBatch(nfts);

        vm.prank(nftOwner);
        registry.unregisterSoundEditions(nfts);

        assertEq(registry.registeredSoundEditions(soundEdition1), false);
        assertEq(registry.registeredSoundEditions(soundEdition2), false);
        assertEq(registry.registeredSoundEditions(soundEdition3), false);
    }
}
