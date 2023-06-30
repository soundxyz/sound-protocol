pragma solidity ^0.8.16;

import { Merkle } from "murky/Merkle.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { IERC721AUpgradeable, ISoundEditionV1_2, SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
import { ISAMV1_1, SAMV1_1, SAMInfo } from "@modules/SAMV1_1.sol";
import { ISAM } from "@modules/SAM.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { LibPRNG } from "solady/utils/LibPRNG.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";
import { MulticallerWithSender } from "multicaller/MulticallerWithSender.sol";
import { IOpenGoldenEggMetadata, OpenGoldenEggMetadata } from "@modules/OpenGoldenEggMetadata.sol";
import "../TestConfig.sol";

contract EvilEdition {
    address public owner;
    uint256 public dummy;

    constructor() {
        owner = msg.sender;
    }

    function mintConcluded() public pure returns (bool) {
        return false;
    }

    function samMint(address to, uint256 quantity) public payable returns (uint256) {
        dummy = uint256(uint160(to)) | quantity;
        return 1;
    }

    function samBurn(address from, uint256[] memory tokenIds) public {
        dummy = uint256(uint160(from)) | tokenIds.length;
    }

    // The following are to allow withdrawing the golden egg fees.

    function metadataModule() public view returns (address) {
        return address(this);
    }

    function getGoldenEggTokenId(address) public pure returns (uint256) {
        return 1;
    }

    function ownerOf(uint256) public view returns (address) {
        return owner;
    }
}

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
        data[0] = abi.encodeWithSelector(ISAMV1_1.setAffiliateFee.selector, msg.sender, uint16(12));

        MulticallerWithSender multicallerWithSender = MulticallerWithSender(
            payable(LibMulticaller.MULTICALLER_WITH_SENDER)
        );

        multicallerWithSender.aggregateWithSender(targets, data, new uint256[](1));
    }
}

contract MockSAM is SAMV1_1 {
    bool internal _checkEdition;

    function directSetPoolBalance(address edition, uint256 balance) public {
        _samData[edition].balance = SafeCastLib.toUint112(balance);
    }

    function setCheckEdition(bool value) public {
        _checkEdition = value;
    }

    function _requireEditionIsApproved(
        address edition,
        address by,
        bytes32 salt
    ) internal view virtual override {
        if (_checkEdition) {
            super._requireEditionIsApproved(edition, by, salt);
        }
    }

    function create(
        address edition,
        uint96 basePrice,
        uint128 linearPriceSlope,
        uint128 inflectionPrice,
        uint32 inflectionPoint,
        uint32 maxSupply,
        uint32 buyFreezeTime,
        uint16 artistFeeBPS,
        uint16 goldenEggFeeBPS,
        uint16 affiliateFeeBPS
    ) public {
        super.create(
            edition,
            basePrice,
            linearPriceSlope,
            inflectionPrice,
            inflectionPoint,
            maxSupply,
            buyFreezeTime,
            artistFeeBPS,
            goldenEggFeeBPS,
            affiliateFeeBPS,
            address(0),
            bytes32(0)
        );
    }

    function buy(
        address edition,
        address to,
        uint32 quantity
    ) public payable {
        super.buy(edition, to, quantity, address(0), MerkleProofLib.emptyProof(), 0);
    }

    function buy(
        address edition,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) public payable {
        super.buy(edition, to, quantity, affiliate, affiliateProof, 0);
    }

    function sell(
        address edition,
        uint256[] calldata tokenIds,
        uint256 minimumPayout,
        address payoutTo
    ) external {
        super.sell(edition, tokenIds, minimumPayout, payoutTo, 0);
    }
}

