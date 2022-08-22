// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModuleEventsAndErrors } from "./minter/IMinterModuleEventsAndErrors.sol";
import { IMinterModuleAdminActions } from "./minter/IMinterModuleAdminActions.sol";
import { IMinterModuleState } from "./minter/IMinterModuleState.sol";

/**
 * @title Interface for the base minter functionality, excluding the mint function.
 */
interface IMinterModule is IMinterModuleEventsAndErrors, IMinterModuleAdminActions, IMinterModuleState {

}
