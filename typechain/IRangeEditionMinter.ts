/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PayableOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "./common";

export interface IRangeEditionMinterInterface extends utils.Interface {
  functions: {
    "affiliateFeesAccrued(address)": FunctionFragment;
    "createEditionMint(address,uint96,uint32,uint32,uint32,uint32,uint32,uint32)": FunctionFragment;
    "isAffiliated(address,uint256,address)": FunctionFragment;
    "mint(address,uint256,uint32,address)": FunctionFragment;
    "moduleInterfaceId()": FunctionFragment;
    "nextMintId()": FunctionFragment;
    "platformFeesAccrued()": FunctionFragment;
    "setAffiliateDiscount(address,uint256,uint16)": FunctionFragment;
    "setAffiliateFee(address,uint256,uint16)": FunctionFragment;
    "setEditionMintPaused(address,uint256,bool)": FunctionFragment;
    "setMaxMintableRange(address,uint256,uint32,uint32)": FunctionFragment;
    "setTimeRange(address,uint256,uint32,uint32)": FunctionFragment;
    "setTimeRange(address,uint256,uint32,uint32,uint32)": FunctionFragment;
    "supportsInterface(bytes4)": FunctionFragment;
    "totalPrice(address,uint256,address,uint32,bool)": FunctionFragment;
    "withdrawForAffiliate(address)": FunctionFragment;
    "withdrawForPlatform()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "affiliateFeesAccrued"
      | "createEditionMint"
      | "isAffiliated"
      | "mint"
      | "moduleInterfaceId"
      | "nextMintId"
      | "platformFeesAccrued"
      | "setAffiliateDiscount"
      | "setAffiliateFee"
      | "setEditionMintPaused"
      | "setMaxMintableRange"
      | "setTimeRange(address,uint256,uint32,uint32)"
      | "setTimeRange(address,uint256,uint32,uint32,uint32)"
      | "supportsInterface"
      | "totalPrice"
      | "withdrawForAffiliate"
      | "withdrawForPlatform"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "affiliateFeesAccrued",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "createEditionMint",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "isAffiliated",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "mint",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "moduleInterfaceId",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "nextMintId",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "platformFeesAccrued",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "setAffiliateDiscount",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "setAffiliateFee",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "setEditionMintPaused",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<boolean>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "setMaxMintableRange",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "setTimeRange(address,uint256,uint32,uint32)",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "setTimeRange(address,uint256,uint32,uint32,uint32)",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "supportsInterface",
    values: [PromiseOrValue<BytesLike>]
  ): string;
  encodeFunctionData(
    functionFragment: "totalPrice",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<boolean>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "withdrawForAffiliate",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "withdrawForPlatform",
    values?: undefined
  ): string;

  decodeFunctionResult(
    functionFragment: "affiliateFeesAccrued",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "createEditionMint",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "isAffiliated",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "mint", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "moduleInterfaceId",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "nextMintId", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "platformFeesAccrued",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setAffiliateDiscount",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setAffiliateFee",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setEditionMintPaused",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setMaxMintableRange",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setTimeRange(address,uint256,uint32,uint32)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setTimeRange(address,uint256,uint32,uint32,uint32)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "supportsInterface",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "totalPrice", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "withdrawForAffiliate",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "withdrawForPlatform",
    data: BytesLike
  ): Result;