contract SAMTests is TestConfig {
    using LibPRNG for LibPRNG.PRNG;

    uint96 constant BASE_PRICE = 0.01 ether;

    uint128 constant LINEAR_PRICE_SLOPE = 0.1 ether;

    uint128 constant INFLECTION_PRICE = 1.3 ether;

    uint32 constant INFLECTION_POINT = 50;

    uint32 constant END_TIME = 300;

    uint16 constant ARTIST_FEE_BPS = 500;

    uint16 constant AFFILIATE_FEE_BPS = 100;

    uint16 constant GOLDEN_EGG_FEE_BPS = 50;

    uint32 constant EDITION_MAX_MINTABLE_LOWER = 5;

    uint32 constant MAX_SUPPLY = 2**32 - 1;

    uint32 constant BUY_FREEZE_TIME = 2**32 - 1;

    event Created(
        address indexed edition,
        uint96 basePrice,
        uint128 linearPriceSlope,
        uint128 inflectionPrice,
        uint32 inflectionPoint,
        uint32 maxSupply,
        uint32 buyFreezeTime,
        uint16 artistFeeBPS,
        uint16 goldenEggFeeBPS,
        uint16 affiliateFeeBPS
    );

    event Bought(
        address indexed edition,
        address indexed buyer,
        uint256 fromTokenId,
        uint32 fromCurveSupply,
        uint32 quantity,
        uint128 totalPayment,
        uint128 platformFee,
        uint128 artistFee,
        uint128 goldenEggFee,
        uint128 affiliateFee,
        address affiliate,
        bool affiliated,
        uint256 indexed attributionId
    );

    event Sold(
        address indexed edition,
        address indexed seller,
        uint32 fromCurveSupply,
        uint256[] tokenIds,
        uint128 totalPayout,
        uint256 indexed attributionId
    );

    event BasePriceSet(address indexed edition, uint96 basePrice);

    event LinearPriceSlopeSet(address indexed edition, uint128 linearPriceSlope);

    event InflectionPriceSet(address indexed edition, uint128 inflectionPrice);

    event InflectionPointSet(address indexed edition, uint32 inflectionPoint);

    event ArtistFeeSet(address indexed edition, uint16 bps);

    event AffiliateFeeSet(address indexed edition, uint16 bps);

    event AffiliateMerkleRootSet(address indexed edition, bytes32 root);

    event GoldenEggFeeSet(address indexed edition, uint16 bps);

    event MaxSupplySet(address indexed edition, uint32 maxSupply);

    event BuyFreezeTimeSet(address indexed edition, uint32 buyFreezeTime);

    event PlatformFeeSet(uint16 bps);

    event PlatformFeeAddressSet(address addr);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event AffiliateFeesWithdrawn(address indexed affiliate, uint256 accrued);

    event GoldenEggFeesWithdrawn(address indexed edition, address indexed recipient, uint128 accrued);

    event PlatformFeesWithdrawn(uint128 accrued);

    event ApprovedEditionFactoriesSet(address[] factories);

    struct _testTempVariables {
        uint256 basePrice;
        uint256 linearPriceSlope;
        uint256 inflectionPrice;
        uint256 inflectionPoint;
        uint256 maxSupply;
        uint256 buyFreezeTime;
        uint256 artistFeeBPS;
        uint256 affiliateFeeBPS;
        uint256 goldenEggFeeBPS;
        uint256[2] totalBuyPrices;
        uint256[2] quantities;
        uint256[2] payments;
        uint256[2] totalSellPrices;
        uint256[2] payouts;
        uint256[2] balancesBefore;
        uint256[2] balancesAfter;
        address[2] collectors;
        address[2] affiliates;
        uint256[][2] tokenIds;
        uint256[] goldenEggIds;
        uint256 totalInflows;
        uint256 totalPoolValue;
        uint256 totalGoldenEggFeesAccrued;
        uint256 totalArtistFeesAccrued;
        uint256 totalAffiliateFeesAccrued;
        uint256 platformFeesAccrued;
        uint256 totalFees;
        uint256 platformFeeBPS;
        uint256 fromTokenId;
        uint256 totalFeeBPS;
        uint256 feePerBPS;
        uint256 artistFee;
        uint256 platformFee;
        uint256 goldenEggFee;
        uint256 affiliateFee;
        uint256 numMintedBefore;
        uint256 numCollectedBefore;
        uint256 numBurnedBefore;
        uint256 totalSupplyBefore;
        uint256 maxArtistFeeBPS;
        uint256 maxAffiliateFeeBPS;
        uint256 maxGoldenEggFeeBPS;
        uint256 maxPlatformFeeBPS;
        uint256 attributionId;
        address affiliate;
    }

    function test_supportsInterface() public {
        MockSAM sam = new MockSAM();

        bool supportsISAMV1_1 = sam.supportsInterface(type(ISAMV1_1).interfaceId);
        bool supportsISAM = sam.supportsInterface(type(ISAM).interfaceId);
        bool supports165 = sam.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsISAM);
        assertTrue(supportsISAMV1_1);
    }

    function _createEditionAndSAM() internal returns (SoundEditionV1_2 edition, MockSAM sam) {
        edition = createGenericEdition();

        edition.setEditionMaxMintableRange(EDITION_MAX_MINTABLE_LOWER, EDITION_MAX_MINTABLE_LOWER);
        edition.setEditionCutoffTime(0);
        _setOpenGoldenEggMetadataModule(edition);

        sam = new MockSAM();

        edition.setSAM(address(sam));

        sam.create(
            address(edition),
            BASE_PRICE,
            LINEAR_PRICE_SLOPE,
            INFLECTION_PRICE,
            INFLECTION_POINT,
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            ARTIST_FEE_BPS,
            GOLDEN_EGG_FEE_BPS,
            AFFILIATE_FEE_BPS
        );
    }

    function _getGoldenEggId(SoundEditionV1_2 edition) internal view returns (uint256) {
        return IOpenGoldenEggMetadata(edition.metadataModule()).getGoldenEggTokenId(address(edition));
    }

    function _maxMint(SoundEditionV1_2 edition) internal {
        edition.mint(address(this), edition.editionMaxMintable());
    }

    function _mintOut(SoundEditionV1_2 edition) internal {
        if (_random() % 2 == 0) {
            _maxMint(edition);
        } else if (_random() % 2 == 0) {
            edition.setEditionMaxMintableRange(0, 0);
        } else if (_random() % 2 == 0) {
            edition.mint(address(this), 1);
            edition.setEditionCutoffTime(1);
            edition.setEditionMaxMintableRange(1, EDITION_MAX_MINTABLE_LOWER);
        } else {
            edition.setEditionCutoffTime(1);
            edition.setEditionMaxMintableRange(0, EDITION_MAX_MINTABLE_LOWER);
        }
    }

    function _setOpenGoldenEggMetadataModule(SoundEditionV1_2 edition) internal {
        edition.setMetadataModule(address(new OpenGoldenEggMetadata()));
    }

    function _randomCollectors() internal returns (address[2] memory collectors) {
        do {
            (collectors[0], ) = _randomSigner();
            (collectors[1], ) = _randomSigner();
            if (collectors[0] == address(this) || collectors[1] == address(this)) continue;
        } while (collectors[0] == collectors[1]);

        vm.deal(collectors[0], type(uint192).max);
        vm.deal(collectors[1], type(uint192).max);
    }

    function test_balanceExploitReverts() public {
        (address exploiter, ) = _randomSigner();
        vm.startPrank(exploiter);
        vm.deal(exploiter, 1);

        MockSAM sam = new MockSAM();
        EvilEdition edition = new EvilEdition();

        vm.deal(address(sam), 1000 ether);

        sam.create(
            address(edition),
            0, // Linear price slope.
            0, // Base price.
            1, // Inflection price.
            type(uint32).max, // Inflection point.
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            1000, // Artist fee BPS.
            0, // Golden egg fee BPS.
            0 // Affiliate fee BPS.
        );

        sam.buy{ value: 1 }(address(edition), exploiter, 1, address(0), new bytes32[](0));

        vm.expectRevert(ISAMV1_1.InSAMPhase.selector);
        sam.setInflectionPrice(address(edition), 500 ether);
        vm.expectRevert(ISAMV1_1.InSAMPhase.selector);
        sam.setInflectionPoint(address(edition), 1);
        vm.expectRevert(ISAMV1_1.InSAMPhase.selector);
        sam.setBasePrice(address(edition), 100 ether);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.expectRevert(abi.encodeWithSignature("InsufficientPayout(uint256,uint256)", 0, 1 ether));
        sam.sell(address(edition), tokenIds, 1 ether, exploiter);

        sam.sell(address(edition), tokenIds, 0 ether, exploiter);
    }

    function test_balanceExploitCannotWork(uint256) public {
        _testTempVariables memory t;
        (address exploiter, ) = _randomSigner();
        vm.startPrank(exploiter);
        vm.deal(exploiter, type(uint192).max);
        uint256 exploiterBalanceBefore = exploiter.balance;

        MockSAM sam = new MockSAM();
        EvilEdition edition = new EvilEdition();

        t.maxArtistFeeBPS = sam.MAX_ARTIST_FEE_BPS();
        t.maxAffiliateFeeBPS = sam.MAX_AFFILIATE_FEE_BPS();
        t.maxGoldenEggFeeBPS = sam.MAX_GOLDEN_EGG_FEE_BPS();
        t.maxPlatformFeeBPS = sam.MAX_PLATFORM_FEE_BPS();

        t.basePrice = _bound(_random(), 0, type(uint96).max);
        t.linearPriceSlope = _bound(_random(), 1, type(uint96).max);
        t.inflectionPrice = _bound(_random(), 1, type(uint96).max);
        t.inflectionPoint = _bound(_random(), 1, type(uint32).max);
        t.maxSupply = _bound(_random(), 0, type(uint32).max);
        t.buyFreezeTime = _bound(_random(), 0, type(uint32).max);
        t.artistFeeBPS = _bound(_random(), 0, t.maxArtistFeeBPS);
        t.affiliateFeeBPS = _bound(_random(), 0, t.maxAffiliateFeeBPS);
        t.goldenEggFeeBPS = _bound(_random(), 0, t.maxGoldenEggFeeBPS);

        sam.create(
            address(edition),
            uint96(t.basePrice),
            uint128(t.linearPriceSlope),
            uint128(t.inflectionPrice),
            uint32(t.inflectionPoint),
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            uint16(t.artistFeeBPS),
            uint16(t.goldenEggFeeBPS),
            uint16(t.affiliateFeeBPS)
        );

        (address affiliate, ) = _randomSigner();
        uint256 n = _bound(_random(), 1, 10);
        uint256 samBaseBalance = type(uint192).max;
        vm.deal(address(sam), samBaseBalance);
        assertEq(address(sam).balance, samBaseBalance);
        sam.buy{ value: exploiter.balance }(address(edition), exploiter, uint32(n), affiliate, new bytes32[](0));

        try sam.setInflectionPrice(address(edition), uint96(_random())) {} catch {}
        try sam.setInflectionPoint(address(edition), uint32(_random())) {} catch {}
        try sam.setBasePrice(address(edition), uint32(_random())) {} catch {}
        try sam.setAffiliateFee(address(edition), uint16(_random())) {} catch {}
        try sam.setGoldenEggFee(address(edition), uint16(_random())) {} catch {}
        try sam.setArtistFee(address(edition), uint16(_random())) {} catch {}
        try sam.setPlatformFee(uint16(_random())) {} catch {}

        // If the contract is not watertight, one of the following asserts or transactions will fail.

        assertEq(
            address(sam).balance,
            samBaseBalance +
                sam.totalValue(address(edition), 0, uint32(n)) +
                sam.affiliateFeesAccrued(affiliate) +
                sam.platformFeesAccrued() +
                sam.goldenEggFeesAccrued(address(edition))
        );

        uint256[] memory tokenIds = new uint256[](n);
        if (_random() % 2 == 0) {
            uint256 balance = sam.samInfo(address(edition)).balance;
            if (balance != 0) {
                sam.directSetPoolBalance(address(edition), balance - 1);
                vm.expectRevert(bytes("WTF"));
                sam.sell(address(edition), tokenIds, 0, exploiter);
                sam.directSetPoolBalance(address(edition), balance);
            }
        }
        sam.sell(address(edition), tokenIds, 0, exploiter);

        assertEq(
            address(sam).balance,
            samBaseBalance +
                sam.affiliateFeesAccrued(affiliate) +
                sam.platformFeesAccrued() +
                sam.goldenEggFeesAccrued(address(edition))
        );

        sam.withdrawForAffiliate(affiliate);

        assertEq(
            address(sam).balance,
            samBaseBalance + sam.platformFeesAccrued() + sam.goldenEggFeesAccrued(address(edition))
        );

        sam.setPlatformFeeAddress(address(this));
        sam.withdrawForPlatform();

        assertEq(address(sam).balance, samBaseBalance + sam.goldenEggFeesAccrued(address(edition)));

        sam.withdrawForGoldenEgg(address(edition));

        assertEq(address(sam).balance, samBaseBalance);

        uint256 exploiterBalanceAfter = exploiter.balance;
        require(exploiterBalanceAfter <= exploiterBalanceBefore, "Something is wrong");
    }

    function test_samBeforeAndAfterPrimarySales(uint256) public {
        SoundEditionV1_2 edition = createGenericEdition();
        MockSAM sam = new MockSAM();

        edition.setSAM(address(sam));

        sam.create(
            address(edition),
            BASE_PRICE,
            LINEAR_PRICE_SLOPE,
            INFLECTION_PRICE,
            INFLECTION_POINT,
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            ARTIST_FEE_BPS,
            GOLDEN_EGG_FEE_BPS,
            AFFILIATE_FEE_BPS
        );

        uint256 editionMaxMintableLower = _random() % 32;
        uint256 editionMaxMintableUpper = editionMaxMintableLower + (_random() % 32);
        uint256 editionCutoffTime = block.timestamp + (_random() % 128);
        edition.setEditionMaxMintableRange(uint32(editionMaxMintableLower), uint32(editionMaxMintableUpper));
        if (editionMaxMintableUpper != 0) {
            edition.setEditionCutoffTime(uint32(editionCutoffTime));
        }

        while (true) {
            uint256 quantity = _bound(_random(), 1, 4);
            vm.warp(block.timestamp + (_random() % 16));
            uint256 editionMaxMintable = edition.editionMaxMintable();
            uint256 totalMinted = edition.totalMinted();
            if (totalMinted + quantity > editionMaxMintable) {
                vm.expectRevert();
                edition.mint(address(this), quantity);
                if (editionMaxMintable > totalMinted) {
                    edition.mint(address(this), editionMaxMintable - totalMinted);
                }
                break;
            } else {
                vm.expectRevert(ISoundEditionV1_2.MintNotConcluded.selector);
                sam.buy{ value: address(this).balance }(
                    address(edition),
                    address(this),
                    1,
                    address(0),
                    new bytes32[](0)
                );
                if (edition.totalMinted() != 0) {
                    vm.expectRevert(ISoundEditionV1_2.MintsAlreadyExist.selector);
                    edition.setSAM(address(sam));
                }
                edition.mint(address(this), quantity);
            }
        }
        assertTrue(edition.mintConcluded());

        vm.expectRevert(ISoundEditionV1_2.MintHasConcluded.selector);
        edition.setSAM(address(sam));

        if (block.timestamp >= editionCutoffTime) {
            assertTrue(edition.totalMinted() >= editionMaxMintableLower);
        } else {
            assertEq(edition.totalMinted(), editionMaxMintableUpper);
        }
        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, address(0), new bytes32[](0));
    }

    function test_samMint(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _maxMint(edition);
        t.fromTokenId = edition.nextTokenId();

        uint256 n = _bound(_random(), 0, 100);
        t.collectors = _randomCollectors();

        if (n == 0) {
            vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);
        }
        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        uint256[] memory expectedTokenIds = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            expectedTokenIds[i] = t.fromTokenId + i;
        }
        assertEq(expectedTokenIds, edition.tokensOfOwner(t.collectors[0]));
    }

    function test_samBurnCannotBurnTokenZero(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _maxMint(edition);

        uint256 n = _bound(_random(), 1, 5);
        t.collectors = _randomCollectors();

        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIdsToSell = edition.tokensOfOwner(t.collectors[0]);
        if (_random() % 2 == 0) {
            tokenIdsToSell[0] = 0;
            vm.expectRevert(IERC721AUpgradeable.OwnerQueryForNonexistentToken.selector);
        }
        vm.prank(t.collectors[0]);
        sam.sell(address(edition), tokenIdsToSell, 0, address(t.collectors[0]));
    }

    function test_samBurnUpdatesTokenExistences(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _maxMint(edition);

        uint256 n = _bound(_random(), 1, 5);
        t.collectors = _randomCollectors();

        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIdsToSell = edition.tokensOfOwner(t.collectors[0]);
        vm.prank(t.collectors[0]);
        sam.sell(address(edition), tokenIdsToSell, 0, address(t.collectors[0]));

        for (uint256 i; i != tokenIdsToSell.length; ++i) {
            vm.expectRevert(IERC721AUpgradeable.ApprovalQueryForNonexistentToken.selector);
            edition.getApproved(tokenIdsToSell[i]);
        }
    }

    function test_samBurnCannotBurnBurnedTokens(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _maxMint(edition);

        uint256 n = _bound(_random(), 1, 5);
        t.collectors = _randomCollectors();

        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        vm.prank(t.collectors[1]);
        sam.buy{ value: address(t.collectors[1]).balance }(
            address(edition),
            t.collectors[1],
            10,
            address(0),
            new bytes32[](0)
        );

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIdsToSell = edition.tokensOfOwner(t.collectors[0]);
        vm.prank(t.collectors[0]);
        sam.sell(address(edition), tokenIdsToSell, 0, address(t.collectors[0]));

        for (uint256 j; j < 5; ++j) {
            uint256[] memory partialTokenIdsToSell = new uint256[](tokenIdsToSell.length);
            for (uint256 i; i != tokenIdsToSell.length; ++i) {
                partialTokenIdsToSell[i] = tokenIdsToSell[_random() % tokenIdsToSell.length];
            }
            LibSort.insertionSort(partialTokenIdsToSell);
            LibSort.uniquifySorted(partialTokenIdsToSell);
            vm.expectRevert(IERC721AUpgradeable.OwnerQueryForNonexistentToken.selector);
            vm.prank(t.collectors[0]);
            sam.sell(address(edition), partialTokenIdsToSell, 0, address(t.collectors[0]));
        }
    }

    function test_samBurnUpdatesBalanceAndNumberBurned(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _maxMint(edition);

        uint256 n = _bound(_random(), 1, 5);
        t.collectors = _randomCollectors();

        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        uint256[] memory tokenIdsToSell = edition.tokensOfOwner(t.collectors[0]);

        // Mint more.
        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(_bound(_random(), 1, 5)),
            address(0),
            new bytes32[](0)
        );

        vm.warp(block.timestamp + 60);

        t.numBurnedBefore = edition.numberBurned(t.collectors[0]);
        t.numCollectedBefore = edition.balanceOf(t.collectors[0]);
        vm.prank(t.collectors[0]);
        sam.sell(address(edition), tokenIdsToSell, 0, address(t.collectors[0]));

        assertEq(edition.numberBurned(t.collectors[0]) - t.numBurnedBefore, tokenIdsToSell.length);
        assertEq(t.numCollectedBefore - edition.balanceOf(t.collectors[0]), tokenIdsToSell.length);
    }

    function test_samBurnMustBeStrictlyAscending(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _mintOut(edition);

        uint256 n = _bound(_random(), 1, 5);
        t.collectors = _randomCollectors();

        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIdsToSell = edition.tokensOfOwner(t.collectors[0]);
        if (_random() % 8 != 0) {
            bytes32 strictlyAscendingHash = keccak256(abi.encode(tokenIdsToSell));
            if (_random() % 8 != 0) {
                LibPRNG.PRNG memory prng = LibPRNG.PRNG(_random());
                prng.shuffle(tokenIdsToSell);
            } else {
                tokenIdsToSell[_random() % tokenIdsToSell.length] = tokenIdsToSell[_random() % tokenIdsToSell.length];
            }
            if (strictlyAscendingHash != keccak256(abi.encode(tokenIdsToSell))) {
                vm.expectRevert(ISoundEditionV1_2.TokenIdsNotStrictlyAscending.selector);
            }
        }
        vm.prank(t.collectors[0]);
        sam.sell(address(edition), tokenIdsToSell, 0, address(t.collectors[0]));
    }

    function test_samBurnMustBeApproved(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _mintOut(edition);

        uint256 n = _bound(_random(), 1, 5);
        t.collectors = _randomCollectors();
        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        uint256[] memory tokenIdsToSell = edition.tokensOfOwner(t.collectors[0]);

        if (_random() % 2 == 0) {
            uint256 tokenIdTransferred = tokenIdsToSell[_random() % tokenIdsToSell.length];
            vm.prank(t.collectors[0]);
            edition.transferFrom(t.collectors[0], t.collectors[1], tokenIdTransferred);
            if (_random() % 2 == 0) {
                vm.prank(t.collectors[1]);
                edition.approve(t.collectors[0], tokenIdTransferred);
            } else if (_random() % 2 == 0) {
                vm.prank(t.collectors[1]);
                edition.setApprovalForAll(t.collectors[0], true);
            } else {
                vm.expectRevert(IERC721AUpgradeable.TransferCallerNotOwnerNorApproved.selector);
            }
        }
        vm.warp(block.timestamp + 60);

        vm.prank(t.collectors[0]);
        sam.sell(address(edition), tokenIdsToSell, 0, address(t.collectors[0]));
    }

    function test_samBurnSuccessAfterSetApprovalForAll(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _mintOut(edition);

        t.collectors = _randomCollectors();

        for (uint256 i; i < 2; ++i) {
            vm.prank(t.collectors[i]);
            sam.buy{ value: address(t.collectors[i]).balance }(
                address(edition),
                t.collectors[i],
                uint32(_bound(_random(), 1, 5)),
                address(0),
                new bytes32[](0)
            );
            vm.prank(t.collectors[i]);
            edition.setApprovalForAll(address(this), true);

            t.tokenIds[i] = edition.tokensOfOwner(t.collectors[i]);
        }

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIdsToSell = new uint256[](sam.samInfo(address(edition)).supply);
        uint256 o;
        for (uint256 j; j < 2; ++j) {
            for (uint256 i; i < t.tokenIds[j].length; ++i) {
                tokenIdsToSell[o++] = t.tokenIds[j][i];
            }
        }

        sam.sell(address(edition), tokenIdsToSell, 0, address(this));

        for (uint256 i; i < 2; ++i) {
            assertEq(edition.numberBurned(t.collectors[i]), t.tokenIds[i].length);
            assertEq(edition.balanceOf(t.collectors[i]), 0);
        }
    }

    function test_samBurnSuccessForApproved(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _mintOut(edition);

        uint256 n = _bound(_random(), 1, 5);
        t.collectors = _randomCollectors();

        vm.prank(t.collectors[0]);
        sam.buy{ value: address(t.collectors[0]).balance }(
            address(edition),
            t.collectors[0],
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        uint256[] memory tokenIdsToSell = edition.tokensOfOwner(t.collectors[0]);

        if (_random() % 2 == 0) {
            uint256 tokenIdTransferred = tokenIdsToSell[_random() % tokenIdsToSell.length];
            vm.prank(t.collectors[0]);
            edition.transferFrom(t.collectors[0], t.collectors[1], tokenIdTransferred);
            if (_random() % 2 == 0) {
                vm.prank(t.collectors[1]);
                edition.approve(t.collectors[0], tokenIdTransferred);
            } else if (_random() % 2 == 0) {
                vm.prank(t.collectors[1]);
                edition.setApprovalForAll(t.collectors[0], true);
            } else {
                vm.expectRevert(IERC721AUpgradeable.TransferCallerNotOwnerNorApproved.selector);
            }
        }

        vm.warp(block.timestamp + 60);

        vm.prank(t.collectors[0]);
        sam.sell(address(edition), tokenIdsToSell, 0, address(t.collectors[0]));
    }

    function test_samBuyNonExistingEditionReverts() public {
        MockSAM sam = new MockSAM();

        address nonExistingEdition = address(0xa11ce);
        // This will be an EvmError revert because we
        // are using plain Solidity to call a non-existing edition.
        vm.expectRevert();

        sam.buy{ value: address(this).balance }(nonExistingEdition, address(1), 1, address(0), new bytes32[](0));

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        // This will be an EvmError revert because we
        // are using plain Solidity to call a non-existing edition
        vm.expectRevert();
        sam.sell(nonExistingEdition, tokenIds, 0, address(this));
    }

    function test_samBuyOnEditionWhenMintNotConcludedReverts() public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();

        vm.expectRevert(ISoundEditionV1_2.MintNotConcluded.selector);
        sam.buy{ value: address(this).balance }(address(edition), address(1), 1, address(0), new bytes32[](0));

        _maxMint(edition);

        sam.buy{ value: address(this).balance }(address(edition), address(1), 1, address(0), new bytes32[](0));
    }

    function test_samBuyOnEditionWithoutCreateReverts() public {
        MockSAM sam = new MockSAM();

        SoundEditionV1_2 edition = createGenericEdition();
        edition.setEditionMaxMintableRange(EDITION_MAX_MINTABLE_LOWER, EDITION_MAX_MINTABLE_LOWER);
        edition.setEditionCutoffTime(0);
        edition.setSAM(address(sam));

        _maxMint(edition);

        vm.expectRevert(ISAMV1_1.SAMDoesNotExist.selector);
        sam.buy{ value: address(this).balance }(address(edition), address(1), 1, address(0), new bytes32[](0));
    }

    function test_samSellOnEditionWithoutCreateReverts() public {
        MockSAM sam = new MockSAM();

        SoundEditionV1_2 edition = createGenericEdition();
        edition.setEditionMaxMintableRange(EDITION_MAX_MINTABLE_LOWER, EDITION_MAX_MINTABLE_LOWER);
        edition.setEditionCutoffTime(0);
        edition.setSAM(address(sam));

        _maxMint(edition);

        uint256[] memory tokenIdsToSell = new uint256[](1);
        tokenIdsToSell[0] = 1;
        vm.expectRevert(ISAMV1_1.SAMDoesNotExist.selector);
        sam.sell(address(edition), tokenIdsToSell, 0, address(this));
    }

    function test_samSellMoreThanSupplyReverts(uint256) public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _mintOut(edition);

        uint256 n = _bound(_random(), 1, 10);
        uint256 fromTokenId = edition.nextTokenId();
        sam.buy{ value: address(this).balance }(
            address(edition),
            address(this),
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        vm.warp(block.timestamp + 60);

        uint256 m = _bound(_random(), 1, 10);
        uint256[] memory tokenIdsToSell = new uint256[](m);
        for (uint256 i; i < m; ++i) {
            tokenIdsToSell[i] = i + fromTokenId;
        }
        if (m > n) {
            vm.expectRevert(abi.encodeWithSignature("InsufficientSupply(uint256,uint256)", n, m));
        }
        sam.sell(address(edition), tokenIdsToSell, 0, address(this));
    }

    function test_samBuySellLargeBatch() public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _maxMint(edition);

        uint256 n = 300;
        uint256 fromTokenId = edition.nextTokenId();
        sam.buy{ value: address(this).balance }(
            address(edition),
            address(this),
            uint32(n),
            address(0),
            new bytes32[](0)
        );

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIdsToSell = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            tokenIdsToSell[i] = i + fromTokenId;
        }

        sam.sell(address(edition), tokenIdsToSell, 0, address(this));
        for (uint256 i; i != tokenIdsToSell.length; ++i) {
            vm.expectRevert(IERC721AUpgradeable.ApprovalQueryForNonexistentToken.selector);
            edition.getApproved(tokenIdsToSell[i]);
        }
    }

    function test_samDoesNotChangeGoldenEggId(uint256) public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _mintOut(edition);
        bool hasGoldenEgg = edition.totalMinted() != 0;
        uint256 goldenEggIdBefore = hasGoldenEgg ? _getGoldenEggId(edition) : 0;

        uint256 n = _bound(_random(), 1, 10);
        sam.buy{ value: address(this).balance }(
            address(edition),
            address(this),
            uint32(n),
            address(0),
            new bytes32[](0)
        );
        uint256 goldenEggIdAfter = hasGoldenEgg ? _getGoldenEggId(edition) : 0;
        assertEq(goldenEggIdAfter, goldenEggIdBefore);
    }

    function test_samBuySellRepeatedly(uint256) public {
        /* ------------------------- SETUP -------------------------- */

        _testTempVariables memory t;

        SoundEditionV1_2[] memory editions = new SoundEditionV1_2[](2);
        t.goldenEggIds = new uint256[](editions.length);

        MockSAM sam = new MockSAM();

        sam.setPlatformFee(PLATFORM_FEE_BPS);

        for (uint256 i; i < editions.length; ++i) {
            SoundEditionV1_2 edition = createGenericEdition();
            edition.setEditionMaxMintableRange(EDITION_MAX_MINTABLE_LOWER, EDITION_MAX_MINTABLE_LOWER);
            edition.setEditionCutoffTime(0);
            edition.setSAM(address(sam));
            _setOpenGoldenEggMetadataModule(edition);

            if (_random() % 4 == 0) {
                t.basePrice = _bound(_random(), 0, type(uint96).max);
                t.linearPriceSlope = _bound(_random(), 1, type(uint96).max);
                t.inflectionPrice = _bound(_random(), 1, type(uint96).max);
                t.inflectionPoint = _bound(_random(), 1, type(uint32).max);
            } else {
                t.basePrice = BASE_PRICE;
                t.linearPriceSlope = LINEAR_PRICE_SLOPE;
                t.inflectionPrice = INFLECTION_PRICE;
                t.inflectionPoint = INFLECTION_POINT;
            }

            t.artistFeeBPS = _bound(_random(), 0, sam.MAX_ARTIST_FEE_BPS());
            t.goldenEggFeeBPS = _bound(_random(), 0, sam.MAX_GOLDEN_EGG_FEE_BPS());
            t.affiliateFeeBPS = _bound(_random(), 0, sam.MAX_AFFILIATE_FEE_BPS());

            sam.create(
                address(edition),
                uint96(t.basePrice),
                uint128(t.linearPriceSlope),
                uint128(t.inflectionPrice),
                uint32(t.inflectionPoint),
                MAX_SUPPLY,
                BUY_FREEZE_TIME,
                uint16(t.artistFeeBPS),
                uint16(t.goldenEggFeeBPS),
                uint16(t.affiliateFeeBPS)
            );

            _maxMint(edition);

            t.goldenEggIds[i] = _getGoldenEggId(edition);
            editions[i] = edition;
        }

        t.collectors = _randomCollectors();
        t.affiliates = _randomCollectors();

        /* ---------------------- TEST BUY SELL --------------------- */

        for (uint256 i = 2 + (_random() % 4); i != 0; --i) {
            address collector = t.collectors[_random() % t.collectors.length];
            address affiliate = t.affiliates[_random() % t.affiliates.length];
            SoundEditionV1_2 edition = editions[_random() % editions.length];
            (uint256 totalInflows, uint256 totalOutflows) = _testBuySell(edition, sam, collector, affiliate);
            t.totalInflows += totalInflows;
            t.totalInflows -= totalOutflows;
        }

        /* ---------- CHECK WITHDRAWING FEES AND BALANCES ----------- */

        for (uint256 i; i < editions.length; ++i) {
            SoundEditionV1_2 edition = editions[i];
            SAMInfo memory samInfo = sam.samInfo(address(edition));
            uint256 balance = sam.totalSellPrice(address(edition), 0, samInfo.supply);
            assertEq(samInfo.balance, balance);
            t.totalPoolValue += balance;
            t.totalGoldenEggFeesAccrued += sam.goldenEggFeesAccrued(address(edition));
            t.totalArtistFeesAccrued += address(edition).balance;
        }

        for (uint256 i; i < t.affiliates.length; ++i) {
            t.totalAffiliateFeesAccrued += sam.affiliateFeesAccrued(t.affiliates[i]);
        }

        t.platformFeesAccrued = sam.platformFeesAccrued();

        assertEq(
            t.totalPoolValue + t.totalGoldenEggFeesAccrued + t.totalAffiliateFeesAccrued + t.platformFeesAccrued,
            address(sam).balance
        );
        assertEq(address(sam).balance + t.totalArtistFeesAccrued, t.totalInflows);

        _testWithdrawForPlatform(sam);
        assertEq(t.totalPoolValue + t.totalGoldenEggFeesAccrued + t.totalAffiliateFeesAccrued, address(sam).balance);

        for (uint256 i; i < t.affiliates.length; ++i) {
            _testWithdrawForAffiliate(sam, t.affiliates[i]);
        }
        assertEq(t.totalPoolValue + t.totalGoldenEggFeesAccrued, address(sam).balance);
        for (uint256 i; i < editions.length; ++i) {
            _testWithdrawForGoldenEgg(sam, editions[i]);
            assertEq(_getGoldenEggId(editions[i]), t.goldenEggIds[i]);
        }
        assertEq(t.totalPoolValue, address(sam).balance);

        if (t.totalGoldenEggFeesAccrued != 0) {
            t.totalGoldenEggFeesAccrued = 0;
            vm.deal(address(this), type(uint192).max);
            for (uint256 i; i < editions.length; ++i) {
                sam.buy{ value: address(this).balance }(
                    address(editions[i]),
                    address(this),
                    1,
                    address(1),
                    new bytes32[](0)
                );
                t.totalGoldenEggFeesAccrued += sam.goldenEggFeesAccrued(address(editions[i]));
                _testWithdrawForGoldenEgg(sam, editions[i]);
            }
            assertTrue(t.totalGoldenEggFeesAccrued > 0);
        }

        /* -------- TEST SELLING BELOW MINIMUM SUPPLY REVERTS ------- */

        vm.warp(block.timestamp + 60);

        for (uint256 i; i < editions.length; ++i) {
            SoundEditionV1_2 edition = editions[i];
            _testSellRemainingTokens(edition, sam);
        }

        /* --------------------- TEST FREEZE BUY -------------------- */

        vm.warp(block.timestamp + 60);

        if (_random() % 8 == 0) {
            for (uint256 i; i < editions.length; ++i) {
                SoundEditionV1_2 edition = editions[i];
                _testFreezeBuy(edition, sam);
            }
        }
    }

    function _testSellRemainingTokens(SoundEditionV1_2 edition, MockSAM sam) internal {
        vm.warp(block.timestamp + 60);

        _testTempVariables memory t;
        uint256[] memory tokenIds = edition.tokensOfOwner(address(this));

        uint256 remainingSupply = sam.samInfo(address(edition)).supply;

        if (tokenIds.length != 0) {
            t.tokenIds[0] = new uint256[](_bound(_random(), 1, tokenIds.length));
            for (uint256 i; i < t.tokenIds[0].length; ++i) {
                t.tokenIds[0][i] = tokenIds[i];
                assertEq(edition.ownerOf(tokenIds[i]), address(this));
            }
            bool hasRevert;
            if (remainingSupply < t.tokenIds[0].length) {
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "InsufficientSupply(uint256,uint256)",
                        remainingSupply,
                        t.tokenIds[0].length
                    )
                );
                hasRevert = true;
            }
            sam.sell(address(edition), t.tokenIds[0], 0, address(this));

            if (_random() % 2 == 0) {
                remainingSupply = sam.samInfo(address(edition)).supply;
                tokenIds = edition.tokensOfOwner(address(this));

                if (tokenIds.length >= remainingSupply) {
                    t.tokenIds[0] = new uint256[](remainingSupply);
                    for (uint256 i; i < remainingSupply; ++i) {
                        t.tokenIds[0][i] = tokenIds[i];
                    }
                    if (t.tokenIds[0].length != 0) {
                        sam.sell(address(edition), t.tokenIds[0], 0, address(this));
                    }
                    SAMInfo memory samInfo = sam.samInfo(address(edition));
                    assertEq(samInfo.supply, 0);
                    assertEq(samInfo.balance, 0);
                }
            }
        }
    }

    function _testWithdrawForPlatform(MockSAM sam) internal {
        (address feeAddr, ) = _randomSigner();

        vm.expectRevert(ISAMV1_1.PlatformFeeAddressIsZero.selector);
        sam.setPlatformFeeAddress(address(0));

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(address(1));
        sam.setPlatformFeeAddress(feeAddr);

        vm.expectEmit(true, true, true, true);
        emit PlatformFeeAddressSet(feeAddr);
        sam.setPlatformFeeAddress(feeAddr);

        uint256 accrued = sam.platformFeesAccrued();
        uint256 balanceBefore = address(feeAddr).balance;
        if (accrued != 0) {
            vm.expectEmit(true, true, true, true);
            emit PlatformFeesWithdrawn(SafeCastLib.toUint128(accrued));
        }
        sam.withdrawForPlatform();
        assertEq(address(feeAddr).balance - balanceBefore, accrued);
        assertEq(sam.platformFeesAccrued(), 0);
    }

    function _testWithdrawForAffiliate(MockSAM sam, address affiliate) internal {
        uint256 accrued = sam.affiliateFeesAccrued(affiliate);
        uint256 balanceBefore = address(affiliate).balance;
        if (accrued != 0) {
            vm.expectEmit(true, true, true, true);
            emit AffiliateFeesWithdrawn(affiliate, SafeCastLib.toUint128(accrued));
        }
        sam.withdrawForAffiliate(affiliate);
        assertEq(address(affiliate).balance - balanceBefore, accrued);
        assertEq(sam.affiliateFeesAccrued(affiliate), 0);
    }

    function _testWithdrawForGoldenEgg(MockSAM sam, SoundEditionV1_2 edition) internal {
        uint256 accrued = sam.goldenEggFeesAccrued(address(edition));
        uint256 goldenEggId = IOpenGoldenEggMetadata(edition.metadataModule()).getGoldenEggTokenId(address(edition));
        address goldenEggOwner = edition.ownerOf(goldenEggId);
        uint256 balanceBefore = address(goldenEggOwner).balance;
        if (accrued != 0) {
            vm.expectEmit(true, true, true, true);
            emit GoldenEggFeesWithdrawn(address(edition), goldenEggOwner, SafeCastLib.toUint128(accrued));
        }
        sam.withdrawForGoldenEgg(address(edition));
        assertEq(address(goldenEggOwner).balance - balanceBefore, accrued);
        assertEq(sam.goldenEggFeesAccrued(address(edition)), 0);
    }

    function _totalBuyPrice(
        SoundEditionV1_2 edition,
        MockSAM sam,
        uint256 fromSupply,
        uint256 quantity
    ) internal view returns (uint256 result) {
        (result, , , , ) = sam.totalBuyPriceAndFees(address(edition), uint32(fromSupply), uint32(quantity));
    }

    function _testBuySell(
        SoundEditionV1_2 edition,
        MockSAM sam,
        address collector,
        address affiliate
    ) internal returns (uint256 totalInflows, uint256 totalOutflows) {
        /* ------------------------- SETUP -------------------------- */

        _testTempVariables memory t;

        t.quantities[0] = _bound(_random(), 1, 3);
        t.quantities[1] = _bound(_random(), 1, 3);

        t.totalBuyPrices[0] = _totalBuyPrice(edition, sam, 0, t.quantities[0]);
        t.totalBuyPrices[1] = _totalBuyPrice(edition, sam, t.quantities[0], t.quantities[1]);

        totalInflows += t.totalBuyPrices[0] + t.totalBuyPrices[1];

        /* ------------------------ TEST BUY ------------------------ */

        vm.startPrank(collector);
        t.numCollectedBefore = edition.balanceOf(collector);
        t.numMintedBefore = edition.numberMinted(collector);
        t.totalSupplyBefore = edition.totalSupply();

        // Check events.
        {
            SAMInfo memory samInfo = sam.samInfo(address(edition));
            t.totalFees =
                t.totalBuyPrices[0] -
                sam.totalValue(address(edition), samInfo.supply, uint32(t.quantities[0]));
            t.platformFeeBPS = sam.platformFeeBPS();
            t.fromTokenId = edition.nextTokenId();
            t.totalFeeBPS = t.platformFeeBPS + samInfo.artistFeeBPS + samInfo.affiliateFeeBPS + samInfo.goldenEggFeeBPS;
            t.feePerBPS = t.totalFees / t.totalFeeBPS;
            t.platformFee = t.feePerBPS * uint256(t.platformFeeBPS);
            t.artistFee = t.feePerBPS * uint256(samInfo.artistFeeBPS);
            t.goldenEggFee = t.feePerBPS * uint256(samInfo.goldenEggFeeBPS);
            t.affiliateFee = t.feePerBPS * uint256(samInfo.affiliateFeeBPS);
            t.attributionId = _random();
            t.affiliate = affiliate;

            vm.expectEmit(true, true, true, true);
            emit Bought(
                address(edition),
                collector,
                t.fromTokenId,
                samInfo.supply,
                uint32(t.quantities[0]),
                uint128(t.totalBuyPrices[0]),
                uint128(t.platformFee),
                uint128(t.artistFee),
                uint128(t.goldenEggFee),
                uint128(t.affiliateFee),
                t.affiliate,
                true,
                t.attributionId
            );
        }

        sam.buy{ value: t.totalBuyPrices[0] }(
            address(edition),
            collector,
            uint32(t.quantities[0]),
            affiliate,
            new bytes32[](0),
            t.attributionId
        );

        // Check underpaying reverts.
        if (_random() % 2 == 0 && t.totalBuyPrices[1] != 0) {
            vm.expectRevert(
                abi.encodeWithSignature("Underpaid(uint256,uint256)", t.totalBuyPrices[1] - 1, t.totalBuyPrices[1])
            );
            sam.buy{ value: t.totalBuyPrices[1] - 1 }(
                address(edition),
                collector,
                uint32(t.quantities[1]),
                affiliate,
                new bytes32[](0)
            );
        }
        t.balancesBefore[0] = address(collector).balance;
        sam.buy{ value: t.totalBuyPrices[1] + _bound(_random(), 0, 1 ether) }(
            address(edition),
            collector,
            uint32(t.quantities[1]),
            affiliate,
            new bytes32[](0)
        );

        {
            uint256 numBought = t.quantities[0] + t.quantities[1];
            assertEq(edition.balanceOf(collector) - t.numCollectedBefore, numBought);
            assertEq(edition.totalSupply() - t.totalSupplyBefore, numBought);
            assertEq(edition.numberMinted(collector) - t.numMintedBefore, numBought);
            assertEq(t.balancesBefore[0] - address(collector).balance, t.totalBuyPrices[1]);
        }

        /* ------------------------ TEST SELL ----------------------- */

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIds = edition.tokensOfOwner(collector);

        t.tokenIds[0] = new uint256[](_bound(_random(), 1, tokenIds.length));
        for (uint256 i; i < t.tokenIds[0].length; ++i) {
            t.tokenIds[0][i] = tokenIds[i];
        }

        t.tokenIds[1] = new uint256[](0);
        if (tokenIds.length > t.tokenIds[0].length) {
            t.tokenIds[1] = new uint256[](_bound(_random(), 1, tokenIds.length - t.tokenIds[0].length));
        }
        for (uint256 i; i < t.tokenIds[1].length; ++i) {
            t.tokenIds[1][i] = tokenIds[t.tokenIds[0].length + i];
        }

        t.numCollectedBefore = edition.balanceOf(collector);
        t.numBurnedBefore = edition.numberBurned(collector);
        t.numMintedBefore = edition.numberMinted(collector);
        t.totalSupplyBefore = edition.totalSupply();

        t.totalSellPrices[0] = sam.totalSellPrice(address(edition), 0, uint32(t.tokenIds[0].length));
        t.totalSellPrices[1] = sam.totalSellPrice(
            address(edition),
            uint32(t.tokenIds[0].length),
            uint32(t.tokenIds[1].length)
        );

        totalOutflows += t.totalSellPrices[0] + t.totalSellPrices[1];
        t.attributionId = _random();
        {
            SAMInfo memory samInfo = sam.samInfo(address(edition));
            for (uint256 i; i < t.tokenIds[0].length; ++i) {
                vm.expectEmit(true, true, true, true);
                emit Transfer(collector, address(0), t.tokenIds[0][i]);
            }
            if (t.tokenIds[0].length != 0) {
                vm.expectEmit(true, true, true, true);
                emit Sold(
                    address(edition),
                    collector,
                    samInfo.supply,
                    t.tokenIds[0],
                    uint128(t.totalSellPrices[0]),
                    t.attributionId
                );
            }
        }
        if (_random() % 8 == 0) _checkAllExists(edition, collector, t.tokenIds[0]);
        if (t.tokenIds[0].length == 0) {
            vm.expectRevert(ISAMV1_1.BurnZeroQuantity.selector);
        }
        sam.sell(address(edition), t.tokenIds[0], t.totalSellPrices[0], collector, t.attributionId);
        if (_random() % 8 == 0) _checkAllBurned(edition, collector, t.tokenIds[0]);

        if (_random() % 2 == 0) {
            if (t.tokenIds[1].length == 0) {
                vm.expectRevert(ISAMV1_1.BurnZeroQuantity.selector);
            } else {
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "InsufficientPayout(uint256,uint256)",
                        t.totalSellPrices[1],
                        t.totalSellPrices[1] + 1
                    )
                );
            }
            sam.sell(address(edition), t.tokenIds[1], t.totalSellPrices[1] + 1, collector);
        }

        // Check events.
        {
            SAMInfo memory samInfo = sam.samInfo(address(edition));
            for (uint256 i; i < t.tokenIds[1].length; ++i) {
                vm.expectEmit(true, true, true, true);
                emit Transfer(collector, address(0), t.tokenIds[1][i]);
            }
            if (t.tokenIds[1].length != 0) {
                vm.expectEmit(true, true, true, true);
                emit Sold(address(edition), collector, samInfo.supply, t.tokenIds[1], uint128(t.totalSellPrices[1]), 0);
            }
        }
        vm.warp(block.timestamp + 60);
        if (_random() % 8 == 0) _checkAllExists(edition, collector, t.tokenIds[1]);
        if (t.tokenIds[1].length == 0) {
            vm.expectRevert(ISAMV1_1.BurnZeroQuantity.selector);
        }
        sam.sell(address(edition), t.tokenIds[1], t.totalSellPrices[1], collector);
        if (_random() % 8 == 0) _checkAllBurned(edition, collector, t.tokenIds[1]);

        {
            uint256 numSold = t.tokenIds[0].length + t.tokenIds[1].length;
            assertEq(t.numCollectedBefore - edition.balanceOf(collector), numSold);
            assertEq(t.totalSupplyBefore - edition.totalSupply(), numSold);
            assertEq(edition.numberBurned(collector) - t.numBurnedBefore, numSold);
            assertEq(edition.numberMinted(collector), t.numMintedBefore);
        }

        vm.stopPrank();
    }

    function _checkAllExists(
        SoundEditionV1_2 edition,
        address collector,
        uint256[] memory tokenIds
    ) internal {
        unchecked {
            for (uint256 i; i < tokenIds.length; ++i) {
                IERC721AUpgradeable.TokenOwnership memory ownership = edition.explicitOwnershipOf(tokenIds[i]);
                assertEq(ownership.burned, false);
                assertEq(ownership.addr, collector);
            }
        }
    }

    function _checkAllBurned(
        SoundEditionV1_2 edition,
        address collector,
        uint256[] memory tokenIds
    ) internal {
        unchecked {
            for (uint256 i; i < tokenIds.length; ++i) {
                IERC721AUpgradeable.TokenOwnership memory ownership = edition.explicitOwnershipOf(tokenIds[i]);
                assertEq(ownership.burned, true);
                assertEq(ownership.startTimestamp, block.timestamp);
                assertEq(ownership.addr, collector);
            }
        }
    }

    function _testFreezeBuy(SoundEditionV1_2 edition, MockSAM sam) internal {
        vm.deal(address(this), type(uint192).max);
        uint256 startTokenId = edition.nextTokenId();
        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, address(0), new bytes32[](0));
        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, address(0), new bytes32[](0));

        vm.expectEmit(true, true, true, true);
        emit BuyFreezeTimeSet(address(edition), uint32(block.timestamp));
        sam.setBuyFreezeTime(address(edition), uint32(block.timestamp));

        vm.expectRevert(ISAMV1_1.BuyIsFrozen.selector);
        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, address(0), new bytes32[](0));

        vm.warp(block.timestamp + 60);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = startTokenId;
        sam.sell(address(edition), tokenIds, 0, address(this));
    }

    function test_samSetBuyFreezeTime() public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        uint256 buyFreezeTime = block.timestamp + 10;

        sam.setBuyFreezeTime(address(edition), uint32(0));
        sam.setBuyFreezeTime(address(edition), uint32(1));
        sam.setBuyFreezeTime(address(edition), uint32(2));

        vm.expectEmit(true, true, true, true);
        emit BuyFreezeTimeSet(address(edition), uint32(buyFreezeTime + 10));
        sam.setBuyFreezeTime(address(edition), uint32(buyFreezeTime + 10));

        _mintOut(edition);

        vm.expectRevert(ISAMV1_1.InvalidBuyFreezeTime.selector);
        sam.setBuyFreezeTime(address(edition), uint32(buyFreezeTime + 11));

        sam.setBuyFreezeTime(address(edition), uint32(buyFreezeTime + 10));
        sam.setBuyFreezeTime(address(edition), uint32(buyFreezeTime + 9));

        sam.setBuyFreezeTime(address(edition), uint32(buyFreezeTime));

        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, address(0), new bytes32[](0));

        vm.warp(buyFreezeTime - 1);

        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, address(0), new bytes32[](0));

        vm.warp(buyFreezeTime);

        vm.expectRevert(ISAMV1_1.BuyIsFrozen.selector);
        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, address(0), new bytes32[](0));
    }

    function test_samSetMaxSupply() public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();

        uint32 maxSupply = 100;
        sam.setMaxSupply(address(edition), uint32(0));
        sam.setMaxSupply(address(edition), uint32(1));
        sam.setMaxSupply(address(edition), uint32(2));

        vm.expectEmit(true, true, true, true);
        emit MaxSupplySet(address(edition), uint32(maxSupply + 10));
        sam.setMaxSupply(address(edition), uint32(maxSupply + 10));

        _mintOut(edition);

        vm.expectRevert(ISAMV1_1.InvalidMaxSupply.selector);
        sam.setMaxSupply(address(edition), uint32(maxSupply + 11));

        sam.setMaxSupply(address(edition), uint32(maxSupply));

        sam.buy{ value: address(this).balance }(address(edition), address(this), 3, address(0), new bytes32[](0));

        vm.expectRevert(abi.encodeWithSignature("ExceedsMaxSupply(uint32)", uint32(maxSupply - 3)));
        sam.buy{ value: address(this).balance }(
            address(edition),
            address(this),
            maxSupply,
            address(0),
            new bytes32[](0)
        );
    }

    function test_samCreate(uint256) public {
        _testTempVariables memory t;

        SoundEditionV1_2 edition = createGenericEdition();

        MockSAM sam = new MockSAM();

        edition.setEditionMaxMintableRange(EDITION_MAX_MINTABLE_LOWER, EDITION_MAX_MINTABLE_LOWER);
        edition.setSAM(address(sam));

        t.maxArtistFeeBPS = sam.MAX_ARTIST_FEE_BPS();
        t.maxAffiliateFeeBPS = sam.MAX_AFFILIATE_FEE_BPS();
        t.maxGoldenEggFeeBPS = sam.MAX_GOLDEN_EGG_FEE_BPS();
        t.maxPlatformFeeBPS = sam.MAX_PLATFORM_FEE_BPS();

        t.basePrice = _bound(_random(), 0, type(uint96).max);
        t.inflectionPrice = _bound(_random(), 0, type(uint128).max);
        t.inflectionPoint = _bound(_random(), 0, type(uint32).max);
        t.maxSupply = _bound(_random(), 0, type(uint32).max);
        t.buyFreezeTime = _bound(_random(), 0, type(uint32).max);
        t.artistFeeBPS = _bound(_random(), 0, t.maxArtistFeeBPS + 1000);
        t.affiliateFeeBPS = _bound(_random(), 0, t.maxAffiliateFeeBPS + 1000);
        t.goldenEggFeeBPS = _bound(_random(), 0, t.maxGoldenEggFeeBPS + 1000);

        bool hasRevert;

        if (_random() % 64 == 0) {
            edition.transferOwnership(address(1));
            vm.expectRevert(Ownable.Unauthorized.selector);
            hasRevert = true;
        } else if (t.maxSupply == 0) {
            vm.expectRevert(ISAMV1_1.InvalidMaxSupply.selector);
            hasRevert = true;
        } else if (t.buyFreezeTime == 0) {
            vm.expectRevert(ISAMV1_1.InvalidBuyFreezeTime.selector);
            hasRevert = true;
        } else if (t.artistFeeBPS > t.maxArtistFeeBPS) {
            vm.expectRevert(ISAMV1_1.InvalidArtistFeeBPS.selector);
            hasRevert = true;
        } else if (t.goldenEggFeeBPS > t.maxGoldenEggFeeBPS) {
            vm.expectRevert(ISAMV1_1.InvalidGoldenEggFeeBPS.selector);
            hasRevert = true;
        } else if (t.affiliateFeeBPS > t.maxAffiliateFeeBPS) {
            vm.expectRevert(ISAMV1_1.InvalidAffiliateFeeBPS.selector);
            hasRevert = true;
        } else if (_random() % 2 == 0) {
            _maxMint(edition);
            vm.expectRevert(ISAMV1_1.InSAMPhase.selector);
            hasRevert = true;
        }

        if (!hasRevert) {
            // Test if an admin of the edition is authorized to create.
            if (_random() % 2 == 0) {
                edition.grantRoles(address(this), edition.ADMIN_ROLE());
                edition.transferOwnership(address(1));
            }
            vm.expectEmit(true, true, true, true);
            emit Created(
                address(edition),
                uint96(t.basePrice),
                uint128(t.linearPriceSlope),
                uint128(t.inflectionPrice),
                uint32(t.inflectionPoint),
                uint32(t.maxSupply),
                uint32(t.buyFreezeTime),
                uint16(t.artistFeeBPS),
                uint16(t.goldenEggFeeBPS),
                uint16(t.affiliateFeeBPS)
            );
        }

        sam.create(
            address(edition),
            uint96(t.basePrice),
            uint128(t.linearPriceSlope),
            uint128(t.inflectionPrice),
            uint32(t.inflectionPoint),
            uint32(t.maxSupply),
            uint32(t.buyFreezeTime),
            uint16(t.artistFeeBPS),
            uint16(t.goldenEggFeeBPS),
            uint16(t.affiliateFeeBPS)
        );

        if (hasRevert) return;

        // Test if repeated creation for the same edition is not allowed.
        if (_random() % 2 == 0) {
            vm.expectRevert(ISAMV1_1.SAMAlreadyExists.selector);
            sam.create(
                address(edition),
                uint96(t.basePrice),
                uint128(t.linearPriceSlope),
                uint128(t.inflectionPrice),
                uint32(t.inflectionPoint),
                uint32(t.maxSupply),
                uint32(t.buyFreezeTime),
                uint16(t.artistFeeBPS),
                uint16(t.goldenEggFeeBPS),
                uint16(t.affiliateFeeBPS)
            );
        }

        // Check if `create` properly initializes the variables.
        SAMInfo memory info = sam.samInfo(address(edition));
        assertEq(info.basePrice, t.basePrice);
        assertEq(info.linearPriceSlope, t.linearPriceSlope);
        assertEq(info.inflectionPrice, t.inflectionPrice);
        assertEq(info.inflectionPoint, t.inflectionPoint);
        assertEq(info.maxSupply, t.maxSupply);
        assertEq(info.buyFreezeTime, t.buyFreezeTime);
        assertEq(info.artistFeeBPS, t.artistFeeBPS);
        assertEq(info.goldenEggFeeBPS, t.goldenEggFeeBPS);
        assertEq(info.affiliateFeeBPS, t.affiliateFeeBPS);
    }

    function test_goldenEggFeeRecipient() public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        // If the golden egg has not been revealed, the recipient is the `edition`.
        assertEq(sam.goldenEggFeeRecipient(address(edition)), address(edition));

        // Check if the function reverts if the edition is not a valid contract.
        vm.expectRevert(); // Reverts with EvmError.
        sam.goldenEggFeeRecipient(address(0xa11ce));

        _maxMint(edition);
        // If there is an golden egg, the recipient is the golden egg owner.
        assertEq(sam.goldenEggFeeRecipient(address(edition)), edition.ownerOf(_getGoldenEggId(edition)));
        // Burn the golden egg and check that the recipient is the edition.
        edition.burn(_getGoldenEggId(edition));
        assertEq(sam.goldenEggFeeRecipient(address(edition)), address(edition));

        // Recreate `edition` and `sam`.
        (edition, sam) = _createEditionAndSAM();

        edition.setMetadataModule(address(0));
        _maxMint(edition);
        // If there is no golden egg metadata module, the recipient is the edition itself.
        assertEq(sam.goldenEggFeeRecipient(address(edition)), address(edition));

        // Recreate `edition` and `sam`.
        (edition, sam) = _createEditionAndSAM();

        edition.setMetadataModule(address(0));
        edition.setEditionMaxMintableRange(0, 0);
        // If there is no golden egg, the recipient is the edition itself.
        assertEq(sam.goldenEggFeeRecipient(address(edition)), address(edition));
    }

    function test_withdrawGoldenEggFees() public {
        vm.deal(address(this), type(uint192).max);

        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();
        _maxMint(edition);

        assertEq(sam.goldenEggFeesAccrued(address(edition)), 0);
        sam.buy{ value: address(this).balance }(
            address(edition),
            address(this),
            uint32(_bound(_random(), 1, 10)),
            address(0),
            new bytes32[](0)
        );
        uint256 accrued = sam.goldenEggFeesAccrued(address(edition));
        assertTrue(accrued != 0);

        uint256 balanceBefore = address(this).balance;
        sam.withdrawForGoldenEgg(address(edition));
        assertEq(address(this).balance - balanceBefore, accrued);

        // Try again, but without a golden egg winner due to zero `editionMaxMintable`.

        (edition, sam) = _createEditionAndSAM();
        edition.setEditionMaxMintableRange(0, 0);

        assertEq(sam.goldenEggFeesAccrued(address(edition)), 0);
        sam.buy{ value: address(this).balance }(
            address(edition),
            address(this),
            uint32(_bound(_random(), 1, 10)),
            address(0),
            new bytes32[](0)
        );
        accrued = sam.goldenEggFeesAccrued(address(edition));
        assertTrue(accrued != 0);
        balanceBefore = address(edition).balance;
        sam.withdrawForGoldenEgg(address(edition));
        assertEq(address(edition).balance - balanceBefore, accrued);

        // Try again, but without a golden egg winner due to no `metadataModule`.

        (edition, sam) = _createEditionAndSAM();
        edition.setMetadataModule(address(0));
        _maxMint(edition);

        assertEq(sam.goldenEggFeesAccrued(address(edition)), 0);
        sam.buy{ value: address(this).balance }(
            address(edition),
            address(this),
            uint32(_bound(_random(), 1, 10)),
            address(0),
            new bytes32[](0)
        );
        accrued = sam.goldenEggFeesAccrued(address(edition));
        assertTrue(accrued != 0);
        balanceBefore = address(edition).balance;
        sam.withdrawForGoldenEgg(address(edition));
        assertEq(address(edition).balance - balanceBefore, accrued);
    }

    function test_generalSettersAndGetters(uint256) public {
        _testTempVariables memory t;
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();

        t.maxArtistFeeBPS = sam.MAX_ARTIST_FEE_BPS();
        t.maxAffiliateFeeBPS = sam.MAX_AFFILIATE_FEE_BPS();
        t.maxGoldenEggFeeBPS = sam.MAX_GOLDEN_EGG_FEE_BPS();
        t.maxPlatformFeeBPS = sam.MAX_PLATFORM_FEE_BPS();

        // Fuzz test for all the functions guarded by the
        // `onlyEditionOwnerOrAdmin` and `onlyBeforeSAMPhase` modifiers.
        for (uint256 i; i < 32; ++i) {
            bool hasRevert;
            bool prankUnauthorized;
            bool mintHasConcluded;

            uint256 r = _random() % 7;

            // Test whether an unauthorized address will be reverted
            // if the function is guarded by the `onlyEditionOwnerOrAdmin` modifier.
            if (_random() % 16 == 0) {
                vm.startPrank(address(1));
                vm.expectRevert(Ownable.Unauthorized.selector);
                prankUnauthorized = true;
                hasRevert = true;
            }

            // Test whether setting a parameter that is guarded by
            // the `onlyBeforeSAMPhase` modifier reverts.
            if (_random() % 16 == 0 && !hasRevert && !(r == 4 || r == 6)) {
                _mintOut(edition);
                vm.expectRevert(ISAMV1_1.InSAMPhase.selector);
                mintHasConcluded = true;
                hasRevert = true;
            }

            // Test set and get the `basePrice`.
            if (r == 0) {
                t.basePrice = _bound(_random(), 0, type(uint96).max);
                if (!hasRevert) {
                    vm.expectEmit(true, true, true, true);
                    emit BasePriceSet(address(edition), uint96(t.basePrice));
                }
                sam.setBasePrice(address(edition), uint96(t.basePrice));
                if (!hasRevert) {
                    assertEq(sam.samInfo(address(edition)).basePrice, t.basePrice);
                    continue;
                }
            }
            // Test set and get the `linearPriceSlope`.
            if (r == 1) {
                t.linearPriceSlope = _bound(_random(), 0, type(uint128).max);
                if (!hasRevert) {
                    vm.expectEmit(true, true, true, true);
                    emit LinearPriceSlopeSet(address(edition), uint128(t.linearPriceSlope));
                }
                sam.setLinearPriceSlope(address(edition), uint128(t.linearPriceSlope));
                if (!hasRevert) {
                    assertEq(sam.samInfo(address(edition)).linearPriceSlope, t.linearPriceSlope);
                    continue;
                }
            }
            // Test set and get the `inflectionPrice`.
            if (r == 2) {
                t.inflectionPrice = _bound(_random(), 0, type(uint128).max);
                if (!hasRevert) {
                    vm.expectEmit(true, true, true, true);
                    emit InflectionPriceSet(address(edition), uint128(t.inflectionPrice));
                }
                sam.setInflectionPrice(address(edition), uint128(t.inflectionPrice));
                if (!hasRevert) {
                    assertEq(sam.samInfo(address(edition)).inflectionPrice, t.inflectionPrice);
                    continue;
                }
            }
            // Test set and get the `inflectionPoint`.
            if (r == 3) {
                t.inflectionPoint = _bound(_random(), 0, type(uint32).max);
                if (!hasRevert) {
                    vm.expectEmit(true, true, true, true);
                    emit InflectionPointSet(address(edition), uint32(t.inflectionPoint));
                }
                sam.setInflectionPoint(address(edition), uint32(t.inflectionPoint));
                if (!hasRevert) {
                    assertEq(sam.samInfo(address(edition)).inflectionPoint, t.inflectionPoint);
                    continue;
                }
            }
            // Test set and get the `inflectionPoint`.
            if (r == 4) {
                t.artistFeeBPS = _bound(_random(), 0, t.maxArtistFeeBPS * 2);
                if (t.artistFeeBPS > t.maxArtistFeeBPS && !hasRevert) {
                    vm.expectRevert(ISAMV1_1.InvalidArtistFeeBPS.selector);
                    hasRevert = true;
                }
                if (!hasRevert) {
                    vm.expectEmit(true, true, true, true);
                    emit ArtistFeeSet(address(edition), uint16(t.artistFeeBPS));
                }
                sam.setArtistFee(address(edition), uint16(t.artistFeeBPS));
                if (!hasRevert) {
                    assertEq(sam.samInfo(address(edition)).artistFeeBPS, t.artistFeeBPS);
                    continue;
                }
            }
            // Test set and get the `goldenEggFeeBPS`.
            if (r == 5) {
                t.goldenEggFeeBPS = _bound(_random(), 0, t.maxGoldenEggFeeBPS * 2);
                if (t.goldenEggFeeBPS > t.maxGoldenEggFeeBPS && !hasRevert) {
                    vm.expectRevert(ISAMV1_1.InvalidGoldenEggFeeBPS.selector);
                    hasRevert = true;
                }
                if (!hasRevert) {
                    vm.expectEmit(true, true, true, true);
                    emit GoldenEggFeeSet(address(edition), uint16(t.goldenEggFeeBPS));
                }
                sam.setGoldenEggFee(address(edition), uint16(t.goldenEggFeeBPS));
                if (!hasRevert) {
                    assertEq(sam.samInfo(address(edition)).goldenEggFeeBPS, t.goldenEggFeeBPS);
                    continue;
                }
            }
            // Test set and get the `affiliateFeeBPS`.
            if (r == 6) {
                t.affiliateFeeBPS = _bound(_random(), 0, t.maxAffiliateFeeBPS * 2);
                if (t.affiliateFeeBPS > t.maxAffiliateFeeBPS && !hasRevert) {
                    vm.expectRevert(ISAMV1_1.InvalidAffiliateFeeBPS.selector);
                    hasRevert = true;
                }
                if (!hasRevert) {
                    vm.expectEmit(true, true, true, true);
                    emit AffiliateFeeSet(address(edition), uint16(t.affiliateFeeBPS));
                }
                sam.setAffiliateFee(address(edition), uint16(t.affiliateFeeBPS));
                if (!hasRevert) {
                    assertEq(sam.samInfo(address(edition)).affiliateFeeBPS, t.affiliateFeeBPS);
                    continue;
                }
            }

            if (prankUnauthorized) {
                vm.stopPrank();
            }

            if (mintHasConcluded) {
                (edition, sam) = _createEditionAndSAM();
            }
        }
    }

    function test_setAffiliateMerkleRoot() public {
        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();

        address[] memory accounts = new address[](2);
        accounts[0] = address(0xa11ce);
        accounts[1] = address(0xb0b);

        bytes32[] memory leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            leaves[i] = keccak256(abi.encodePacked(accounts[i]));
        }

        // Test set and get the `affiliateMerkleRoot`.
        Merkle m = new Merkle();
        bytes32 root = m.getRoot(leaves);
        vm.expectEmit(true, true, true, true);
        emit AffiliateMerkleRootSet(address(edition), root);
        sam.setAffiliateMerkleRoot(address(edition), root);
        assertEq(sam.affiliateMerkleRoot(address(edition)), root);

        // Test the `isAffiliatedWithProof` function.
        assertTrue(sam.isAffiliatedWithProof(address(edition), accounts[0], m.getProof(leaves, 0)));
        assertTrue(sam.isAffiliatedWithProof(address(edition), accounts[1], m.getProof(leaves, 1)));
        assertFalse(sam.isAffiliatedWithProof(address(edition), address(0xbad), m.getProof(leaves, 1)));

        // Test the `onlyEditionOwnerOrAdmin` modifier.
        vm.prank(address(1));
        vm.expectRevert(Ownable.Unauthorized.selector);
        sam.setAffiliateMerkleRoot(address(edition), root);

        _mintOut(edition);

        // Test `buy` to see if it reverts for unapproved affiliate.
        bytes32[] memory proof = m.getProof(leaves, 1);
        vm.expectRevert(ISAMV1_1.InvalidAffiliate.selector);
        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, accounts[0], proof);

        sam.buy{ value: address(this).balance }(address(edition), address(this), 1, accounts[1], proof);
    }

    function test_samMulticallerSupport(uint256) public {
        MulticallerWithSender multicallerWithSender = MulticallerWithSender(
            payable(LibMulticaller.MULTICALLER_WITH_SENDER)
        );
        vm.etch(LibMulticaller.MULTICALLER_WITH_SENDER, bytes(address(new MulticallerWithSenderUpgradeable()).code));
        MulticallerWithSenderUpgradeable(payable(LibMulticaller.MULTICALLER_WITH_SENDER)).initialize();

        _testTempVariables memory t;

        (SoundEditionV1_2 edition, MockSAM sam) = _createEditionAndSAM();

        t.basePrice = _bound(_random(), 1, type(uint96).max);
        t.inflectionPrice = _bound(_random(), 1, type(uint128).max);
        t.inflectionPoint = _bound(_random(), 1, type(uint32).max);

        address[] memory targets = new address[](3);
        targets[0] = address(sam);
        targets[1] = address(sam);
        targets[2] = address(sam);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeWithSelector(ISAMV1_1.setBasePrice.selector, address(edition), uint96(t.basePrice));
        data[1] = abi.encodeWithSelector(
            ISAMV1_1.setInflectionPrice.selector,
            address(edition),
            uint128(t.inflectionPrice)
        );
        data[2] = abi.encodeWithSelector(
            ISAMV1_1.setInflectionPoint.selector,
            address(edition),
            uint32(t.inflectionPoint)
        );

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

        SAMInfo memory info = sam.samInfo(address(edition));
        assertEq(info.basePrice, t.basePrice);
        assertEq(info.inflectionPrice, t.inflectionPrice);
        assertEq(info.inflectionPoint, t.inflectionPoint);

        data[0] = abi.encodeWithSelector(ISAMV1_1.setBasePrice.selector, address(edition), uint96(1 ether));
        data[1] = abi.encodeWithSelector(ISAMV1_1.setInflectionPrice.selector, address(edition), uint96(1));
        data[2] = abi.encodeWithSelector(
            ISAMV1_1.setInflectionPoint.selector,
            address(edition),
            uint32(type(uint32).max)
        );

        multicallerWithSender.aggregateWithSender(targets, data, new uint256[](data.length));

        vm.deal(address(this), 10 ether);

        _mintOut(edition);

        MulticallerWithSenderAttacker attacker = new MulticallerWithSenderAttacker();

        address affiliate = address(attacker);

        sam.setAffiliateFee(address(edition), uint16(sam.MAX_AFFILIATE_FEE_BPS()));

        assertTrue(sam.affiliateFeesAccrued(affiliate) == 0);

        sam.buy{ value: 10 ether }(address(edition), address(this), 1, affiliate, new bytes32[](0));

        assertTrue(sam.affiliateFeesAccrued(affiliate) != 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        // Note that these calls won't revert, due to use of `forceSafeTransferETH`.
        if (_random() % 2 == 0) {
            sam.withdrawForAffiliate(affiliate);
        } else {
            targets = new address[](1);
            targets[0] = address(sam);

            data = new bytes[](1);
            data[0] = abi.encodeWithSelector(ISAMV1_1.withdrawForAffiliate.selector, affiliate);
            multicallerWithSender.aggregateWithSender(targets, data, new uint256[](data.length));
        }

        // No matter what, the attacker cannot change the affiliate fee.
        assertEq(sam.samInfo(address(edition)).affiliateFeeBPS, uint16(sam.MAX_AFFILIATE_FEE_BPS()));
    }

    function test_samRequireEditionHasApprovedBytecode() public {
        SoundEditionV1_2 edition = createGenericEdition();
        MockSAM sam = new MockSAM();

        edition.setSAM(address(sam));

        sam.setCheckEdition(true);

        vm.expectRevert(ISAMV1_1.UnapprovedEdition.selector);
        sam.create(
            address(edition),
            BASE_PRICE,
            LINEAR_PRICE_SLOPE,
            INFLECTION_PRICE,
            INFLECTION_POINT,
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            ARTIST_FEE_BPS,
            GOLDEN_EGG_FEE_BPS,
            AFFILIATE_FEE_BPS,
            address(this),
            bytes32(0)
        );

        address[] memory approvedFactories = new address[](1);
        approvedFactories[0] = address(soundCreator);
        vm.expectEmit(true, true, true, true);
        emit ApprovedEditionFactoriesSet(approvedFactories);
        sam.setApprovedEditionFactories(approvedFactories);

        sam.create(
            address(edition),
            BASE_PRICE,
            LINEAR_PRICE_SLOPE,
            INFLECTION_PRICE,
            INFLECTION_POINT,
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            ARTIST_FEE_BPS,
            GOLDEN_EGG_FEE_BPS,
            AFFILIATE_FEE_BPS,
            address(this),
            bytes32(_salt)
        );

        // Check if another clone works.
        edition = createGenericEdition();
        sam.create(
            address(edition),
            BASE_PRICE,
            LINEAR_PRICE_SLOPE,
            INFLECTION_PRICE,
            INFLECTION_POINT,
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            ARTIST_FEE_BPS,
            GOLDEN_EGG_FEE_BPS,
            AFFILIATE_FEE_BPS,
            address(this),
            bytes32(_salt)
        );

        approvedFactories = new address[](0);
        vm.expectEmit(true, true, true, true);
        emit ApprovedEditionFactoriesSet(approvedFactories);
        sam.setApprovedEditionFactories(approvedFactories);

        edition = createGenericEdition();

        vm.expectRevert(ISAMV1_1.UnapprovedEdition.selector);
        sam.create(
            address(edition),
            BASE_PRICE,
            LINEAR_PRICE_SLOPE,
            INFLECTION_PRICE,
            INFLECTION_POINT,
            MAX_SUPPLY,
            BUY_FREEZE_TIME,
            ARTIST_FEE_BPS,
            GOLDEN_EGG_FEE_BPS,
            AFFILIATE_FEE_BPS,
            address(this),
            bytes32(_salt)
        );
    }
}
