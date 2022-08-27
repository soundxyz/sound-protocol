/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { BaseMinter, BaseMinterInterface } from "../BaseMinter";

const _abi = [
  {
    inputs: [],
    name: "FeeRegistryIsZeroAddress",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidAffiliateDiscountBPS",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidAffiliateFeeBPS",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidTimeRange",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint32",
        name: "maxMintable",
        type: "uint32",
      },
    ],
    name: "MaxMintableReached",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "blockTimestamp",
        type: "uint256",
      },
      {
        internalType: "uint32",
        name: "startTime",
        type: "uint32",
      },
      {
        internalType: "uint32",
        name: "endTime",
        type: "uint32",
      },
    ],
    name: "MintNotOpen",
    type: "error",
  },
  {
    inputs: [],
    name: "MintPaused",
    type: "error",
  },
  {
    inputs: [],
    name: "Unauthorized",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "paid",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "required",
        type: "uint256",
      },
    ],
    name: "WrongEtherValue",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "discountBPS",
        type: "uint16",
      },
    ],
    name: "AffiliateDiscountSet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "feeBPS",
        type: "uint16",
      },
    ],
    name: "AffiliateFeeSet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "creator",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint32",
        name: "startTime",
        type: "uint32",
      },
      {
        indexed: false,
        internalType: "uint32",
        name: "endTime",
        type: "uint32",
      },
    ],
    name: "MintConfigCreated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "paused",
        type: "bool",
      },
    ],
    name: "MintPausedSet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint32",
        name: "startTime",
        type: "uint32",
      },
      {
        indexed: false,
        internalType: "uint32",
        name: "endTime",
        type: "uint32",
      },
    ],
    name: "TimeRangeSet",
    type: "event",
  },
  {
    inputs: [],
    name: "MAX_BPS",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "affiliate",
        type: "address",
      },
    ],
    name: "affiliateFeesAccrued",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "feeRegistry",
    outputs: [
      {
        internalType: "contract ISoundFeeRegistry",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "affiliate",
        type: "address",
      },
    ],
    name: "isAffiliated",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "moduleInterfaceId",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "nextMintId",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "platformFeesAccrued",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        internalType: "uint16",
        name: "discountBPS",
        type: "uint16",
      },
    ],
    name: "setAffiliateDiscount",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        internalType: "uint16",
        name: "feeBPS",
        type: "uint16",
      },
    ],
    name: "setAffiliateFee",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        internalType: "bool",
        name: "paused",
        type: "bool",
      },
    ],
    name: "setEditionMintPaused",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        internalType: "uint32",
        name: "startTime",
        type: "uint32",
      },
      {
        internalType: "uint32",
        name: "endTime",
        type: "uint32",
      },
    ],
    name: "setTimeRange",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "edition",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "mintId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "minter",
        type: "address",
      },
      {
        internalType: "uint32",
        name: "quantity",
        type: "uint32",
      },
      {
        internalType: "bool",
        name: "affiliated",
        type: "bool",
      },
    ],
    name: "totalPrice",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "affiliate",
        type: "address",
      },
    ],
    name: "withdrawForAffiliate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "withdrawForPlatform",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

export class BaseMinter__factory {
  static readonly abi = _abi;
  static createInterface(): BaseMinterInterface {
    return new utils.Interface(_abi) as BaseMinterInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): BaseMinter {
    return new Contract(address, _abi, signerOrProvider) as BaseMinter;
  }
}
