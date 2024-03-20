pragma solidity ^0.8.16;

import { Merkle } from "murky/Merkle.sol";
import { IERC721AUpgradeable, ISoundEditionV2_1, SoundEditionV2_1 } from "@core/SoundEditionV2_1.sol";
import { ISuperMinterE, SuperMinterE } from "@modules/SuperMinterE.sol";
import { DelegateCashLib } from "@modules/utils/DelegateCashLib.sol";
import { LibOps } from "@core/utils/LibOps.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { WETH } from "solady/tokens/WETH.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import "../TestConfigV2_1.sol";

contract SuperMinterETests is TestConfigV2_1 {
    SuperMinterE sm;
    SoundEditionV2_1 edition;
    Merkle merkle;
    WETH weth;

    event Minted(
        address indexed edition,
        uint8 tier,
        uint8 scheduleNum,
        address indexed to,
        ISuperMinterE.MintedLogData data,
        uint256 indexed attributionId
    );

    struct SuperMinterEConstants {
        uint96 MAX_PLATFORM_PER_TX_FLAT_FEE;
        uint96 MAX_PER_MINT_REWARD;
        uint16 MAX_PLATFORM_PER_MINT_FEE_BPS;
        uint16 MAX_AFFILIATE_FEE_BPS;
    }

    bytes constant DELEGATE_V2_REGISTRY_BYTECODE =
        hex"60806040526004361061015e5760003560e01c80638988eea9116100c0578063b9f3687411610074578063d90e73ab11610059578063d90e73ab14610383578063e839bd5314610396578063e8e834a9146103b657600080fd5b8063b9f3687414610343578063ba63c8171461036357600080fd5b8063ac9650d8116100a5578063ac9650d8146102f0578063b18e2bbb14610310578063b87058751461032357600080fd5b80638988eea9146102bd578063ab764683146102dd57600080fd5b806335faa416116101175780634705ed38116100fc5780634705ed381461025d57806351525e9a1461027d57806361451a301461029d57600080fd5b806335faa4161461021957806342f87c251461023057600080fd5b806301ffc9a71161014857806301ffc9a7146101b6578063063182a5146101e657806330ff31401461020657600080fd5b80623c2ba61461016357806301a920a014610189575b600080fd5b6101766101713660046120b4565b6103d5565b6040519081526020015b60405180910390f35b34801561019557600080fd5b506101a96101a43660046120f6565b610637565b6040516101809190612118565b3480156101c257600080fd5b506101d66101d136600461215c565b61066e565b6040519015158152602001610180565b3480156101f257600080fd5b506101a96102013660046120f6565b6106e1565b6101766102143660046121ae565b610712565b34801561022557600080fd5b5061022e6108f9565b005b34801561023c57600080fd5b5061025061024b3660046120f6565b610917565b6040516101809190612219565b34801561026957600080fd5b50610250610278366004612368565b610948565b34801561028957600080fd5b506102506102983660046120f6565b610bf0565b3480156102a957600080fd5b506101a96102b8366004612368565b610c21565b3480156102c957600080fd5b506101d66102d83660046123aa565b610cc6565b6101766102eb3660046123f5565b610dd8565b6103036102fe366004612368565b611056565b6040516101809190612442565b61017661031e366004612510565b61118d565b34801561032f57600080fd5b5061017661033e366004612567565b6113bd565b34801561034f57600080fd5b506101d661035e366004612567565b6115d8565b34801561036f57600080fd5b5061017661037e3660046123aa565b611767565b6101766103913660046125bc565b61192d565b3480156103a257600080fd5b506101d66103b1366004612609565b611b3f565b3480156103c257600080fd5b506101766103d1366004612645565b5490565b60408051603c810185905260288101869052336014820152838152605c902060081b6004176000818152602081905291909120805473ffffffffffffffffffffffffffffffffffffffff1683156105865773ffffffffffffffffffffffffffffffffffffffff81166104ec57336000818152600160208181526040808420805480850182559085528285200188905573ffffffffffffffffffffffffffffffffffffffff8c1680855260028352818520805480860182559086529290942090910187905589901b7bffffffffffffffff000000000000000000000000000000000000000016909217845560a088901b17908301556104d582600486910155565b84156104e7576104e782600287910155565b6105d4565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff73ffffffffffffffffffffffffffffffffffffffff82160161055d5781547fffffffffffffffffffffffff000000000000000000000000000000000000000016331782556104e782600486910155565b3373ffffffffffffffffffffffffffffffffffffffff8216036104e7576104e782600486910155565b3373ffffffffffffffffffffffffffffffffffffffff8216036105d45781547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001178255600060048301555b604080518681526020810186905273ffffffffffffffffffffffffffffffffffffffff80891692908a169133917f6ebd000dfc4dc9df04f723f827bae7694230795e8f22ed4af438e074cc982d1891015b60405180910390a45050949350505050565b73ffffffffffffffffffffffffffffffffffffffff8116600090815260016020526040902060609061066890611bc2565b92915050565b60007f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff0000000000000000000000000000000000000000000000000000000083169081147f5f68bc5a0000000000000000000000000000000000000000000000000000000090911417610668565b73ffffffffffffffffffffffffffffffffffffffff8116600090815260026020526040902060609061066890611bc2565b60408051602881018590523360148201528381526048902060081b6001176000818152602081905291909120805473ffffffffffffffffffffffffffffffffffffffff1683156108555773ffffffffffffffffffffffffffffffffffffffff81166107eb57336000818152600160208181526040808420805480850182559085528285200188905573ffffffffffffffffffffffffffffffffffffffff8b16808552600283529084208054808501825590855291909320018690559184559083015584156107e6576107e682600287910155565b61089c565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff73ffffffffffffffffffffffffffffffffffffffff8216016107e65781547fffffffffffffffffffffffff0000000000000000000000000000000000000000163317825561089c565b3373ffffffffffffffffffffffffffffffffffffffff82160361089c5781547fffffffffffffffffffffffff00000000000000000000000000000000000000001660011782555b60408051868152851515602082015273ffffffffffffffffffffffffffffffffffffffff88169133917fda3ef6410e30373a9137f83f9781a8129962b6882532b7c229de2e39de423227910160405180910390a350509392505050565b6000806000804770de1e80ea5a234fb5488fee2584251bc7e85af150565b73ffffffffffffffffffffffffffffffffffffffff8116600090815260026020526040902060609061066890611d41565b60608167ffffffffffffffff8111156109635761096361265e565b6040519080825280602002602001820160405280156109e857816020015b6040805160e08101825260008082526020808301829052928201819052606082018190526080820181905260a0820181905260c082015282527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9092019101816109815790505b50905060005b82811015610be9576000610a25858584818110610a0d57610a0d61268d565b90506020020135600090815260208190526040902090565b90506000610a47825473ffffffffffffffffffffffffffffffffffffffff1690565b9050610a528161200f565b15610ab6576040805160e08101909152806000815260006020820181905260408201819052606082018190526080820181905260a0820181905260c0909101528451859085908110610aa657610aa661268d565b6020026020010181905250610bdf565b815460018301546040805160e08101825273ffffffffffffffffffffffffffffffffffffffff83169360a09390931c9290911c73ffffffffffffffff00000000000000000000000016919091179080610b278a8a89818110610b1a57610b1a61268d565b9050602002013560ff1690565b6005811115610b3857610b386121ea565b81526020018373ffffffffffffffffffffffffffffffffffffffff1681526020018473ffffffffffffffffffffffffffffffffffffffff168152602001610b80866002015490565b81526020018273ffffffffffffffffffffffffffffffffffffffff168152602001610bac866003015490565b8152602001610bbc866004015490565b815250868681518110610bd157610bd161268d565b602002602001018190525050505b50506001016109ee565b5092915050565b73ffffffffffffffffffffffffffffffffffffffff8116600090815260016020526040902060609061066890611d41565b6060818067ffffffffffffffff811115610c3d57610c3d61265e565b604051908082528060200260200182016040528015610c66578160200160208202803683370190505b50915060008060005b83811015610cbc57868682818110610c8957610c8961268d565b9050602002013592508254915081858281518110610ca957610ca961268d565b6020908102919091010152600101610c6f565b5050505092915050565b6000610cd18461200f565b610dcc576040805160288101879052601481018690526000808252604890912060081b6001178152602081905220610d0a905b85612035565b80610d4a575060408051603c810185905260288101879052601481018690526000808252605c90912060081b6002178152602081905220610d4a90610d04565b9050801515821517610dcc576040805160288101879052601481018690528381526048902060081b6001176000908152602081905220610d8990610d04565b80610dc9575060408051603c81018590526028810187905260148101869052838152605c902060081b6002176000908152602081905220610dc990610d04565b90505b80151560005260206000f35b60408051605c8101859052603c810186905260288101879052336014820152838152607c902060081b6005176000818152602081905291909120805473ffffffffffffffffffffffffffffffffffffffff168315610f9c5773ffffffffffffffffffffffffffffffffffffffff8116610f0257336000818152600160208181526040808420805480850182559085528285200188905573ffffffffffffffffffffffffffffffffffffffff8d168085526002835281852080548086018255908652929094209091018790558a901b7bffffffffffffffff000000000000000000000000000000000000000016909217845560a089901b1790830155610edf82600388910155565b610eeb82600486910155565b8415610efd57610efd82600287910155565b610fea565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff73ffffffffffffffffffffffffffffffffffffffff821601610f735781547fffffffffffffffffffffffff00000000000000000000000000000000000000001633178255610efd82600486910155565b3373ffffffffffffffffffffffffffffffffffffffff821603610efd57610efd82600486910155565b3373ffffffffffffffffffffffffffffffffffffffff821603610fea5781547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001178255600060048301555b604080518781526020810187905290810185905273ffffffffffffffffffffffffffffffffffffffff80891691908a169033907f27ab1adc9bca76301ed7a691320766dfa4b4b1aa32c9e05cf789611be7f8c75f906060015b60405180910390a4505095945050505050565b60608167ffffffffffffffff8111156110715761107161265e565b6040519080825280602002602001820160405280156110a457816020015b606081526020019060019003908161108f5790505b5090506000805b8381101561118557308585838181106110c6576110c661268d565b90506020028101906110d891906126bc565b6040516110e6929190612721565b600060405180830381855af49150503d8060008114611121576040519150601f19603f3d011682016040523d82523d6000602084013e611126565b606091505b508483815181106111395761113961268d565b602090810291909101015291508161117d576040517f4d6a232800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001016110ab565b505092915050565b60408051605c8101859052603c810186905260288101879052336014820152838152607c902060081b6003176000818152602081905291909120805473ffffffffffffffffffffffffffffffffffffffff1683156113155773ffffffffffffffffffffffffffffffffffffffff81166112ab57336000818152600160208181526040808420805480850182559085528285200188905573ffffffffffffffffffffffffffffffffffffffff8d168085526002835281852080548086018255908652929094209091018790558a901b7bffffffffffffffff000000000000000000000000000000000000000016909217845560a089901b179083015561129482600388910155565b84156112a6576112a682600287910155565b61135c565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff73ffffffffffffffffffffffffffffffffffffffff8216016112a65781547fffffffffffffffffffffffff0000000000000000000000000000000000000000163317825561135c565b3373ffffffffffffffffffffffffffffffffffffffff82160361135c5781547fffffffffffffffffffffffff00000000000000000000000000000000000000001660011782555b60408051878152602081018790528515159181019190915273ffffffffffffffffffffffffffffffffffffffff80891691908a169033907f15e7a1bdcd507dd632d797d38e60cc5a9c0749b9a63097a215c4d006126825c690606001611043565b60006113c88561200f565b6115ce576040805160288101889052601481018790526000808252604890912060081b6001178152602081905220611401905b86612035565b80611441575060408051603c810186905260288101889052601481018790526000808252605c90912060081b6002178152602081905220611441906113fb565b61148e5760408051605c8101859052603c810186905260288101889052601481018790526000808252607c90912060081b6005178152602081905220611489905b6004015490565b6114b0565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5b90507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81148215176115ce576040805160288101889052601481018790528381526048902060081b60011760009081526020819052908120611513905b87612035565b80611553575060408051603c81018790526028810189905260148101889052848152605c902060081b60021760009081526020819052206115539061150d565b61159d5760408051605c8101869052603c81018790526028810189905260148101889052848152607c902060081b600517600090815260208190522061159890611482565b6115bf565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5b90508181108282180281189150505b8060005260206000f35b60006115e38561200f565b610dcc576040805160288101889052601481018790526000808252604890912060081b600117815260208190522061161a906113fb565b8061165a575060408051603c810186905260288101889052601481018790526000808252605c90912060081b600217815260208190522061165a906113fb565b806116a1575060408051605c8101859052603c810186905260288101889052601481018790526000808252607c90912060081b60031781526020819052206116a1906113fb565b9050801515821517610dcc576040805160288101889052601481018790528381526048902060081b60011760009081526020819052206116e0906113fb565b80611720575060408051603c81018690526028810188905260148101879052838152605c902060081b6002176000908152602081905220611720906113fb565b80610dc9575060408051605c8101859052603c81018690526028810188905260148101879052838152607c902060081b6003176000908152602081905220610dc9906113fb565b60006117728461200f565b6115ce576040805160288101879052601481018690526000808252604890912060081b60011781526020819052206117a990610d04565b806117e9575060408051603c810185905260288101879052601481018690526000808252605c90912060081b60021781526020819052206117e990610d04565b61182c5760408051603c810185905260288101879052601481018690526000808252605c90912060081b600417815260208190522061182790611482565b61184e565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5b90507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81148215176115ce576040805160288101879052601481018690528381526048902060081b600117600090815260208190529081206118af906113fb565b806118ef575060408051603c81018690526028810188905260148101879052848152605c902060081b60021760009081526020819052206118ef906113fb565b61159d5760408051603c81018690526028810188905260148101879052848152605c902060081b600417600090815260208190522061159890611482565b60408051603c810185905260288101869052336014820152838152605c902060081b6002176000818152602081905291909120805473ffffffffffffffffffffffffffffffffffffffff168315611aa25773ffffffffffffffffffffffffffffffffffffffff8116611a3857336000818152600160208181526040808420805480850182559085528285200188905573ffffffffffffffffffffffffffffffffffffffff8c1680855260028352818520805480860182559086529290942090910187905589901b7bffffffffffffffff000000000000000000000000000000000000000016909217845560a088901b17908301558415611a3357611a3382600287910155565b611ae9565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff73ffffffffffffffffffffffffffffffffffffffff821601611a335781547fffffffffffffffffffffffff00000000000000000000000000000000000000001633178255611ae9565b3373ffffffffffffffffffffffffffffffffffffffff821603611ae95781547fffffffffffffffffffffffff00000000000000000000000000000000000000001660011782555b60408051868152851515602082015273ffffffffffffffffffffffffffffffffffffffff80891692908a169133917f021be15e24de4afc43cfb5d0ba95ca38e0783571e05c12bbe6aece8842ae82df9101610625565b6000611b4a8361200f565b610dcc576040805160288101869052601481018590526000808252604890912060081b6001178152602081905220611b83905b84612035565b9050801515821517610dcc576040805160288101869052601481018590528381526048902060081b6001176000908152602081905220610dc990611b7d565b805460609060009081808267ffffffffffffffff811115611be557611be561265e565b604051908082528060200260200182016040528015611c0e578160200160208202803683370190505b50905060005b83811015611ca757868181548110611c2e57611c2e61268d565b90600052602060002001549250611c75611c70611c5685600090815260208190526040902090565b5473ffffffffffffffffffffffffffffffffffffffff1690565b61200f565b611c9f5782828680600101975081518110611c9257611c9261268d565b6020026020010181815250505b600101611c14565b508367ffffffffffffffff811115611cc157611cc161265e565b604051908082528060200260200182016040528015611cea578160200160208202803683370190505b50945060005b84811015611d3757818181518110611d0a57611d0a61268d565b6020026020010151868281518110611d2457611d2461268d565b6020908102919091010152600101611cf0565b5050505050919050565b805460609060009081808267ffffffffffffffff811115611d6457611d6461265e565b604051908082528060200260200182016040528015611d8d578160200160208202803683370190505b50905060005b83811015611e0757868181548110611dad57611dad61268d565b90600052602060002001549250611dd5611c70611c5685600090815260208190526040902090565b611dff5782828680600101975081518110611df257611df261268d565b6020026020010181815250505b600101611d93565b508367ffffffffffffffff811115611e2157611e2161265e565b604051908082528060200260200182016040528015611ea657816020015b6040805160e08101825260008082526020808301829052928201819052606082018190526080820181905260a0820181905260c082015282527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff909201910181611e3f5790505b5094506000805b8581101561200457828181518110611ec757611ec761268d565b60200260200101519350611ee684600090815260208190526040902090565b805460018201546040805160e08101825293955073ffffffffffffffffffffffffffffffffffffffff808416949083169360a09390931c9290911c73ffffffffffffffff0000000000000000000000001691909117908060ff89166005811115611f5257611f526121ea565b81526020018373ffffffffffffffffffffffffffffffffffffffff1681526020018473ffffffffffffffffffffffffffffffffffffffff168152602001611f9a876002015490565b81526020018273ffffffffffffffffffffffffffffffffffffffff168152602001611fc6876003015490565b8152602001611fd6876004015490565b8152508a8581518110611feb57611feb61268d565b6020026020010181905250505050806001019050611ead565b505050505050919050565b6000600173ffffffffffffffffffffffffffffffffffffffff8316908114901517610668565b6000612055835473ffffffffffffffffffffffffffffffffffffffff1690565b73ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1614905092915050565b803573ffffffffffffffffffffffffffffffffffffffff811681146120af57600080fd5b919050565b600080600080608085870312156120ca57600080fd5b6120d38561208b565b93506120e16020860161208b565b93969395505050506040820135916060013590565b60006020828403121561210857600080fd5b6121118261208b565b9392505050565b6020808252825182820181905260009190848201906040850190845b8181101561215057835183529284019291840191600101612134565b50909695505050505050565b60006020828403121561216e57600080fd5b81357fffffffff000000000000000000000000000000000000000000000000000000008116811461211157600080fd5b803580151581146120af57600080fd5b6000806000606084860312156121c357600080fd5b6121cc8461208b565b9250602084013591506121e16040850161219e565b90509250925092565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602160045260246000fd5b60208082528251828201819052600091906040908185019086840185805b8381101561230e578251805160068110612278577f4e487b710000000000000000000000000000000000000000000000000000000084526021600452602484fd5b86528088015173ffffffffffffffffffffffffffffffffffffffff1688870152868101516122bd8888018273ffffffffffffffffffffffffffffffffffffffff169052565b506060818101519087015260808082015173ffffffffffffffffffffffffffffffffffffffff169087015260a0808201519087015260c0908101519086015260e09094019391860191600101612237565b509298975050505050505050565b60008083601f84011261232e57600080fd5b50813567ffffffffffffffff81111561234657600080fd5b6020830191508360208260051b850101111561236157600080fd5b9250929050565b6000806020838503121561237b57600080fd5b823567ffffffffffffffff81111561239257600080fd5b61239e8582860161231c565b90969095509350505050565b600080600080608085870312156123c057600080fd5b6123c98561208b565b93506123d76020860161208b565b92506123e56040860161208b565b9396929550929360600135925050565b600080600080600060a0868803121561240d57600080fd5b6124168661208b565b94506124246020870161208b565b94979496505050506040830135926060810135926080909101359150565b6000602080830181845280855180835260408601915060408160051b87010192508387016000805b83811015612502577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc089870301855282518051808852835b818110156124bd578281018a01518982018b015289016124a2565b508781018901849052601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01690960187019550938601939186019160010161246a565b509398975050505050505050565b600080600080600060a0868803121561252857600080fd5b6125318661208b565b945061253f6020870161208b565b9350604086013592506060860135915061255b6080870161219e565b90509295509295909350565b600080600080600060a0868803121561257f57600080fd5b6125888661208b565b94506125966020870161208b565b93506125a46040870161208b565b94979396509394606081013594506080013592915050565b600080600080608085870312156125d257600080fd5b6125db8561208b565b93506125e96020860161208b565b9250604085013591506125fe6060860161219e565b905092959194509250565b60008060006060848603121561261e57600080fd5b6126278461208b565b92506126356020850161208b565b9150604084013590509250925092565b60006020828403121561265757600080fd5b5035919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b60008083357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe18436030181126126f157600080fd5b83018035915067ffffffffffffffff82111561270c57600080fd5b60200191503681900382131561236157600080fd5b818382376000910190815291905056fea164736f6c6343000815000a";

    function setUp() public virtual override {
        super.setUp();
        ISoundEditionV2_1.EditionInitialization memory init = genericEditionInitialization();
        init.tierCreations = new ISoundEditionV2_1.TierCreation[](2);
        init.tierCreations[0].tier = 0;
        init.tierCreations[1].tier = 1;
        init.tierCreations[1].maxMintableLower = type(uint32).max;
        init.tierCreations[1].maxMintableUpper = type(uint32).max;
        edition = createSoundEdition(init);
        sm = new SuperMinterE();
        edition.grantRoles(address(sm), edition.MINTER_ROLE());
        merkle = new Merkle();
        weth = new WETH();
    }

    function _superMinterConstants() internal view returns (SuperMinterEConstants memory smc) {
        smc.MAX_PLATFORM_PER_TX_FLAT_FEE = sm.MAX_PLATFORM_PER_TX_FLAT_FEE();
        smc.MAX_PER_MINT_REWARD = sm.MAX_PER_MINT_REWARD();
        smc.MAX_PLATFORM_PER_MINT_FEE_BPS = sm.MAX_PLATFORM_PER_MINT_FEE_BPS();
        smc.MAX_AFFILIATE_FEE_BPS = sm.MAX_AFFILIATE_FEE_BPS();
    }

    function test_createMints() public {
        uint256 gaPrice = 123 ether;
        sm.setGAPrice(uint96(gaPrice));

        assertEq(sm.mintInfoList(address(edition)).length, 0);
        for (uint256 j; j < 3; ++j) {
            for (uint256 i; i < 3; ++i) {
                ISuperMinterE.MintCreation memory c;
                c.maxMintable = type(uint32).max;
                c.platform = address(this);
                c.edition = address(edition);
                c.tier = uint8(i * 2);
                c.price = uint96(i * 1 ether);
                c.startTime = uint32(block.timestamp + i);
                c.endTime = uint32(block.timestamp + 1000 + i);
                c.maxMintablePerAccount = uint32(10 + i);
                c.affiliateMerkleRoot = keccak256(abi.encodePacked(999 + j * 333 + i));
                if (i == 1) {
                    c.mode = sm.VERIFY_MERKLE();
                    c.merkleRoot = keccak256("x");
                }
                if (i == 2) {
                    c.mode = sm.VERIFY_SIGNATURE();
                }
                uint8 nextScheduleNum = sm.nextScheduleNum(c.edition, c.tier);
                assertEq(sm.createEditionMint(c), nextScheduleNum);
                assertEq(nextScheduleNum, j);
                assertEq(sm.mintInfoList(address(edition)).length, j * 3 + i + 1);
            }
        }

        address signer = _randomNonZeroAddress();
        sm.setPlatformSigner(signer);

        ISuperMinterE.MintInfo[] memory mintInfoList = sm.mintInfoList(address(edition));
        assertEq(mintInfoList.length, 3 * 3);
        for (uint256 j; j < 3; ++j) {
            for (uint256 i; i < 3; ++i) {
                ISuperMinterE.MintInfo memory info = mintInfoList[j * 3 + i];
                assertEq(info.scheduleNum, j);
                assertEq(info.edition, address(edition));
                assertEq(info.startTime, uint32(block.timestamp + i));
                assertEq(info.affiliateMerkleRoot, keccak256(abi.encodePacked(999 + j * 333 + i)));
                if (i == 0) {
                    assertEq(info.mode, sm.DEFAULT());
                    assertEq(info.price, gaPrice);
                    assertEq(info.maxMintablePerAccount, type(uint32).max);
                    assertEq(info.endTime, type(uint32).max);
                    assertEq(info.mode, sm.DEFAULT());
                    assertEq(info.merkleRoot, bytes32(0));
                    assertEq(info.signer, signer);
                }
                if (i == 1) {
                    assertEq(info.mode, sm.VERIFY_MERKLE());
                    assertEq(info.price, i * 1 ether);
                    assertEq(info.maxMintablePerAccount, 10 + i);
                    assertEq(info.endTime, uint32(block.timestamp + 1000 + i));
                    assertEq(info.mode, sm.VERIFY_MERKLE());
                    assertEq(info.merkleRoot, keccak256("x"));
                    assertEq(info.signer, signer);
                }
                if (i == 2) {
                    assertEq(info.mode, sm.VERIFY_SIGNATURE());
                    assertEq(info.price, i * 1 ether);
                    assertEq(info.maxMintablePerAccount, type(uint32).max);
                    assertEq(info.endTime, uint32(block.timestamp + 1000 + i));
                    assertEq(info.mode, sm.VERIFY_SIGNATURE());
                    assertEq(info.signer, signer);
                }
            }
        }
    }

    function test_settersConfigurable(uint256) public {
        ISuperMinterE.MintCreation memory c;
        c.maxMintable = uint32(_bound(_random(), 1, type(uint32).max));
        c.platform = address(this);
        c.edition = address(edition);
        c.tier = uint8(_random() % 2);
        c.mode = uint8(_random() % 3);
        c.price = uint96(_bound(_random(), 0, type(uint96).max));
        c.startTime = uint32(block.timestamp + _bound(_random(), 0, 1000));
        c.endTime = uint32(c.startTime + _bound(_random(), 0, 1000));
        c.maxMintablePerAccount = uint32(_bound(_random(), 1, type(uint32).max));
        c.merkleRoot = keccak256(abi.encodePacked(_random()));

        assertEq(sm.createEditionMint(c), 0);

        ISuperMinterE.MintInfo memory info = sm.mintInfo(address(edition), c.tier, 0);
        assertEq(info.platform, address(this));
        if (c.tier == 0) {
            if (c.mode == sm.DEFAULT()) {
                assertEq(info.merkleRoot, bytes32(0));
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMerkleRoot(address(edition), c.tier, 0, c.merkleRoot);

                assertEq(info.price, 0);
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setPrice(address(edition), c.tier, 0, c.price);

                assertEq(info.maxMintable, type(uint32).max);
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMaxMintable(address(edition), c.tier, 0, c.maxMintable);

                assertEq(info.maxMintablePerAccount, type(uint32).max);
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMaxMintablePerAccount(address(edition), c.tier, 0, c.maxMintablePerAccount);
            } else if (c.mode == sm.VERIFY_MERKLE()) {
                assertEq(info.merkleRoot, c.merkleRoot);
                sm.setMerkleRoot(address(edition), c.tier, 0, c.merkleRoot);

                assertEq(info.price, 0);
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setPrice(address(edition), c.tier, 0, c.price);

                assertEq(info.maxMintable, c.maxMintable);
                sm.setMaxMintable(address(edition), c.tier, 0, c.maxMintable);

                assertEq(info.maxMintablePerAccount, type(uint32).max);
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMaxMintablePerAccount(address(edition), c.tier, 0, c.maxMintablePerAccount);
            } else if (c.mode == sm.VERIFY_SIGNATURE()) {
                assertEq(info.signer, sm.platformSigner(c.platform));

                assertEq(info.merkleRoot, bytes32(0));
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMerkleRoot(address(edition), c.tier, 0, c.merkleRoot);

                assertEq(info.price, c.price);
                sm.setPrice(address(edition), c.tier, 0, c.price);

                assertEq(info.maxMintable, c.maxMintable);
                sm.setMaxMintable(address(edition), c.tier, 0, c.maxMintable);

                assertEq(info.maxMintablePerAccount, type(uint32).max);
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMaxMintablePerAccount(address(edition), c.tier, 0, c.maxMintablePerAccount);
            }
        } else {
            if (c.mode == sm.DEFAULT()) {
                assertEq(info.merkleRoot, bytes32(0));
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMerkleRoot(address(edition), c.tier, 0, c.merkleRoot);

                assertEq(info.price, c.price);
                sm.setPrice(address(edition), c.tier, 0, c.price);

                assertEq(info.maxMintable, c.maxMintable);
                sm.setMaxMintable(address(edition), c.tier, 0, c.maxMintable);

                assertEq(info.maxMintablePerAccount, c.maxMintablePerAccount);
                sm.setMaxMintablePerAccount(address(edition), c.tier, 0, c.maxMintablePerAccount);
            } else if (c.mode == sm.VERIFY_MERKLE()) {
                assertEq(info.merkleRoot, c.merkleRoot);
                sm.setMerkleRoot(address(edition), c.tier, 0, c.merkleRoot);

                assertEq(info.price, c.price);
                sm.setPrice(address(edition), c.tier, 0, c.price);

                assertEq(info.maxMintable, c.maxMintable);
                sm.setMaxMintable(address(edition), c.tier, 0, c.maxMintable);

                assertEq(info.maxMintablePerAccount, c.maxMintablePerAccount);
                sm.setMaxMintablePerAccount(address(edition), c.tier, 0, c.maxMintablePerAccount);
            } else if (c.mode == sm.VERIFY_SIGNATURE()) {
                assertEq(info.signer, sm.platformSigner(c.platform));

                assertEq(info.merkleRoot, bytes32(0));
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMerkleRoot(address(edition), c.tier, 0, c.merkleRoot);

                assertEq(info.price, c.price);
                sm.setPrice(address(edition), c.tier, 0, c.price);

                assertEq(info.maxMintable, c.maxMintable);
                sm.setMaxMintable(address(edition), c.tier, 0, c.maxMintable);

                assertEq(info.maxMintablePerAccount, type(uint32).max);
                vm.expectRevert(ISuperMinterE.NotConfigurable.selector);
                sm.setMaxMintablePerAccount(address(edition), c.tier, 0, c.maxMintablePerAccount);
            }
        }
    }

    function test_platformAirdrop(uint256) public {
        (address signer, uint256 privateKey) = _randomSigner();

        ISuperMinterE.MintCreation memory c;
        c.maxMintable = uint32(_bound(_random(), 1, 64));
        c.platform = address(this);
        c.edition = address(edition);
        c.startTime = 0;
        c.tier = uint8(_random() % 2);
        c.endTime = uint32(block.timestamp + 1000);
        c.maxMintablePerAccount = uint32(_random()); // Doesn't matter, will be auto set to max.
        c.mode = sm.PLATFORM_AIRDROP();
        assertEq(sm.createEditionMint(c), 0);

        vm.prank(c.platform);
        sm.setPlatformSigner(signer);

        unchecked {
            ISuperMinterE.PlatformAirdrop memory p;
            p.edition = address(edition);
            p.tier = c.tier;
            p.scheduleNum = 0;
            p.to = new address[](_bound(_random(), 1, 8));
            p.signedQuantity = uint32(_bound(_random(), 1, 8));
            p.signedClaimTicket = uint32(_bound(_random(), 0, type(uint32).max));
            p.signedDeadline = type(uint32).max;
            for (uint256 i; i < p.to.length; ++i) {
                p.to[i] = _randomNonZeroAddress();
            }
            LibSort.sort(p.to);
            LibSort.uniquifySorted(p.to);
            p.signature = _generatePlatformAirdropSignature(p, privateKey);

            uint256 expectedMinted = p.signedQuantity * p.to.length;
            if (expectedMinted > c.maxMintable) {
                vm.expectRevert(ISuperMinterE.ExceedsMintSupply.selector);
                sm.platformAirdrop(p);
                return;
            }

            sm.platformAirdrop(p);
            assertEq(sm.mintInfo(address(edition), p.tier, p.scheduleNum).minted, expectedMinted);
            for (uint256 i; i < p.to.length; ++i) {
                assertEq(edition.balanceOf(p.to[i]), p.signedQuantity);
                assertEq(sm.numberMinted(address(edition), p.tier, p.scheduleNum, p.to[i]), p.signedQuantity);
            }

            vm.expectRevert(ISuperMinterE.SignatureAlreadyUsed.selector);
            sm.platformAirdrop(p);
        }
    }

    function test_mintDefaultUpToMaxPerAccount() public {
        ISuperMinterE.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = address(this);
        c.edition = address(edition);
        c.tier = 0;
        c.price = 1 ether;
        c.startTime = 0;
        c.endTime = uint32(block.timestamp + 1000);
        c.maxMintablePerAccount = uint32(10);
        assertEq(sm.createEditionMint(c), 0);
        c.tier = 0;
        assertEq(sm.createEditionMint(c), 1);
        c.tier = 1;
        assertEq(sm.createEditionMint(c), 0);

        ISuperMinterE.MintTo memory p;
        p.edition = address(edition);
        p.tier = 0;
        p.scheduleNum = 0;
        p.to = address(this);
        p.quantity = 2;

        sm.mintTo{ value: 0 }(p);
        assertEq(edition.balanceOf(address(this)), p.quantity);
        assertEq(sm.numberMinted(address(edition), 0, 0, address(this)), p.quantity);

        p.tier = 1;
        sm.mintTo{ value: p.quantity * 1 ether }(p);
        assertEq(edition.balanceOf(address(this)), p.quantity * 2);
        assertEq(sm.numberMinted(address(edition), 1, 0, address(this)), p.quantity);

        assertEq(edition.tokenTier(1), 0);
        assertEq(edition.tokenTier(2), 0);
        assertEq(edition.tokenTier(3), 1);
        assertEq(edition.tokenTier(4), 1);

        assertEq(sm.mintInfo(address(edition), 0, 0).maxMintablePerAccount, type(uint32).max);
        p.tier = 0;
        p.quantity = 20;
        sm.mintTo{ value: 0 }(p);

        p.tier = 1;
        p.quantity = 9;
        vm.expectRevert(ISuperMinterE.ExceedsMaxPerAccount.selector);
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        p.quantity = 8;
        sm.mintTo{ value: p.quantity * 1 ether }(p);
        assertEq(edition.tierTokenIds(1).length, 10);
    }

    function _twoRandomUniqueAddresses() internal returns (address[] memory c) {
        c = new address[](2);
        c[0] = _randomNonZeroAddress();
        do {
            c[1] = _randomNonZeroAddress();
        } while (c[1] == c[0]);
    }

    function test_mintMerkleUpToMaxPerAccount() public {
        address[] memory allowlisted = _twoRandomUniqueAddresses();
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(allowlisted[0]));
        leaves[1] = keccak256(abi.encodePacked(allowlisted[1]));

        ISuperMinterE.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = address(this);
        c.edition = address(edition);
        c.tier = 1;
        c.mode = sm.VERIFY_MERKLE();
        c.merkleRoot = merkle.getRoot(leaves);
        c.startTime = 0;
        c.endTime = uint32(block.timestamp + 1000);
        c.maxMintablePerAccount = uint32(10);
        c.price = 1 ether;
        // Schedule 0.
        assertEq(sm.createEditionMint(c), 0);

        ISuperMinterE.MintTo memory p;
        p.edition = address(edition);
        p.tier = 1;
        p.scheduleNum = 0;
        p.to = allowlisted[0];
        p.allowlisted = allowlisted[0];
        p.quantity = 2;
        p.allowlistedQuantity = type(uint32).max;
        p.allowlistProof = merkle.getProof(leaves, 0);

        // Try mint with a corrupted proof.
        p.allowlistProof[0] = bytes32(uint256(p.allowlistProof[0]) ^ 1);
        vm.expectRevert(ISuperMinterE.InvalidMerkleProof.selector);
        sm.mintTo{ value: p.quantity * 1 ether }(p);
        // Restore the proof.
        p.allowlistProof[0] = bytes32(uint256(p.allowlistProof[0]) ^ 1);

        sm.mintTo{ value: p.quantity * 1 ether }(p);
        assertEq(edition.balanceOf(allowlisted[0]), p.quantity);
        assertEq(edition.tokenTier(1), 1);
        assertEq(edition.tokenTier(2), 1);

        assertEq(sm.numberMinted(address(edition), 1, 0, allowlisted[0]), p.quantity);
        assertEq(sm.numberMinted(address(edition), 1, 0, allowlisted[1]), 0);

        p.quantity = 9;
        vm.expectRevert(ISuperMinterE.ExceedsMaxPerAccount.selector);
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        p.quantity = 8;
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        p.quantity = 1;
        vm.expectRevert(ISuperMinterE.ExceedsMaxPerAccount.selector);
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        // Schedule 1.
        assertEq(sm.createEditionMint(c), 1);

        p.scheduleNum = 1;
        p.quantity = 1;
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        leaves[0] = keccak256(abi.encodePacked(allowlisted[0], uint32(3)));
        leaves[1] = keccak256(abi.encodePacked(allowlisted[1], uint32(3)));

        sm.setMerkleRoot(address(edition), 1, 1, merkle.getRoot(leaves));

        p.allowlistProof = merkle.getProof(leaves, 0);
        p.quantity = 3;
        p.allowlistedQuantity = 3;
        vm.expectRevert(ISuperMinterE.ExceedsMaxPerAccount.selector);
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        p.quantity = 2;
        sm.mintTo{ value: p.quantity * 1 ether }(p);
    }

    function _setDelegateForAll(address delegate, bool value) internal {
        if (address(DelegateCashLib.REGISTRY_V2).code.length == 0) {
            vm.etch(DelegateCashLib.REGISTRY_V2, DELEGATE_V2_REGISTRY_BYTECODE);
        }
        (bool success, ) = address(DelegateCashLib.REGISTRY_V2).call(
            abi.encodeWithSignature("delegateAll(address,bytes32,bool)", delegate, bytes32(0), value)
        );
        assertTrue(success);
    }

    function test_mintMerkleWithDelegate() public {
        address[] memory allowlisted = _twoRandomUniqueAddresses();
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(allowlisted[0]));
        leaves[1] = keccak256(abi.encodePacked(allowlisted[1]));

        ISuperMinterE.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = address(this);
        c.edition = address(edition);
        c.tier = 1;
        c.mode = sm.VERIFY_MERKLE();
        c.merkleRoot = merkle.getRoot(leaves);
        c.startTime = 0;
        c.endTime = uint32(block.timestamp + 1000);
        c.maxMintablePerAccount = uint32(10);
        c.price = 1 ether;
        // Schedule 0.
        assertEq(sm.createEditionMint(c), 0);

        ISuperMinterE.MintTo memory p;
        p.edition = address(edition);
        p.tier = 1;
        p.scheduleNum = 0;
        p.to = address(this);
        p.allowlisted = allowlisted[0];
        p.quantity = 1;
        p.allowlistedQuantity = type(uint32).max;
        p.allowlistProof = merkle.getProof(leaves, 0);

        uint256 expectedNFTBalance;

        vm.deal(allowlisted[0], 1000 ether);

        vm.expectRevert(ISuperMinterE.CallerNotDelegated.selector);
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        vm.prank(allowlisted[0]);
        sm.mintTo{ value: p.quantity * 1 ether }(p);
        expectedNFTBalance += p.quantity;

        vm.expectRevert(ISuperMinterE.CallerNotDelegated.selector);
        sm.mintTo{ value: p.quantity * 1 ether }(p);

        for (uint256 q; q < 3; ++q) {
            vm.prank(allowlisted[0]);
            _setDelegateForAll(address(this), true);

            sm.mintTo{ value: p.quantity * 1 ether }(p);
            expectedNFTBalance += p.quantity;

            vm.prank(allowlisted[0]);
            _setDelegateForAll(address(this), false);

            vm.expectRevert(ISuperMinterE.CallerNotDelegated.selector);
            sm.mintTo{ value: p.quantity * 1 ether }(p);
        }

        assertEq(edition.balanceOf(address(this)), expectedNFTBalance);
    }

    function test_platformFeeConfig() public {
        uint8 tier = 12;

        _checkEffectivePlatformFeeConfig(tier, 0, 0, 0, false);
        _checkDefaultPlatformFeeConfig(0, 0, 0, false);

        _setDefaultPlatformFeeConfig(1, 2, 3, true);
        _checkDefaultPlatformFeeConfig(1, 2, 3, true);
        _checkEffectivePlatformFeeConfig(tier, 1, 2, 3, true);
        _setDefaultPlatformFeeConfig(1, 2, 3, false);
        _checkDefaultPlatformFeeConfig(1, 2, 3, false);
        _checkEffectivePlatformFeeConfig(tier, 0, 0, 0, false);

        _setPlatformFeeConfig(tier, 11, 22, 33, true);
        _checkEffectivePlatformFeeConfig(tier, 11, 22, 33, true);
        _setPlatformFeeConfig(tier, 11, 22, 33, false);
        _checkEffectivePlatformFeeConfig(tier, 0, 0, 0, false);
        _setDefaultPlatformFeeConfig(1, 2, 3, true);
        _checkEffectivePlatformFeeConfig(tier, 1, 2, 3, true);
        _setPlatformFeeConfig(tier, 11, 22, 33, true);
        _checkEffectivePlatformFeeConfig(tier, 11, 22, 33, true);
    }

    function test_platformFeeConfig(uint256) public {
        SuperMinterEConstants memory smc = _superMinterConstants();
        uint96 perTxFlat = uint96(_bound(_random(), 0, smc.MAX_PLATFORM_PER_TX_FLAT_FEE * 2));
        uint96 platformReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD * 2));
        uint16 perMintBPS = uint16(_bound(_random(), 0, smc.MAX_PLATFORM_PER_MINT_FEE_BPS * 2));

        uint8 tier = uint8(_random());
        bool active = _random() % 2 == 0;

        bool expectRevert = perTxFlat > smc.MAX_PLATFORM_PER_TX_FLAT_FEE ||
            platformReward > smc.MAX_PER_MINT_REWARD ||
            perMintBPS > smc.MAX_PLATFORM_PER_MINT_FEE_BPS;

        if (expectRevert) vm.expectRevert(ISuperMinterE.InvalidPlatformFeeConfig.selector);

        if (_random() % 2 == 0) {
            _setPlatformFeeConfig(tier, perTxFlat, platformReward, perMintBPS, active);
            if (!expectRevert) {
                if (active) {
                    _checkEffectivePlatformFeeConfig(tier, perTxFlat, platformReward, perMintBPS, true);
                } else {
                    _checkEffectivePlatformFeeConfig(tier, 0, 0, 0, false);
                }
            }
        } else {
            _setDefaultPlatformFeeConfig(perTxFlat, platformReward, perMintBPS, active);
            if (!expectRevert) {
                if (active) {
                    _checkEffectivePlatformFeeConfig(tier, perTxFlat, platformReward, perMintBPS, true);
                    _checkDefaultPlatformFeeConfig(perTxFlat, platformReward, perMintBPS, true);
                } else {
                    _checkEffectivePlatformFeeConfig(tier, 0, 0, 0, false);
                    _checkDefaultPlatformFeeConfig(perTxFlat, platformReward, perMintBPS, false);
                }
            }
        }
    }

    function _setDefaultPlatformFeeConfig(
        uint96 perTxFlat,
        uint96 platformReward,
        uint16 perMintBPS,
        bool active
    ) internal {
        ISuperMinterE.PlatformFeeConfig memory c;
        c.platformTxFlatFee = perTxFlat;
        c.platformMintReward = platformReward;
        c.platformMintFeeBPS = perMintBPS;
        c.active = active;
        sm.setDefaultPlatformFeeConfig(c);
    }

    function _setPlatformFeeConfig(
        uint8 tier,
        uint96 perTxFlat,
        uint96 platformReward,
        uint16 perMintBPS,
        bool active
    ) internal {
        ISuperMinterE.PlatformFeeConfig memory c;
        c.platformTxFlatFee = perTxFlat;
        c.platformMintReward = platformReward;
        c.platformMintFeeBPS = perMintBPS;
        c.active = active;
        sm.setPlatformFeeConfig(tier, c);
    }

    function _checkDefaultPlatformFeeConfig(
        uint96 perTxFlat,
        uint96 platformReward,
        uint16 perMintBPS,
        bool active
    ) internal {
        _checkPlatformFeeConfig(
            sm.defaultPlatformFeeConfig(address(this)),
            perTxFlat,
            platformReward,
            perMintBPS,
            active
        );
    }

    function _checkEffectivePlatformFeeConfig(
        uint8 tier,
        uint96 perTxFlat,
        uint96 platformReward,
        uint16 perMintBPS,
        bool active
    ) internal {
        _checkPlatformFeeConfig(
            sm.effectivePlatformFeeConfig(address(this), tier),
            perTxFlat,
            platformReward,
            perMintBPS,
            active
        );
    }

    function _checkPlatformFeeConfig(
        ISuperMinterE.PlatformFeeConfig memory result,
        uint96 perTxFlat,
        uint96 platformReward,
        uint16 perMintBPS,
        bool active
    ) internal {
        assertEq(result.platformTxFlatFee, perTxFlat);
        assertEq(result.platformMintReward, platformReward);
        assertEq(result.platformMintFeeBPS, perMintBPS);
        assertEq(result.active, active);
    }

    function test_unitPrice(uint256) public {
        SuperMinterEConstants memory smc = _superMinterConstants();

        ISuperMinterE.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = _randomNonZeroAddress();
        c.edition = address(edition);
        c.tier = uint8(_random() % 2);
        c.mode = uint8(_random() % 3);
        c.price = uint96(_bound(_random(), 0, type(uint96).max));
        c.affiliateFeeBPS = uint16(_bound(_random(), 0, smc.MAX_AFFILIATE_FEE_BPS));
        c.startTime = 0;
        c.endTime = uint32(block.timestamp + 1000);
        c.maxMintablePerAccount = type(uint32).max;
        if (c.mode == sm.VERIFY_MERKLE()) {
            c.merkleRoot = bytes32(_random() | 1);
        }
        assertEq(sm.createEditionMint(c), 0);

        uint256 gaPrice = uint96(_bound(_random(), 0, type(uint96).max));
        vm.prank(c.platform);
        sm.setGAPrice(uint96(gaPrice));

        uint32 quantity = uint32(_bound(_random(), 1, type(uint32).max));
        uint96 signedPrice = uint96(_bound(_random(), 1, type(uint96).max));
        ISuperMinterE.TotalPriceAndFees memory tpaf;
        if (c.mode == sm.VERIFY_SIGNATURE() && signedPrice < c.price) {
            vm.expectRevert(ISuperMinterE.SignedPriceTooLow.selector);
            tpaf = sm.totalPriceAndFeesWithSignedPrice(address(edition), c.tier, 0, quantity, signedPrice, false);
            signedPrice = c.price;
        }
        tpaf = sm.totalPriceAndFeesWithSignedPrice(address(edition), c.tier, 0, quantity, signedPrice, false);
        if (c.mode == sm.VERIFY_SIGNATURE()) {
            assertEq(tpaf.unitPrice, signedPrice);
        } else if (c.tier == 0) {
            assertEq(tpaf.unitPrice, gaPrice);
        } else {
            assertEq(tpaf.unitPrice, c.price);
        }

        ISuperMinterE.MintInfo memory info = sm.mintInfo(address(edition), c.tier, 0);
        if (c.tier == 0) {
            assertEq(info.price, c.mode == sm.VERIFY_SIGNATURE() ? c.price : gaPrice);
        } else {
            assertEq(info.price, c.price);
        }
    }

    function test_mintWithVariousFees(uint256) public {
        SuperMinterEConstants memory smc = _superMinterConstants();
        address[] memory feeRecipients = _twoRandomUniqueAddresses();

        // Create a tier 1 mint schedule, without any affiliate root.
        ISuperMinterE.MintCreation memory c;
        {
            c.maxMintable = type(uint32).max;
            c.platform = _randomNonZeroAddress();
            c.edition = address(edition);
            c.tier = 1;
            c.price = uint96(_bound(_random(), 0, type(uint96).max));
            c.affiliateFeeBPS = uint16(_bound(_random(), 0, smc.MAX_AFFILIATE_FEE_BPS));
            c.startTime = 0;
            c.endTime = uint32(block.timestamp + 1000);
            c.maxMintablePerAccount = type(uint32).max;
            assertEq(sm.createEditionMint(c), 0);
        }

        // Set the tier 1 platform fee config.
        ISuperMinterE.PlatformFeeConfig memory pfc;
        {
            pfc.platformTxFlatFee = uint96(_bound(_random(), 0, smc.MAX_PLATFORM_PER_TX_FLAT_FEE));
            pfc.platformMintFeeBPS = uint16(_bound(_random(), 0, smc.MAX_PLATFORM_PER_MINT_FEE_BPS));

            pfc.artistMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.affiliateMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.platformMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));

            pfc.thresholdPrice = uint96(_bound(_random(), 0, type(uint96).max));

            pfc.thresholdArtistMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.thresholdAffiliateMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.thresholdPlatformMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));

            pfc.active = true;
            vm.prank(c.platform);
            sm.setPlatformFeeConfig(1, pfc);
        }

        // Prepare the MintTo struct witha a random quantity.
        ISuperMinterE.MintTo memory p;
        {
            p.edition = address(edition);
            p.tier = 1;
            p.scheduleNum = 0;
            p.to = address(this);
            p.quantity = uint32(_bound(_random(), 0, type(uint32).max));
        }

        // Just to ensure we have enough ETH to mint.
        vm.deal(address(this), type(uint192).max);

        ISuperMinterE.MintedLogData memory l;
        ISuperMinterE.TotalPriceAndFees memory tpaf;
        {
            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, _random() % 2 == 0);
            assertEq(tpaf.subTotal, c.price * uint256(p.quantity));
            assertGt(tpaf.total + 1, tpaf.subTotal);

            // Use a lower, non-zero quantity for mint testing.
            p.quantity = uint32(_bound(_random(), 1, 8));
            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, _random() % 2 == 0);
            assertEq(tpaf.subTotal, c.price * uint256(p.quantity));
            assertGt(tpaf.total + 1, tpaf.subTotal);
        }

        // Test the affiliated path.
        if (_random() % 2 == 0) {
            p.affiliate = _randomNonZeroAddress();

            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, true);

            vm.expectEmit(true, true, true, true);

            l.quantity = p.quantity;
            l.fromTokenId = 1;
            l.affiliate = p.affiliate;
            l.affiliated = true;
            l.requiredPayment = tpaf.total;
            l.unitPrice = tpaf.unitPrice;
            l.finalArtistFee = tpaf.finalArtistFee;
            l.finalAffiliateFee = tpaf.finalAffiliateFee;
            l.finalPlatformFee = tpaf.finalPlatformFee;

            emit Minted(address(edition), c.tier, 0, address(this), l, 0);
        } else {
            p.affiliate = address(0);

            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, false);

            vm.expectEmit(true, true, true, true);

            l.quantity = p.quantity;
            l.fromTokenId = 1;
            l.affiliate = address(0);
            l.affiliated = false;
            l.requiredPayment = tpaf.total;
            l.unitPrice = tpaf.unitPrice;
            l.finalArtistFee = tpaf.finalArtistFee;
            l.finalAffiliateFee = 0;
            l.finalPlatformFee = tpaf.finalPlatformFee;

            emit Minted(address(edition), c.tier, 0, address(this), l, 0);
        }

        sm.mintTo{ value: tpaf.total }(p);

        // Check invariants.
        assertEq(l.finalPlatformFee + l.finalAffiliateFee + l.finalArtistFee, tpaf.total);
        assertEq(sm.platformFeesAccrued(c.platform), l.finalPlatformFee);
        assertEq(sm.affiliateFeesAccrued(p.affiliate), l.finalAffiliateFee);
        assertEq(address(sm).balance, l.finalPlatformFee + l.finalAffiliateFee);
        assertEq(address(edition).balance, l.finalArtistFee);

        // Perform the withdrawals for affiliate and check if the balances tally.
        uint256 balanceBefore = address(p.affiliate).balance;
        sm.withdrawForAffiliate(p.affiliate);
        assertEq(address(p.affiliate).balance, balanceBefore + l.finalAffiliateFee);

        // Perform the withdrawals for platform and check if the balances tally.
        balanceBefore = address(feeRecipients[0]).balance;
        vm.prank(c.platform);
        sm.setPlatformFeeAddress(feeRecipients[0]);
        assertEq(sm.platformFeeAddress(c.platform), feeRecipients[0]);
        sm.withdrawForPlatform(c.platform);
        assertEq(address(feeRecipients[0]).balance, balanceBefore + l.finalPlatformFee);
        assertEq(sm.platformFeeAddress(c.platform), feeRecipients[0]);
        assertEq(address(sm).balance, 0);
    }

    function test_mintWithVariousERC20Fees(uint256) public {
        SuperMinterEConstants memory smc = _superMinterConstants();
        address[] memory feeRecipients = _twoRandomUniqueAddresses();

        // Create a tier 1 mint schedule, without any affiliate root.
        ISuperMinterE.MintCreation memory c;
        {
            c.maxMintable = type(uint32).max;
            c.platform = _randomNonZeroAddress();
            c.edition = address(edition);
            c.tier = 1;
            c.price = uint96(_bound(_random(), 0, type(uint96).max));
            c.affiliateFeeBPS = uint16(_bound(_random(), 0, smc.MAX_AFFILIATE_FEE_BPS));
            c.startTime = 0;
            c.endTime = uint32(block.timestamp + 1000);
            c.maxMintablePerAccount = type(uint32).max;
            c.erc20 = address(weth);
            assertEq(sm.createEditionMint(c), 0);
        }

        // Set the tier 1 platform fee config.
        ISuperMinterE.PlatformFeeConfig memory pfc;
        {
            pfc.platformTxFlatFee = uint96(_bound(_random(), 0, smc.MAX_PLATFORM_PER_TX_FLAT_FEE));
            pfc.platformMintFeeBPS = uint16(_bound(_random(), 0, smc.MAX_PLATFORM_PER_MINT_FEE_BPS));

            pfc.artistMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.affiliateMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.platformMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));

            pfc.thresholdPrice = uint96(_bound(_random(), 0, type(uint96).max));

            pfc.thresholdArtistMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.thresholdAffiliateMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));
            pfc.thresholdPlatformMintReward = uint96(_bound(_random(), 0, smc.MAX_PER_MINT_REWARD));

            pfc.active = true;
            vm.prank(c.platform);
            sm.setPlatformFeeConfig(1, pfc);
        }

        // Prepare the MintTo struct witha a random quantity.
        ISuperMinterE.MintTo memory p;
        {
            p.edition = address(edition);
            p.tier = 1;
            p.scheduleNum = 0;
            p.to = address(this);
            p.quantity = uint32(_bound(_random(), 0, type(uint32).max));
        }

        // Just to ensure we have enough ETH to mint.
        vm.deal(address(this), type(uint192).max);
        weth.deposit{ value: type(uint192).max }();
        assertEq(weth.balanceOf(address(this)), type(uint192).max);
        weth.approve(address(sm), type(uint256).max);

        ISuperMinterE.MintedLogData memory l;
        ISuperMinterE.TotalPriceAndFees memory tpaf;
        {
            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, _random() % 2 == 0);
            assertEq(tpaf.subTotal, c.price * uint256(p.quantity));
            assertGt(tpaf.total + 1, tpaf.subTotal);

            // Use a lower, non-zero quantity for mint testing.
            p.quantity = uint32(_bound(_random(), 1, 8));
            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, _random() % 2 == 0);
            assertEq(tpaf.subTotal, c.price * uint256(p.quantity));
            assertGt(tpaf.total + 1, tpaf.subTotal);
        }

        // Test the affiliated path.
        if (_random() % 2 == 0) {
            p.affiliate = _randomNonZeroAddress();

            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, true);

            vm.expectEmit(true, true, true, true);

            l.quantity = p.quantity;
            l.fromTokenId = 1;
            l.affiliate = p.affiliate;
            l.affiliated = true;
            l.requiredPayment = tpaf.total;
            l.unitPrice = tpaf.unitPrice;
            l.finalArtistFee = tpaf.finalArtistFee;
            l.finalAffiliateFee = tpaf.finalAffiliateFee;
            l.finalPlatformFee = tpaf.finalPlatformFee;
            l.erc20 = address(weth);

            emit Minted(address(edition), c.tier, 0, address(this), l, 0);
        } else {
            p.affiliate = address(0);

            tpaf = sm.totalPriceAndFees(address(edition), c.tier, 0, p.quantity, false);

            vm.expectEmit(true, true, true, true);

            l.quantity = p.quantity;
            l.fromTokenId = 1;
            l.affiliate = address(0);
            l.affiliated = false;
            l.requiredPayment = tpaf.total;
            l.unitPrice = tpaf.unitPrice;
            l.finalArtistFee = tpaf.finalArtistFee;
            l.finalAffiliateFee = 0;
            l.finalPlatformFee = tpaf.finalPlatformFee;
            l.erc20 = address(weth);

            emit Minted(address(edition), c.tier, 0, address(this), l, 0);
        }

        sm.mintTo(p);

        // Check invariants.
        assertEq(l.finalPlatformFee + l.finalAffiliateFee + l.finalArtistFee, tpaf.total);
        assertEq(sm.platformERC20FeesAccrued(c.platform, address(weth)), l.finalPlatformFee);
        assertEq(sm.affiliateERC20FeesAccrued(p.affiliate, address(weth)), l.finalAffiliateFee);
        assertEq(weth.balanceOf(address(sm)), l.finalPlatformFee + l.finalAffiliateFee);
        assertEq(weth.balanceOf(address(edition)), l.finalArtistFee);

        // Perform the withdrawals for affiliate and check if the balances tally.
        uint256 balanceBefore = address(p.affiliate).balance;
        sm.withdrawERC20ForAffiliate(p.affiliate, address(weth));
        assertEq(weth.balanceOf(address(p.affiliate)), balanceBefore + l.finalAffiliateFee);

        // Perform the withdrawals for platform and check if the balances tally.
        balanceBefore = weth.balanceOf(address(feeRecipients[0]));
        vm.prank(c.platform);
        sm.setPlatformFeeAddress(feeRecipients[0]);
        assertEq(sm.platformFeeAddress(c.platform), feeRecipients[0]);
        sm.withdrawERC20ForPlatform(c.platform, address(weth));
        assertEq(weth.balanceOf(address(feeRecipients[0])), balanceBefore + l.finalPlatformFee);
        assertEq(sm.platformFeeAddress(c.platform), feeRecipients[0]);
        assertEq(weth.balanceOf(address(sm)), 0);
    }

    function test_mintWithSignature(uint256) public {
        (address signer, uint256 privateKey) = _randomSigner();
        ISuperMinterE.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = _randomNonZeroAddress();
        c.edition = address(edition);
        c.tier = uint8(_random() % 2);
        c.startTime = 0;
        c.mode = sm.VERIFY_SIGNATURE();
        c.endTime = uint32(block.timestamp + 1000);
        c.maxMintablePerAccount = type(uint32).max;
        vm.prank(c.platform);
        sm.setPlatformSigner(signer);
        assertEq(sm.createEditionMint(c), 0);

        ISuperMinterE.MintTo memory p;
        p.edition = address(edition);
        p.tier = c.tier;
        p.scheduleNum = 0;
        p.to = _randomNonZeroAddress();
        p.quantity = uint32(_bound(_random(), 1, 16));
        p.signedPrice = uint96(_bound(_random(), 0, type(uint96).max));
        p.signedQuantity = uint32(p.quantity + (_random() % 16));
        p.signedClaimTicket = uint32(_bound(_random(), 0, type(uint32).max));
        p.signedDeadline = type(uint32).max;
        p.affiliate = _randomNonZeroAddress();
        while (p.affiliate == p.to) p.affiliate = _randomNonZeroAddress();
        p.signature = _generateSignature(p, privateKey);

        vm.deal(address(this), type(uint192).max);

        sm.mintTo{ value: uint256(p.quantity) * uint256(p.signedPrice) }(p);

        vm.expectRevert(ISuperMinterE.SignatureAlreadyUsed.selector);
        sm.mintTo{ value: uint256(p.quantity) * uint256(p.signedPrice) }(p);

        assertEq(edition.balanceOf(p.to), p.quantity);

        p.signedClaimTicket = uint32(p.signedClaimTicket ^ 1);
        vm.expectRevert(ISuperMinterE.InvalidSignature.selector);
        sm.mintTo{ value: uint256(p.quantity) * uint256(p.signedPrice) }(p);

        uint32 originalQuantity = p.quantity;
        p.quantity = uint32(p.signedQuantity + _bound(_random(), 1, 10));
        p.signature = _generateSignature(p, privateKey);
        vm.expectRevert(ISuperMinterE.ExceedsSignedQuantity.selector);
        sm.mintTo{ value: uint256(p.quantity) * uint256(p.signedPrice) }(p);
        p.quantity = originalQuantity;

        p.signature = _generateSignature(p, privateKey);
        sm.mintTo{ value: uint256(p.quantity) * uint256(p.signedPrice) }(p);

        assertEq(edition.balanceOf(p.to), p.quantity * 2);
    }

    function _generateSignature(ISuperMinterE.MintTo memory p, uint256 privateKey)
        internal
        returns (bytes memory signature)
    {
        bytes32 digest = sm.computeMintToDigest(p);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _generatePlatformAirdropSignature(ISuperMinterE.PlatformAirdrop memory p, uint256 privateKey)
        internal
        returns (bytes memory signature)
    {
        bytes32 digest = sm.computePlatformAirdropDigest(p);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function test_mintGA(uint256) public {
        ISuperMinterE.MintCreation memory c;
        c.maxMintable = type(uint32).max;
        c.platform = _randomNonZeroAddress();
        c.edition = address(edition);
        c.tier = 0;
        c.startTime = 0;
        c.mode = sm.DEFAULT();
        c.endTime = uint32(block.timestamp + 1000);
        c.maxMintablePerAccount = type(uint32).max;
        assertEq(sm.createEditionMint(c), 0);

        uint256 gaPrice = uint96(_bound(_random(), 0, type(uint96).max));
        vm.prank(c.platform);
        sm.setGAPrice(uint96(gaPrice));

        ISuperMinterE.MintTo memory p;
        p.edition = address(edition);
        p.tier = 0;
        p.scheduleNum = 0;
        p.to = _randomNonZeroAddress();
        p.quantity = uint32(_bound(_random(), 1, 16));

        vm.deal(address(this), type(uint192).max);
        sm.mintTo{ value: uint256(p.quantity) * uint256(gaPrice) }(p);
    }
}
