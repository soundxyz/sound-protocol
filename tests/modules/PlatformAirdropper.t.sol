pragma solidity ^0.8.16;

import { IERC721AUpgradeable, ISoundEditionV2_1, SoundEditionV2_1 } from "@core/SoundEditionV2_1.sol";
import { ISuperMinterV2, SuperMinterV2 } from "@modules/SuperMinterV2.sol";
import { IPlatformAirdropper, PlatformAirdropper } from "@modules/PlatformAirdropper.sol";
import { IAddressAliasRegistry, AddressAliasRegistry } from "@modules/AddressAliasRegistry.sol";
import { LibOps } from "@core/utils/LibOps.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import "../TestConfigV2_1.sol";

contract PlatformAirdropperTests is TestConfigV2_1 {
    SuperMinterV2 sm;
    SoundEditionV2_1 edition;
    PlatformAirdropper pa;
    AddressAliasRegistry aar;

    mapping(uint256 => mapping(address => uint256)) internal _expectedMintCounts;

    function setUp() public virtual override {
        super.setUp();
        ISoundEditionV2_1.EditionInitialization memory init = genericEditionInitialization();
        init.tierCreations = new ISoundEditionV2_1.TierCreation[](2);
        init.tierCreations[0].tier = 0;
        init.tierCreations[1].tier = 1;
        init.tierCreations[1].maxMintableLower = type(uint32).max;
        init.tierCreations[1].maxMintableUpper = type(uint32).max;
        edition = createSoundEdition(init);
        sm = new SuperMinterV2();
        edition.grantRoles(address(sm), edition.MINTER_ROLE());
        aar = new AddressAliasRegistry();
        pa = new PlatformAirdropper(address(aar));
    }

    function test_platformAirdrop(uint256) public {
        (address signer, uint256 privateKey) = _randomSigner();

        ISuperMinterV2.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = address(this);
        c.edition = address(edition);
        c.startTime = 0;
        c.tier = uint8(_random() % 2);
        c.endTime = type(uint32).max;
        c.maxMintablePerAccount = uint32(_random()); // Doesn't matter, will be auto set to max.
        c.mode = sm.PLATFORM_AIRDROP();
        assertEq(sm.createEditionMint(c), 0);

        vm.prank(c.platform);
        sm.setPlatformSigner(signer);

        unchecked {
            ISuperMinterV2.PlatformAirdrop memory p;
            p.edition = address(edition);
            p.tier = c.tier;
            p.scheduleNum = 0;
            while (p.to.length == 0) p.to = _randomNonZeroAddressesGreaterThan();
            p.signedQuantity = uint32(_bound(_random(), 1, 8));
            p.signedClaimTicket = uint32(_bound(_random(), 0, type(uint32).max));
            p.signedDeadline = type(uint32).max;
            p.signature = _generatePlatformAirdropSignature(p, privateKey);

            for (uint256 i; i != p.to.length; ++i) {
                _expectedMintCounts[0][p.to[i]] += p.signedQuantity;
            }

            address[][2] memory aliases;
            (, aliases[0]) = pa.platformAirdrop(address(sm), p);

            if (_random() % 8 == 0) {
                for (uint256 i; i < p.to.length; ++i) {
                    uint256 k = _expectedMintCounts[0][p.to[i]];
                    assertEq(edition.balanceOf(p.to[i]), k);
                    assertEq(sm.numberMinted(address(edition), p.tier, p.scheduleNum, p.to[i]), k);
                }
            }

            p.signedClaimTicket ^= 1;
            p.signature = _generatePlatformAirdropSignature(p, privateKey);
            // Note that we replace the addresses AFTER signing.
            p.to = aliases[0];

            uint256 numAliases = aar.numAliases();
            (, aliases[1]) = pa.platformAirdrop(address(sm), p);
            assertEq(aar.numAliases(), numAliases);
            assertEq(aliases[0], aliases[1]);

            (, p.to) = aar.resolve(p.to);

            if (_random() % 8 == 0) {
                for (uint256 i; i < p.to.length; ++i) {
                    uint256 k = _expectedMintCounts[0][p.to[i]] * 2;
                    assertEq(edition.balanceOf(p.to[i]), k);
                    assertEq(sm.numberMinted(address(edition), p.tier, p.scheduleNum, p.to[i]), k);
                }
            }

            assertEq(_uniquified(p.to).length, numAliases);
        }
    }

    function test_platformAirdropMulti(uint256) public {
        (address signer, uint256 privateKey) = _randomSigner();

        ISuperMinterV2.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = address(this);
        c.edition = address(edition);
        c.startTime = 0;
        c.tier = uint8(_random() % 2);
        c.endTime = type(uint32).max;
        c.maxMintablePerAccount = uint32(_random()); // Doesn't matter, will be auto set to max.
        c.mode = sm.PLATFORM_AIRDROP();
        assertEq(sm.createEditionMint(c), 0);

        vm.prank(c.platform);
        sm.setPlatformSigner(signer);

        unchecked {
            ISuperMinterV2.PlatformAirdrop[] memory p = new ISuperMinterV2.PlatformAirdrop[](2);
            for (uint256 j; j != 2; ++j) {
                p[j].edition = address(edition);
                p[j].tier = c.tier;
                p[j].scheduleNum = 0;
                while (p[j].to.length == 0) p[j].to = _randomNonZeroAddressesGreaterThan();
                p[j].signedQuantity = uint32(_bound(_random(), 1, 8));
                p[j].signedClaimTicket = uint32(j);
                p[j].signedDeadline = type(uint32).max;
                p[j].signature = _generatePlatformAirdropSignature(p[j], privateKey);
                for (uint256 i; i != p[j].to.length; ++i) {
                    _expectedMintCounts[0][p[j].to[i]] += p[j].signedQuantity;
                }
            }

            address[][][2] memory aliases;
            (, aliases[0]) = pa.platformAirdropMulti(address(sm), p);

            if (_random() % 8 == 0) {
                for (uint256 j; j != 2; ++j) {
                    for (uint256 i; i < p[j].to.length; ++i) {
                        uint256 k = _expectedMintCounts[0][p[j].to[i]];
                        assertEq(edition.balanceOf(p[j].to[i]), k);
                        assertEq(sm.numberMinted(address(edition), p[j].tier, p[j].scheduleNum, p[j].to[i]), k);
                    }
                }
            }

            for (uint256 j; j != 2; ++j) {
                p[j].signedClaimTicket = uint32(2 + j);
                p[j].signature = _generatePlatformAirdropSignature(p[j], privateKey);
                // Note that we replace the addresses AFTER signing.
                p[j].to = aliases[0][j];
            }

            (, aliases[1]) = pa.platformAirdropMulti(address(sm), p);
            for (uint256 j; j != 2; ++j) {
                assertEq(aliases[0][j], aliases[1][j]);
                (, p[j].to) = aar.resolve(p[j].to);
            }

            if (_random() % 8 == 0) {
                for (uint256 j; j != 2; ++j) {
                    for (uint256 i; i < p[j].to.length; ++i) {
                        uint256 k = _expectedMintCounts[0][p[j].to[i]] * 2;
                        assertEq(edition.balanceOf(p[j].to[i]), k);
                        assertEq(sm.numberMinted(address(edition), p[j].tier, p[j].scheduleNum, p[j].to[i]), k);
                    }
                }
            }

            assertEq(LibSort.union(_uniquified(p[0].to), _uniquified(p[1].to)).length, aar.numAliases());
        }
    }

    function test_platformAirdropLimit() public {
        (address signer, uint256 privateKey) = _randomSigner();

        ISuperMinterV2.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = address(this);
        c.edition = address(edition);
        c.startTime = 0;
        c.tier = 0;
        c.endTime = type(uint32).max;
        c.maxMintablePerAccount = uint32(_random()); // Doesn't matter, will be auto set to max.
        c.mode = sm.PLATFORM_AIRDROP();
        assertEq(sm.createEditionMint(c), 0);

        vm.prank(c.platform);
        sm.setPlatformSigner(signer);

        uint256 n = 256;

        ISuperMinterV2.PlatformAirdrop memory p;
        p.edition = address(edition);
        p.tier = c.tier;
        p.scheduleNum = 0;
        p.to = new address[](n);
        unchecked {
            for (uint256 i; i != n; ++i) {
                p.to[i] = address(uint160(0x123456789abcdef + i));
            }
        }
        p.signedQuantity = 1;
        p.signedClaimTicket = 1;
        p.signedDeadline = type(uint32).max;
        p.signature = _generatePlatformAirdropSignature(p, privateKey);

        pa.platformAirdrop(address(sm), p);
    }

    function _generatePlatformAirdropSignature(ISuperMinterV2.PlatformAirdrop memory p, uint256 privateKey)
        internal
        returns (bytes memory signature)
    {
        bytes32 digest = sm.computePlatformAirdropDigest(p);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _uniquified(address[] memory a) internal pure returns (address[] memory) {
        LibSort.sort(a);
        LibSort.uniquifySorted(a);
        return a;
    }

    function _randomNonZeroAddressesGreaterThan() internal returns (address[] memory a) {
        a = _randomNonZeroAddressesGreaterThan(0xffffffff);
    }

    function _randomNonZeroAddressesGreaterThan(uint256 t) internal returns (address[] memory a) {
        uint256 n = _random() % 4;
        if (_random() % 32 == 0) {
            n = _random() % 32;
        }
        a = new address[](n);
        require(t != 0, "t must not be zero");
        unchecked {
            for (uint256 i; i != n; ++i) {
                uint256 r;
                if (_random() & 1 == 0) {
                    while (r <= t) r = uint256(uint160(_random()));
                } else {
                    r = type(uint256).max ^ _bound(_random(), 1, 8);
                }
                a[i] = address(uint160(r));
            }
        }
    }
}
