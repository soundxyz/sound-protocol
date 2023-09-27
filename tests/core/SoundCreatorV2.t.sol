// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISoundEditionV2, SoundEditionV2 } from "@core/SoundEditionV2.sol";
import { ISoundCreatorV2, SoundCreatorV2 } from "@core/SoundCreatorV2.sol";
import { Ownable, OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import ".././TestPlus.sol";

contract Target {
    uint256 public x;
    uint256 public mintValue;
    address public mintedTo;

    function setX(uint256 x_) public returns (bytes32 h) {
        x = x_;
        h = keccak256(abi.encodePacked(x_));
    }

    function mint(address to) public payable {
        mintedTo = to;
        mintValue = msg.value;
        SafeTransferLib.safeTransferETH(msg.sender, msg.value);
    }
}

contract SoundCreatorV2Tests is TestPlus {
    SoundCreatorV2 sc;
    SoundEditionV2 impl;
    Target target;

    function setUp() public {
        sc = new SoundCreatorV2();
        impl = new SoundEditionV2();
        target = new Target();
    }

    struct _TestTemps {
        address owner;
        uint256 privateKey;
        bytes32 digest;
        bytes signature;
        address expectedAddress;
    }

    function _nonceIsValid(address signer, uint256 nonce) internal view returns (bool) {
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = nonce;
        bool[] memory result = sc.noncesInvalidated(signer, nonces);
        return !result[0];
    }

    function _testVars() internal returns (_TestTemps memory t, SoundCreatorV2.SoundCreation memory c) {
        (t.owner, t.privateKey) = _randomSigner();

        ISoundEditionV2.EditionInitialization memory init;
        init.fundingRecipient = address(this);
        init.tierCreations = new ISoundEditionV2.TierCreation[](1);

        c.implementation = address(impl);
        c.owner = t.owner;
        c.salt = bytes32(_random());
        c.initData = abi.encodeCall(ISoundEditionV2.initialize, init);
        c.contracts = new address[](2);
        c.contracts[0] = address(target);
        c.contracts[1] = address(target);
        c.data = new bytes[](2);
        c.data[0] = abi.encodeCall(Target.setX, 111);
        c.data[1] = abi.encodeCall(Target.setX, 222);
        c.nonce = _random();

        assertTrue(_nonceIsValid(c.owner, c.nonce));

        t.digest = sc.computeDigest(c);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(t.privateKey, t.digest);
        t.signature = abi.encodePacked(r, s, v);
        assertTrue(sc.isValidSignature(c, t.signature));

        bool exists;
        (t.expectedAddress, exists) = sc.soundEditionAddress(c.implementation, c.owner, c.salt);
        assertFalse(exists);
    }

    function testCreateWithSignature() public {
        (_TestTemps memory t, SoundCreatorV2.SoundCreation memory c) = _testVars();

        (address edition, bytes[] memory results) = sc.createWithSignature(c, t.signature);
        assertEq(edition, t.expectedAddress);
        assertEq(abi.decode(results[0], (bytes32)), keccak256(abi.encodePacked(uint256(111))));
        assertEq(abi.decode(results[1], (bytes32)), keccak256(abi.encodePacked(uint256(222))));
        assertEq(target.x(), 222);

        assertFalse(_nonceIsValid(c.owner, c.nonce));
        assertFalse(sc.isValidSignature(c, t.signature));
        vm.expectRevert(ISoundCreatorV2.InvalidSignature.selector);
        sc.createWithSignature(c, t.signature);
    }

    function testCreateWithSignatureAndMintWithoutRefund() public {
        (_TestTemps memory t, SoundCreatorV2.SoundCreation memory c) = _testVars();
        address mintTo = _randomNonZeroAddress();
        address mintBy = _randomNonZeroAddress();
        bytes memory mintData = abi.encodeCall(Target.mint, mintTo);

        vm.deal(mintBy, 1 ether);
        uint256 mintPayment = 1 ether;
        vm.prank(mintBy);
        address refundTo;
        (address edition, ) = sc.createWithSignatureAndMint{ value: mintPayment }(
            c,
            t.signature,
            address(target),
            mintData,
            refundTo
        );

        assertEq(edition, t.expectedAddress);
        assertEq(target.mintedTo(), mintTo);
        assertEq(target.mintValue(), mintPayment);
        assertEq(address(mintBy).balance, 0);
        assertEq(address(sc).balance, mintPayment);
    }

    function testCreateWithSignatureAndMintWithRefund() public {
        (_TestTemps memory t, SoundCreatorV2.SoundCreation memory c) = _testVars();
        address mintTo = _randomNonZeroAddress();
        address mintBy = _randomNonZeroAddress();
        bytes memory mintData = abi.encodeCall(Target.mint, mintTo);

        vm.deal(mintBy, 1 ether);
        uint256 mintPayment = 1 ether;
        vm.prank(mintBy);
        address refundTo = _randomNonZeroAddress();
        (address edition, ) = sc.createWithSignatureAndMint{ value: mintPayment }(
            c,
            t.signature,
            address(target),
            mintData,
            refundTo
        );

        assertEq(edition, t.expectedAddress);
        assertEq(target.mintedTo(), mintTo);
        assertEq(target.mintValue(), mintPayment);
        assertEq(address(refundTo).balance, mintPayment);
        assertEq(address(sc).balance, 0);
    }

    function testCreateWithSignatureAndMintWithRefund2() public {
        (_TestTemps memory t, SoundCreatorV2.SoundCreation memory c) = _testVars();
        address mintTo = _randomNonZeroAddress();
        address mintBy = _randomNonZeroAddress();
        bytes memory mintData = abi.encodeCall(Target.mint, mintTo);

        vm.deal(mintBy, 1 ether);
        uint256 mintPayment = 1 ether;
        vm.prank(mintBy);
        address refundTo = address(1);
        (address edition, ) = sc.createWithSignatureAndMint{ value: mintPayment }(
            c,
            t.signature,
            address(target),
            mintData,
            refundTo
        );

        assertEq(edition, t.expectedAddress);
        assertEq(target.mintedTo(), mintTo);
        assertEq(target.mintValue(), mintPayment);
        assertEq(address(mintBy).balance, mintPayment);
        assertEq(address(sc).balance, 0);
    }

    function testInvalidateNonces() public {
        address signer = _randomNonZeroAddress();
        uint256[] memory nonces = new uint256[](2);
        nonces[0] = _random();
        nonces[1] = _random();
        while (nonces[0] == nonces[1]) nonces[1] = _random();
        bool[] memory results = sc.noncesInvalidated(signer, nonces);
        assertFalse(results[0]);
        assertFalse(results[1]);
        vm.prank(signer);
        sc.invalidateNonces(nonces);
        results = sc.noncesInvalidated(signer, nonces);
        assertTrue(results[0]);
        assertTrue(results[1]);
    }
}
