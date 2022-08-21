// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

interface ISoundEditionState {
    /// @dev Returns the base token URI for the collection
    function baseURI() external view returns (string memory);

    /// @dev Returns the total amount of tokens minted in the contract
    function totalMinted() external view returns (uint256);

    function randomnessLockedAfterMinted() external view returns (uint32);

    function randomnessLockedTimestamp() external view returns (uint32);

    function mintRandomness() external view returns (bytes32);

    function getMembersOfRole(bytes32 role) external view returns (address[] memory);
}
