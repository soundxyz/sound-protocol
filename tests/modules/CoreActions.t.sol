pragma solidity ^0.8.16;

// import { IERC721AUpgradeable, ISoundEditionV2_1, SoundEditionV2_1 } from "@core/SoundEditionV2_1.sol";
// import { ISuperMinterV2, SuperMinterV2 } from "@modules/SuperMinterV2.sol";
// import { IPlatformAirdropper, PlatformAirdropper } from "@modules/PlatformAirdropper.sol";
// import { IAddressAliasRegistry, AddressAliasRegistry } from "@modules/AddressAliasRegistry.sol";
// import { LibOps } from "@core/utils/LibOps.sol";
// import { Ownable } from "solady/auth/Ownable.sol";
// import { LibZip } from "solady/utils/LibZip.sol";
// import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
// import { LibSort } from "solady/utils/LibSort.sol";
import "../TestConfigV2_1.sol";

contract CoreActionsTests is TestConfigV2_1 {
    function setUp() public virtual override {
        super.setUp();
        // ISoundEditionV2_1.EditionInitialization memory init = genericEditionInitialization();
        // init.tierCreations = new ISoundEditionV2_1.TierCreation[](2);
        // init.tierCreations[0].tier = 0;
        // init.tierCreations[1].tier = 1;
        // init.tierCreations[1].maxMintableLower = type(uint32).max;
        // init.tierCreations[1].maxMintableUpper = type(uint32).max;
        // edition = createSoundEdition(init);
        // sm = new SuperMinterV2();
        // edition.grantRoles(address(sm), edition.MINTER_ROLE());
        // aar = new AddressAliasRegistry();
        // pa = new PlatformAirdropper(address(aar));
    }

    // function _computeDigest()

    function _hashOf(address[] memory a) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
    }

    function _hashOf(address[][] memory a) internal pure returns (bytes32) {
        uint256 n = a.length;
        bytes32[] memory encoded = new bytes32[](n);
        for (uint256 i = 0; i != n; ++i) {
            encoded[i] = keccak256(abi.encodePacked(a[i]));
        }
        return keccak256(abi.encodePacked(encoded));
    }

    function _hashOf(uint256[][] calldata a) internal pure returns (bytes32) {
        uint256 n = a.length;
        bytes32[] memory encoded = new bytes32[](n);
        for (uint256 i = 0; i != n; ++i) {
            encoded[i] = keccak256(abi.encodePacked(a[i]));
        }
        return keccak256(abi.encodePacked(encoded));
    }
}
