// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract InvariantTest {
    address[] private targets;

    function targetContracts() public view virtual returns (address[] memory) {
        require(targets.length > 0, "NO_TARGET_CONTRACTS");

        return targets;
    }

    function addTargetContract(address newTargetContract) internal virtual {
        targets.push(newTargetContract);
    }
}
