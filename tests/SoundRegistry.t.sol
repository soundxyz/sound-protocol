pragma solidity ^0.8.15;

import "./TestConfig.sol";
import "../contracts/SoundNft/SoundNftV1.sol";
import "../contracts/SoundRegistry/SoundRegistryV1.sol";

contract SoundRegistryTests is TestConfig {
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

        address soundNft = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        bytes memory authoritySignature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundNft
        );

        // Tests valid signature from unauthorized caller
        vm.expectRevert(bytes("Unauthorized"));
        vm.prank(unauthorizedSigner);
        registry.registerSoundNft(soundNft, authoritySignature);
    }

    // Tests that the owner can't register an NFT using their own signature.
    function test_ownerCantRegisterWithOwnSignature() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);

        vm.prank(nftOwner);
        address soundNft = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(address(123));

        bytes memory ownerSignature = getRegistrationSignature(
            registry,
            nftOwnerPk,
            soundNft
        );

        // Tests wrong signature from owner (should be signing authority's signature)
        vm.expectRevert(bytes("Unauthorized"));
        registry.registerSoundNft(soundNft, ownerSignature);
    }

    // Tests that the signing authority can't register an NFT using their own signature.
    function test_signingAuthorityCantRegisterWithOwnSignature() public {
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        address soundNft = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(address(123));

        bytes memory signature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundNft
        );

        // Tests wrong signature from owner (should be signing authority's signature)
        vm.expectRevert(bytes("Unauthorized"));
        vm.prank(signerAuthority);
        registry.registerSoundNft(soundNft, signature);
    }

    // Tests signing authority can register an NFT.
    function test_signingAuthorityCanRegisterNft() public {
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);

        vm.prank(nftOwner);
        address soundNft = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by NFT owner
        bytes memory signature = getRegistrationSignature(
            registry,
            nftOwnerPk,
            soundNft
        );

        vm.prank(signerAuthority);
        registry.registerSoundNft(soundNft, signature);

        assertEq(registry.registeredSoundNfts(soundNft), true);
    }

    // Tests NFT owner can register their NFT.
    function test_ownerCanRegisterNft() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        vm.prank(nftOwner);
        address soundNft = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundNft
        );

        vm.prank(nftOwner);
        registry.registerSoundNft(soundNft, signature);

        assertEq(registry.registeredSoundNfts(soundNft), true);
    }

    // Tests registering multiple NFTs.
    function test_registerSoundNfts() public {
        uint256 nftOwnerPk = 0x234;
        address nftOwner = vm.addr(nftOwnerPk);
        uint256 signerAuthorityPk = 0x123;
        address signerAuthority = vm.addr(signerAuthorityPk);

        vm.startPrank(nftOwner);
        address soundNft1 = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);
        address soundNft2 = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);
        address soundNft3 = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);
        vm.stopPrank();

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature1 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundNft1
        );
        bytes memory signature2 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundNft2
        );
        bytes memory signature3 = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundNft3
        );

        SoundRegistryV1.SoundNftData[]
            memory data = new SoundRegistryV1.SoundNftData[](3);
        data[0].soundNft = soundNft1;
        data[0].signature = signature1;
        data[1].soundNft = soundNft2;
        data[1].signature = signature2;
        data[2].soundNft = soundNft3;
        data[2].signature = signature3;

        vm.prank(nftOwner);
        registry.registerSoundNfts(data);

        assertEq(registry.registeredSoundNfts(soundNft1), true);
        assertEq(registry.registeredSoundNfts(soundNft2), true);
        assertEq(registry.registeredSoundNfts(soundNft3), true);
    }

    // Tests that unauthorized accounts can't unregister a Sound NFT.
    function test_unauthorizedUnregisterSoundNft(address unauthorizedAccount)
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
        address soundNft = soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL);

        SoundRegistryV1 registry = new SoundRegistryV1();
        registry.initialize(signerAuthority);

        // Signed by signing authority
        bytes memory signature = getRegistrationSignature(
            registry,
            signerAuthorityPk,
            soundNft
        );

        vm.prank(nftOwner);
        registry.registerSoundNft(soundNft, signature);

        // Tests unauthorized account can't unregister NFT
        vm.expectRevert(bytes("Unauthorized"));
        vm.prank(unauthorizedAccount);
        registry.unregisterSoundNft(soundNft);
    }

    // Tests unregistering a Sound NFT.
    function test_unregisterSoundNft() public {}

    // Tests unregistering multiple Sound NFTs.
    function test_unregisterSoundNfts() public {}
}
