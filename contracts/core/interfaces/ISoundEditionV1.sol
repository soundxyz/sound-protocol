// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { IERC165Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC165Upgradeable.sol";
import { ISoundEditionActions } from "./edition/ISoundEditionActions.sol";
import { ISoundEditionImmutables } from "./edition/ISoundEditionImmutables.sol";
import { ISoundEditionEventsAndErrors } from "./edition/ISoundEditionEventsAndErrors.sol";
import { ISoundEditionOwnerActions } from "./edition/ISoundEditionOwnerActions.sol";
import { ISoundEditionState } from "./edition/ISoundEditionState.sol";
import { IMetadataModule } from "./IMetadataModule.sol";

/**
 * @title ISoundEditionV1
 * @author Sound.xyz
 */
interface ISoundEditionV1 is
    IERC721AUpgradeable,
    IERC2981Upgradeable,
    ISoundEditionActions,
    ISoundEditionImmutables,
    ISoundEditionEventsAndErrors,
    ISoundEditionOwnerActions,
    ISoundEditionState
{
    /**
     * @dev Informs other contracts which interfaces this contract supports.
     * https://eips.ethereum.org/EIPS/eip-165
     * @param interfaceId The interface id to check.
     */
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override(IERC721AUpgradeable, IERC165Upgradeable)
        returns (bool);
}
