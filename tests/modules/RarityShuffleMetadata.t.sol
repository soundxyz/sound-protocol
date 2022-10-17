// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import { RarityShuffleMetadata } from "@modules/RarityShuffleMetadata.sol";

error LogError(uint256, uint256, uint256, uint256);

contract RarityShuffleMetadataTests is Test{
  
  mapping (uint256 => bool) usedOffset;
  

  RarityShuffleMetadata module;
  
    address contractCreator;
    function setUp() public {

        contractCreator = vm.addr(1);

        uint256[] memory _ranges = new uint256[](6);
        _ranges[0] = 0;
        _ranges[1] = 10;
        _ranges[2] = 25;
        _ranges[3] = 50;
        _ranges[4] = 80;
        _ranges[5] = 95;

        module = new RarityShuffleMetadata(
          contractCreator,
          100,
          6,
          _ranges
        );


        console2.log("Set up!");
    }
    
    function test_triggerMetadata() public {
      vm.startPrank(contractCreator);
      
      module.triggerMetadata(100);
      
      for (uint256 index = 0; index < 10; index++) {
        uint256 offset = module.offsets(index);
        assertFalse(usedOffset[offset]);
        assertTrue(offset < 100);
        
        usedOffset[offset] = true;

        uint256 shuffleId = module.getShuffledTokenId(index);
        assertTrue(shuffleId <= 6);
        
        if (offset < 10) expectEqual(shuffleId, 1, offset, index);
        else if (offset < 25) expectEqual(shuffleId, 2, offset, index);
        else if (offset < 50) expectEqual(shuffleId, 3, offset, index);
        else if (offset < 80) expectEqual(shuffleId, 4, offset, index);
        else if (offset < 95) expectEqual(shuffleId, 5, offset, index);
        else expectEqual(shuffleId, 6, offset, index);
      }
      
      vm.stopPrank();
    }
    
    function expectEqual(uint256 a, uint256 b, uint256 c, uint256 d) internal{
      // revert LogError(a, b, c, d);
      if (a != b) revert LogError(a, b, c, d);
    }

    function testExample() public {
        vm.startPrank(address(0xB0B));
        console2.log("Hello world!");
        assertTrue(true);
    }

}
