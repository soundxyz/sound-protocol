// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ISoundMinterEventsAndErrors } from "./minter/ISoundMinterEventsAndErrors.sol";
import { ISoundMinterOwnerActions } from "./minter/ISoundMinterOwnerActions.sol";
import { ISoundMinterState } from "./minter/ISoundMinterState.sol";

/**
 * @title Interface for the base minter functionality, excluding the mint function.
 */
interface ISoundMinter is ISoundMinterEventsAndErrors, ISoundMinterOwnerActions, ISoundMinterState {

}
