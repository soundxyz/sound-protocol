// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import { RarityShuffleMetadata } from "@modules/RarityShuffleMetadata.sol";
import { IRarityShuffleMetadata } from "@modules/interfaces/IRarityShuffleMetadata.sol";

error LogError(uint256, uint256, uint256, uint256);
error USED(uint256 id, uint256 by, uint256 curr);

contract RarityShuffleMetadataTests is Test{
    struct Offset {
        bool used;
        uint256 by;
    }
  
  mapping (uint256 => Offset) usedOffset;

  RarityShuffleMetadata module;
  
    address contractCreator;
    address anyone;

    function setUp() public {

        contractCreator = vm.addr(1);
        anyone = vm.addr(2);

        uint256[] memory _ranges = new uint256[](6);
        _ranges[0] = 0;
        _ranges[1] = 10;
        _ranges[2] = 25;
        _ranges[3] = 50;
        _ranges[4] = 80;
        _ranges[5] = 95;

        module = new RarityShuffleMetadata(
          contractCreator,
          300,
          6,
          _ranges
        );
    }
    
    function test_setupFailsIfRangeOutOfOrder() public {
        uint256[] memory _ranges = new uint256[](6);
        _ranges[0] = 0;
        _ranges[1] = 25;
        _ranges[2] = 10;
        _ranges[3] = 50;
        _ranges[4] = 80;
        _ranges[5] = 95;

        vm.expectRevert(IRarityShuffleMetadata.RangeMustBeOrdered.selector);
        new RarityShuffleMetadata(
          contractCreator,
          100,
          6,
          _ranges
        );

    }
    
    function test_bst(uint256 offset) public {
        uint256 shuffleId = module.getShuffledTokenId(offset);
        assertTrue(shuffleId <= 6);
        
        if (offset < 10) assertEq(shuffleId, 1);
        else if (offset < 25) assertEq(shuffleId, 2);
        else if (offset < 50) assertEq(shuffleId, 3);
        else if (offset < 80) assertEq(shuffleId, 4);
        else if (offset < 95) assertEq(shuffleId, 5);
        else assertEq(shuffleId, 6);
    }
    
    function test_OnlyEditionCanTrigger() public {
      vm.startPrank(anyone);
      
      vm.expectRevert(IRarityShuffleMetadata.OnlyEditionCanTrigger.selector);
      module.triggerMetadata(100);
      
      vm.stopPrank();
    }
    
    function test_TriggerFailsIfExceedsEditionsAvailable() public {
      vm.startPrank(contractCreator);

      vm.expectRevert(IRarityShuffleMetadata.NoEditionsRemain.selector);
      module.triggerMetadata(301);
      
      vm.stopPrank();
      
    }
    
    function test_triggerMetadata() public {
      vm.startPrank(contractCreator);

      module.triggerMetadata(100);
      module.triggerMetadata(100);
      module.triggerMetadata(100);
      
      for (uint256 index = 0; index < 300; index++) {
        uint256 offset = module.offsets(index);
        // assertFalse(usedOffset[offset]);
          if (usedOffset[offset].used) revert USED(offset, usedOffset[offset].by, index);
        assertTrue(offset < 300);
        
          usedOffset[offset] = Offset(true, index);
        
        uint256 shuffleId = module.getShuffledTokenId(offset);
        assertTrue(shuffleId <= 6);
        
        if (offset < 10) assertEq(shuffleId, 1);
        else if (offset < 25) assertEq(shuffleId, 2);
        else if (offset < 50) assertEq(shuffleId, 3);
        else if (offset < 80) assertEq(shuffleId, 4);
        else if (offset < 95) assertEq(shuffleId, 5);
        else assertEq(shuffleId, 6);
      }
      
      vm.stopPrank();
    }
    
    function testExample() public {
        vm.startPrank(address(0xB0B));
        assertTrue(true);
    }

}
