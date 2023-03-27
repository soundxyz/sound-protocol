// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
import { ISoundEditionV1_2, EditionInfo } from "@core/interfaces/ISoundEditionV1_2.sol";
import { ISoundEditionV1_1 } from "@core/interfaces/ISoundEditionV1_1.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";
import { MulticallerWithSender } from "multicaller/MulticallerWithSender.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

import { TestConfig } from "../../TestConfig.sol";

contract MulticallerWithSenderUpgradeable is MulticallerWithSender {
    function initialize() external {
        assembly {
            sstore(0, shl(160, 1))
        }
    }
}

contract MulticallerWithSenderAttacker {
    fallback() external payable {
        address[] memory targets = new address[](1);
        targets[0] = msg.sender;

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(ISoundEditionV1_2.setRoyalty.selector, msg.sender, uint16(12));

        MulticallerWithSender multicallerWithSender = MulticallerWithSender(
            payable(LibMulticaller.MULTICALLER_WITH_SENDER)
        );

        multicallerWithSender.aggregateWithSender(targets, data, new uint256[](1));
    }
}

/**
 * @dev Miscellaneous tests for SoundEdition
 */
contract SoundEdition_misc is TestConfig {
    event SoundEditionInitialized(
        address indexed edition_,
        string name_,
        string symbol_,
        address metadataModule_,
        string baseURI_,
        string contractURI_,
        address fundingRecipient_,
        uint16 royaltyBPS_,
        uint32 editionMaxMintableLower_,
        uint32 editionMaxMintableUpper_,
        uint32 editionCutoffTime_,
        uint8 flags_
    );

    event OperatorFilteringEnablededSet(bool operatorFilteringEnabled_);

    error TransferCallerNotOwnerNorApproved();

    function test_createSoundEmitsEvent() public {
        vm.expectEmit(true, true, true, true);

        (address soundEditionAddress, ) = soundCreator.soundEditionAddress(address(this), bytes32(_salt + 1));

        emit SoundEditionInitialized(
            soundEditionAddress,
            SONG_NAME,
            SONG_SYMBOL,
            METADATA_MODULE,
            BASE_URI,
            CONTRACT_URI,
            FUNDING_RECIPIENT,
            ROYALTY_BPS,
            EDITION_MAX_MINTABLE,
            EDITION_MAX_MINTABLE,
            EDITION_CUTOFF_TIME,
            FLAGS
        );

        SoundEditionV1_2(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                EDITION_MAX_MINTABLE,
                EDITION_MAX_MINTABLE,
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );
    }

    function test_supportsInterface() public {
        SoundEditionV1_2 edition = createGenericEdition();
        bool supportsEditionIface = edition.supportsInterface(type(ISoundEditionV1_2).interfaceId);
        assertTrue(supportsEditionIface);
        supportsEditionIface = edition.supportsInterface(type(ISoundEditionV1_1).interfaceId);
        assertTrue(supportsEditionIface);
        supportsEditionIface = edition.supportsInterface(type(ISoundEditionV1).interfaceId);
        assertTrue(supportsEditionIface);
        bool supports165 = edition.supportsInterface(type(IERC165).interfaceId);
        assertTrue(supports165);
    }

    function test_operatorFilterer() public {
        SoundEditionV1_2[2] memory editions;

        for (uint8 i; i < 2; ++i) {
            editions[i] = SoundEditionV1_2(
                createSound(
                    SONG_NAME,
                    SONG_SYMBOL,
                    METADATA_MODULE,
                    BASE_URI,
                    CONTRACT_URI,
                    FUNDING_RECIPIENT,
                    ROYALTY_BPS,
                    EDITION_MAX_MINTABLE,
                    EDITION_MAX_MINTABLE,
                    EDITION_CUTOFF_TIME,
                    FLAGS | (i * createGenericEdition().OPERATOR_FILTERING_ENABLED_FLAG())
                )
            );
            assertEq(editions[i].operatorFilteringEnabled(), i > 0);

            uint256 randomness = uint256(keccak256(abi.encode(i)));
            for (uint8 j; j < 8; ++j) {
                bool enabled = randomness & 1 == 0;
                vm.expectEmit(true, true, true, true);
                emit OperatorFilteringEnablededSet(enabled);
                editions[i].setOperatorFilteringEnabled(enabled);
                assertEq(editions[i].operatorFilteringEnabled(), enabled);
                randomness = randomness >> 1;
            }
            editions[i].setOperatorFilteringEnabled(i > 0);
        }

        // Test whether enabling the operator filter affects the transfer functions.
        // For brevity, we will outsource the tests for whether the filterer works to
        // the closedsea library. Otherwise, we will need like a whole lot of duplicated tests.

        uint256 gasUsedForDisabled;
        uint256 gasUsedForEnabled;
        uint256 gasBefore;

        address alice = address(0xa11ce);

        // Mint and set approval for all on both editions.
        for (uint256 t; t < 2; ++t) {
            editions[t].mint(alice, 3);
            vm.prank(alice);
            editions[t].setApprovalForAll(address(this), true);
        }

        // `transferFrom(address from, address to, uint256 tokenId)`.

        gasBefore = gasleft();
        editions[0].transferFrom(alice, address(1), 1);
        gasUsedForDisabled = gasBefore - gasleft();

        gasBefore = gasleft();
        editions[1].transferFrom(alice, address(1), 1);
        gasUsedForEnabled = gasBefore - gasleft();

        assertTrue(gasUsedForEnabled > gasUsedForDisabled);

        // Test `safeTransferFrom(address from, address to, uint256 tokenId)`.

        gasBefore = gasleft();
        editions[0].safeTransferFrom(alice, address(1), 2);
        gasUsedForDisabled = gasBefore - gasleft();

        gasBefore = gasleft();
        editions[1].safeTransferFrom(alice, address(1), 2);
        gasUsedForEnabled = gasBefore - gasleft();

        assertTrue(gasUsedForEnabled > gasUsedForDisabled);

        // Test `safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)`.

        gasBefore = gasleft();
        editions[0].safeTransferFrom(alice, address(1), 3, bytes(""));
        gasUsedForDisabled = gasBefore - gasleft();
        gasBefore = gasleft();
        editions[1].safeTransferFrom(alice, address(1), 3, bytes(""));
        gasUsedForEnabled = gasBefore - gasleft();

        assertTrue(gasUsedForEnabled > gasUsedForDisabled);
    }

    function test_multicallerSupport(uint256) public {
        MulticallerWithSender multicallerWithSender = MulticallerWithSender(
            payable(LibMulticaller.MULTICALLER_WITH_SENDER)
        );
        vm.etch(LibMulticaller.MULTICALLER_WITH_SENDER, bytes(address(new MulticallerWithSenderUpgradeable()).code));
        MulticallerWithSenderUpgradeable(payable(LibMulticaller.MULTICALLER_WITH_SENDER)).initialize();

        SoundEditionV1_2 edition = createGenericEdition();

        MulticallerWithSenderAttacker attacker = new MulticallerWithSenderAttacker();

        address fundingRecipient = address(attacker);
        uint16 royaltyBPS = uint16(_bound(_random(), 0, 10));

        address[] memory targets = new address[](2);
        targets[0] = address(edition);
        targets[1] = address(edition);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SoundEditionV1_2.setFundingRecipient.selector, fundingRecipient);
        data[1] = abi.encodeWithSelector(SoundEditionV1_2.setRoyalty.selector, royaltyBPS);

        bool isUnauthorized;
        if (_random() % 16 == 0) {
            vm.startPrank(address(1));
            vm.expectRevert(Ownable.Unauthorized.selector);
            isUnauthorized = true;
        } else if (_random() % 2 == 0) {
            edition.grantRoles(address(this), edition.ADMIN_ROLE());
            edition.transferOwnership(address(1));
        }
        multicallerWithSender.aggregateWithSender(targets, data, new uint256[](data.length));
        if (isUnauthorized) {
            return;
        }

        EditionInfo memory info = edition.editionInfo();

        assertEq(info.royaltyBPS, royaltyBPS);
        assertEq(info.fundingRecipient, fundingRecipient);

        vm.deal(address(edition), 1 ether);

        edition.withdrawETH();

        assertEq(edition.editionInfo().royaltyBPS, royaltyBPS);
    }
}