  events: {
    "AffiliateDiscountSet(address,uint256,uint16)": EventFragment;
    "AffiliateFeeSet(address,uint256,uint16)": EventFragment;
    "ClosingTimeSet(address,uint256,uint32)": EventFragment;
    "MaxMintableRangeSet(address,uint256,uint32,uint32)": EventFragment;
    "MintConfigCreated(address,address,uint256,uint32,uint32)": EventFragment;
    "MintPausedSet(address,uint256,bool)": EventFragment;
    "RangeEditionMintCreated(address,uint256,uint96,uint32,uint32,uint32,uint32,uint32,uint32)": EventFragment;
    "TimeRangeSet(address,uint256,uint32,uint32)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "AffiliateDiscountSet"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "AffiliateFeeSet"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ClosingTimeSet"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "MaxMintableRangeSet"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "MintConfigCreated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "MintPausedSet"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RangeEditionMintCreated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "TimeRangeSet"): EventFragment;
}

export interface AffiliateDiscountSetEventObject {
  edition: string;
  mintId: BigNumber;
  discountBPS: number;
}
export type AffiliateDiscountSetEvent = TypedEvent<
  [string, BigNumber, number],
  AffiliateDiscountSetEventObject
>;

export type AffiliateDiscountSetEventFilter =
  TypedEventFilter<AffiliateDiscountSetEvent>;

export interface AffiliateFeeSetEventObject {
  edition: string;
  mintId: BigNumber;
  feeBPS: number;
}
export type AffiliateFeeSetEvent = TypedEvent<
  [string, BigNumber, number],
  AffiliateFeeSetEventObject
>;

export type AffiliateFeeSetEventFilter = TypedEventFilter<AffiliateFeeSetEvent>;

export interface ClosingTimeSetEventObject {
  edition: string;
  mintId: BigNumber;
  closingTime: number;
}
export type ClosingTimeSetEvent = TypedEvent<
  [string, BigNumber, number],
  ClosingTimeSetEventObject
>;

export type ClosingTimeSetEventFilter = TypedEventFilter<ClosingTimeSetEvent>;

export interface MaxMintableRangeSetEventObject {
  edition: string;
  mintId: BigNumber;
  maxMintableLower: number;
  maxMintableUpper: number;
}
export type MaxMintableRangeSetEvent = TypedEvent<
  [string, BigNumber, number, number],
  MaxMintableRangeSetEventObject
>;

export type MaxMintableRangeSetEventFilter =
  TypedEventFilter<MaxMintableRangeSetEvent>;

export interface MintConfigCreatedEventObject {
  edition: string;
  creator: string;
  mintId: BigNumber;
  startTime: number;
  endTime: number;
}
export type MintConfigCreatedEvent = TypedEvent<
  [string, string, BigNumber, number, number],
  MintConfigCreatedEventObject
>;

export type MintConfigCreatedEventFilter =
  TypedEventFilter<MintConfigCreatedEvent>;

export interface MintPausedSetEventObject {
  edition: string;
  mintId: BigNumber;
  paused: boolean;
}
export type MintPausedSetEvent = TypedEvent<
  [string, BigNumber, boolean],
  MintPausedSetEventObject
>;

export type MintPausedSetEventFilter = TypedEventFilter<MintPausedSetEvent>;

export interface RangeEditionMintCreatedEventObject {
  edition: string;
  mintId: BigNumber;
  price: BigNumber;
  startTime: number;
  closingTime: number;
  endTime: number;
  maxMintableLower: number;
  maxMintableUpper: number;
  maxMintablePerAccount: number;
}
export type RangeEditionMintCreatedEvent = TypedEvent<
  [
    string,
    BigNumber,
    BigNumber,
    number,
    number,
    number,
    number,
    number,
    number
  ],
  RangeEditionMintCreatedEventObject
>;

export type RangeEditionMintCreatedEventFilter =
  TypedEventFilter<RangeEditionMintCreatedEvent>;

export interface TimeRangeSetEventObject {
  edition: string;
  mintId: BigNumber;
  startTime: number;
  endTime: number;
}
export type TimeRangeSetEvent = TypedEvent<
  [string, BigNumber, number, number],
  TimeRangeSetEventObject
>;

export type TimeRangeSetEventFilter = TypedEventFilter<TimeRangeSetEvent>;

export interface IRangeEditionMinter extends BaseContract {
  contractName: "IRangeEditionMinter";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IRangeEditionMinterInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    affiliateFeesAccrued(
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    createEditionMint(
      edition: PromiseOrValue<string>,
      price: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      maxMintablePerAccount_: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    isAffiliated(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    mint(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    moduleInterfaceId(overrides?: CallOverrides): Promise<[string]>;

    nextMintId(overrides?: CallOverrides): Promise<[BigNumber]>;

    platformFeesAccrued(overrides?: CallOverrides): Promise<[BigNumber]>;

    setAffiliateDiscount(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateDiscountBPS: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    setAffiliateFee(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateFeeBPS: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    setEditionMintPaused(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      paused: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    setMaxMintableRange(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "setTimeRange(address,uint256,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "setTimeRange(address,uint256,uint32,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    supportsInterface(
      interfaceId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    totalPrice(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      minter: PromiseOrValue<string>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliated: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    withdrawForAffiliate(
      affiliate: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    withdrawForPlatform(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;
  };

  affiliateFeesAccrued(
    affiliate: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  createEditionMint(
    edition: PromiseOrValue<string>,
    price: PromiseOrValue<BigNumberish>,
    startTime: PromiseOrValue<BigNumberish>,
    closingTime: PromiseOrValue<BigNumberish>,
    endTime: PromiseOrValue<BigNumberish>,
    maxMintableLower: PromiseOrValue<BigNumberish>,
    maxMintableUpper: PromiseOrValue<BigNumberish>,
    maxMintablePerAccount_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  isAffiliated(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    affiliate: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  mint(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    quantity: PromiseOrValue<BigNumberish>,
    affiliate: PromiseOrValue<string>,
    overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  moduleInterfaceId(overrides?: CallOverrides): Promise<string>;

  nextMintId(overrides?: CallOverrides): Promise<BigNumber>;

  platformFeesAccrued(overrides?: CallOverrides): Promise<BigNumber>;

  setAffiliateDiscount(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    affiliateDiscountBPS: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  setAffiliateFee(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    affiliateFeeBPS: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  setEditionMintPaused(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    paused: PromiseOrValue<boolean>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  setMaxMintableRange(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    maxMintableLower: PromiseOrValue<BigNumberish>,
    maxMintableUpper: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "setTimeRange(address,uint256,uint32,uint32)"(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    startTime: PromiseOrValue<BigNumberish>,
    endTime: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "setTimeRange(address,uint256,uint32,uint32,uint32)"(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    startTime: PromiseOrValue<BigNumberish>,
    closingTime: PromiseOrValue<BigNumberish>,
    endTime: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  supportsInterface(
    interfaceId: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  totalPrice(
    edition: PromiseOrValue<string>,
    mintId: PromiseOrValue<BigNumberish>,
    minter: PromiseOrValue<string>,
    quantity: PromiseOrValue<BigNumberish>,
    affiliated: PromiseOrValue<boolean>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  withdrawForAffiliate(
    affiliate: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  withdrawForPlatform(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    affiliateFeesAccrued(
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    createEditionMint(
      edition: PromiseOrValue<string>,
      price: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      maxMintablePerAccount_: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    isAffiliated(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    mint(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    moduleInterfaceId(overrides?: CallOverrides): Promise<string>;

    nextMintId(overrides?: CallOverrides): Promise<BigNumber>;

    platformFeesAccrued(overrides?: CallOverrides): Promise<BigNumber>;

    setAffiliateDiscount(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateDiscountBPS: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    setAffiliateFee(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateFeeBPS: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    setEditionMintPaused(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      paused: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<void>;

    setMaxMintableRange(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    "setTimeRange(address,uint256,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    "setTimeRange(address,uint256,uint32,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    supportsInterface(
      interfaceId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    totalPrice(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      minter: PromiseOrValue<string>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliated: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    withdrawForAffiliate(
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    withdrawForPlatform(overrides?: CallOverrides): Promise<void>;
  };

  filters: {
    "AffiliateDiscountSet(address,uint256,uint16)"(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      discountBPS?: null
    ): AffiliateDiscountSetEventFilter;
    AffiliateDiscountSet(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      discountBPS?: null
    ): AffiliateDiscountSetEventFilter;

    "AffiliateFeeSet(address,uint256,uint16)"(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      feeBPS?: null
    ): AffiliateFeeSetEventFilter;
    AffiliateFeeSet(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      feeBPS?: null
    ): AffiliateFeeSetEventFilter;

    "ClosingTimeSet(address,uint256,uint32)"(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      closingTime?: null
    ): ClosingTimeSetEventFilter;
    ClosingTimeSet(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      closingTime?: null
    ): ClosingTimeSetEventFilter;

    "MaxMintableRangeSet(address,uint256,uint32,uint32)"(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      maxMintableLower?: null,
      maxMintableUpper?: null
    ): MaxMintableRangeSetEventFilter;
    MaxMintableRangeSet(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      maxMintableLower?: null,
      maxMintableUpper?: null
    ): MaxMintableRangeSetEventFilter;

    "MintConfigCreated(address,address,uint256,uint32,uint32)"(
      edition?: PromiseOrValue<string> | null,
      creator?: PromiseOrValue<string> | null,
      mintId?: null,
      startTime?: null,
      endTime?: null
    ): MintConfigCreatedEventFilter;
    MintConfigCreated(
      edition?: PromiseOrValue<string> | null,
      creator?: PromiseOrValue<string> | null,
      mintId?: null,
      startTime?: null,
      endTime?: null
    ): MintConfigCreatedEventFilter;

    "MintPausedSet(address,uint256,bool)"(
      edition?: PromiseOrValue<string> | null,
      mintId?: null,
      paused?: null
    ): MintPausedSetEventFilter;
    MintPausedSet(
      edition?: PromiseOrValue<string> | null,
      mintId?: null,
      paused?: null
    ): MintPausedSetEventFilter;

    "RangeEditionMintCreated(address,uint256,uint96,uint32,uint32,uint32,uint32,uint32,uint32)"(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      price?: null,
      startTime?: null,
      closingTime?: null,
      endTime?: null,
      maxMintableLower?: null,
      maxMintableUpper?: null,
      maxMintablePerAccount?: null
    ): RangeEditionMintCreatedEventFilter;
    RangeEditionMintCreated(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      price?: null,
      startTime?: null,
      closingTime?: null,
      endTime?: null,
      maxMintableLower?: null,
      maxMintableUpper?: null,
      maxMintablePerAccount?: null
    ): RangeEditionMintCreatedEventFilter;

    "TimeRangeSet(address,uint256,uint32,uint32)"(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      startTime?: null,
      endTime?: null
    ): TimeRangeSetEventFilter;
    TimeRangeSet(
      edition?: PromiseOrValue<string> | null,
      mintId?: PromiseOrValue<BigNumberish> | null,
      startTime?: null,
      endTime?: null
    ): TimeRangeSetEventFilter;
  };

  estimateGas: {
    affiliateFeesAccrued(
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    createEditionMint(
      edition: PromiseOrValue<string>,
      price: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      maxMintablePerAccount_: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    isAffiliated(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    mint(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    moduleInterfaceId(overrides?: CallOverrides): Promise<BigNumber>;

    nextMintId(overrides?: CallOverrides): Promise<BigNumber>;

    platformFeesAccrued(overrides?: CallOverrides): Promise<BigNumber>;

    setAffiliateDiscount(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateDiscountBPS: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    setAffiliateFee(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateFeeBPS: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    setEditionMintPaused(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      paused: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    setMaxMintableRange(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "setTimeRange(address,uint256,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "setTimeRange(address,uint256,uint32,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    supportsInterface(
      interfaceId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    totalPrice(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      minter: PromiseOrValue<string>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliated: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    withdrawForAffiliate(
      affiliate: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    withdrawForPlatform(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    affiliateFeesAccrued(
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    createEditionMint(
      edition: PromiseOrValue<string>,
      price: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      maxMintablePerAccount_: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    isAffiliated(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    mint(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliate: PromiseOrValue<string>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    moduleInterfaceId(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    nextMintId(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    platformFeesAccrued(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    setAffiliateDiscount(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateDiscountBPS: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    setAffiliateFee(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      affiliateFeeBPS: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    setEditionMintPaused(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      paused: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    setMaxMintableRange(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      maxMintableLower: PromiseOrValue<BigNumberish>,
      maxMintableUpper: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "setTimeRange(address,uint256,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "setTimeRange(address,uint256,uint32,uint32,uint32)"(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      startTime: PromiseOrValue<BigNumberish>,
      closingTime: PromiseOrValue<BigNumberish>,
      endTime: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    supportsInterface(
      interfaceId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    totalPrice(
      edition: PromiseOrValue<string>,
      mintId: PromiseOrValue<BigNumberish>,
      minter: PromiseOrValue<string>,
      quantity: PromiseOrValue<BigNumberish>,
      affiliated: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    withdrawForAffiliate(
      affiliate: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    withdrawForPlatform(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;
  };
}
