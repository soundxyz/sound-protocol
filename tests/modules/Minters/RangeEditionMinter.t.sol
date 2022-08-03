pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/RangeEditionMinter.sol";

contract RangeEditionMinterTests is TestConfig {
    uint256 constant PRICE = 1;

    uint32 constant START_TIME = 100;

    uint32 constant END_TIME = 200;

    uint32 constant MAX_MINTABLE = 5;

    uint32 constant MAX_PERMISSIONED_MINTABLE = 2;

    uint256 SIGNER_PRIVATE_KEY = 1;

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 price,
        address signer,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxPermissionedMintable
    );

    event StartTimeSet(address indexed edition, uint32 indexed startTime);

    event EndTimeSet(address indexed edition, uint32 indexed endTime);

    event SignerSet(address indexed edition, address indexed signer);

    event PausedSet(address indexed edition, bool indexed paused);

    event MaxPermissionedMintableSet(address indexed edition, uint32 indexed maxPermissionedMintable);

    event MaxMintableSet(address indexed edition, uint32 indexed maxMintable);

    function _signerAddress() internal returns (address) {
        return vm.addr(SIGNER_PRIVATE_KEY);
    }

    function _getSignature(
        RangeEditionMinter minter,
        address caller,
        address edition,
        uint256[] memory ticketNumbers
    ) internal returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                minter.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(minter.PERMISSIONED_SALE_TYPEHASH(), address(minter), caller, edition, ticketNumbers)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getTicketNumbers(uint256 startTicketNumber, uint256 quantity) internal pure returns (uint256[] memory) {
        unchecked {
            uint256[] memory ticketNumbers = new uint256[](quantity);
            for (uint256 i; i < quantity; ++i) {
                ticketNumbers[i] = startTicketNumber + i;
            }
            return ticketNumbers;
        }
    }

    function _createEditionAndMinter() internal returns (SoundEditionV1 edition, RangeEditionMinter minter) {
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        minter = new RangeEditionMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            START_TIME,
            END_TIME,
            MAX_MINTABLE,
            MAX_PERMISSIONED_MINTABLE
        );
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        RangeEditionMinter minter = new RangeEditionMinter();

        vm.expectEmit(false, false, false, true);

        emit RangeEditionMintCreated(
            address(edition),
            PRICE,
            _signerAddress(),
            START_TIME,
            END_TIME,
            MAX_MINTABLE,
            MAX_PERMISSIONED_MINTABLE
        );

        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            START_TIME,
            END_TIME,
            MAX_MINTABLE,
            MAX_PERMISSIONED_MINTABLE
        );
    }

    function test_createEditionMintRevertsIfMaxMintableIsZero() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        RangeEditionMinter minter = new RangeEditionMinter();

        vm.expectRevert(RangeEditionMinter.MaxMintableIsZero.selector);
        minter.createEditionMint(address(edition), PRICE, _signerAddress(), START_TIME, END_TIME, 0, 0);

        minter.createEditionMint(address(edition), PRICE, _signerAddress(), START_TIME, END_TIME, 1, 0);
    }

    function test_createEditionMintRevertsIfInvalidTimeRange() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        RangeEditionMinter minter = new RangeEditionMinter();

        vm.expectRevert(RangeEditionMinter.InvalidTimeRange.selector);
        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            END_TIME + 1,
            END_TIME,
            MAX_MINTABLE,
            MAX_PERMISSIONED_MINTABLE
        );

        vm.expectRevert(RangeEditionMinter.InvalidTimeRange.selector);
        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            END_TIME,
            END_TIME,
            MAX_MINTABLE,
            MAX_PERMISSIONED_MINTABLE
        );

        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            END_TIME - 1,
            END_TIME,
            MAX_MINTABLE,
            MAX_PERMISSIONED_MINTABLE
        );
    }

    function test_createEditionMintRevertsIfMaxPermissionedMintableExceedsMaxMintable() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        RangeEditionMinter minter = new RangeEditionMinter();

        vm.expectRevert(RangeEditionMinter.MaxPermissionedMintableExceedsMaxMintable.selector);
        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            START_TIME,
            END_TIME,
            MAX_MINTABLE,
            MAX_MINTABLE + 1
        );

        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            START_TIME,
            END_TIME,
            MAX_MINTABLE,
            MAX_MINTABLE
        );
    }

    function test_createEditionMintRevertsIfSignerIsZeroAddressWhenMaxPermissionedMintableNotZero() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        RangeEditionMinter minter = new RangeEditionMinter();

        vm.expectRevert(RangeEditionMinter.SignerIsZeroAddress.selector);
        minter.createEditionMint(address(edition), PRICE, address(0), START_TIME, END_TIME, MAX_MINTABLE, 1);

        minter.createEditionMint(address(edition), PRICE, address(1), START_TIME, END_TIME, MAX_MINTABLE, 1);
    }

    function test_createEditionMintSetsValuesCorrectly() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        (
            uint256 price,
            address signer,
            uint32 startTime,
            uint32 endTime,
            uint32 totalMinted,
            uint32 maxMintable,
            uint32 totalPermissionedMinted,
            uint32 maxPermissionedMintable,
            bool paused
        ) = minter.editionMintData(address(edition));

        assertEq(price, PRICE);
        assertEq(signer, _signerAddress());
        assertEq(startTime, START_TIME);
        assertEq(endTime, END_TIME);
        assertEq(totalMinted, uint32(0));
        assertEq(maxMintable, MAX_MINTABLE);
        assertEq(totalPermissionedMinted, uint32(0));
        assertEq(maxPermissionedMintable, MAX_PERMISSIONED_MINTABLE);
        assertEq(paused, false);
    }

    function test_permissionedMintSetsValuesCorrectly() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;

        address caller = getRandomAccount(1);
        bytes memory sig = _getSignature(minter, caller, address(edition), _getTicketNumbers(0, quantity));

        vm.warp(START_TIME - 1);
        vm.prank(caller);
        minter.mint{ value: quantity * PRICE }(address(edition), quantity, _getTicketNumbers(0, quantity), sig);

        (, , , , uint32 totalMinted, , uint32 totalPermissionedMinted, , ) = minter.editionMintData(address(edition));
        assertEq(totalMinted, quantity);
        assertEq(totalPermissionedMinted, quantity);

        assertEq(edition.ownerOf(0), caller);
        assertEq(edition.ownerOf(1), caller);
        assertEq(edition.totalSupply(), quantity);
    }

    function test_permissionedMintRevertsForIncorrectSignature() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;

        address caller = getRandomAccount(1);
        bytes memory sig = _getSignature(minter, getRandomAccount(2), address(edition), _getTicketNumbers(0, quantity));

        vm.warp(START_TIME - 1);
        vm.prank(caller);
        vm.expectRevert(RangeEditionMinter.InvalidSignature.selector);
        minter.mint{ value: quantity * PRICE }(address(edition), quantity, _getTicketNumbers(0, quantity), sig);
    }

    // function test_mintBeforeStartTimeReverts() public {
    //     (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(START_TIME - 1);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePublicSaleMinter.MintNotStarted.selector);
    //     minter.mint{ value: PRICE }(address(edition), 1);

    //     vm.warp(START_TIME);
    //     vm.prank(caller);
    //     minter.mint{ value: PRICE }(address(edition), 1);
    // }

    // function test_mintAfterEndTimeReverts() public {
    //     (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(END_TIME + 1);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePublicSaleMinter.MintHasEnded.selector);
    //     minter.mint{ value: PRICE }(address(edition), 1);

    //     vm.warp(END_TIME);
    //     vm.prank(caller);
    //     minter.mint{ value: PRICE }(address(edition), 1);
    // }

    // function test_mintWhenSoldOutReverts() public {
    //     (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(START_TIME);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePublicSaleMinter.SoldOut.selector);
    //     minter.mint{ value: PRICE * (MAX_MINTABLE + 1) }(address(edition), MAX_MINTABLE + 1);

    //     vm.prank(caller);
    //     minter.mint{ value: PRICE * MAX_MINTABLE }(address(edition), MAX_MINTABLE);

    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePublicSaleMinter.SoldOut.selector);
    //     minter.mint{ value: PRICE }(address(edition), 1);
    // }

    // function test_mintWithWrongEtherValueReverts() public {
    //     (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(START_TIME);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePublicSaleMinter.WrongEtherValue.selector);
    //     minter.mint{ value: PRICE * 2 }(address(edition), 1);
    // }

    // function test_mintWithUnauthorizedMinterReverts() public {
    //     (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(START_TIME);

    //     address caller = getRandomAccount(1);

    //     bool status;

    //     vm.prank(caller);
    //     (status, ) = address(minter).call{ value: PRICE }(
    //         abi.encodeWithSelector(FixedPricePublicSaleMinter.mint.selector, address(edition), 1)
    //     );
    //     assertTrue(status);

    //     vm.prank(edition.owner());
    //     edition.revokeRole(edition.MINTER_ROLE(), address(minter));

    //     vm.prank(caller);
    //     (status, ) = address(minter).call{ value: PRICE }(
    //         abi.encodeWithSelector(FixedPricePublicSaleMinter.mint.selector, address(edition), 1)
    //     );
    //     assertFalse(status);
    // }
}
