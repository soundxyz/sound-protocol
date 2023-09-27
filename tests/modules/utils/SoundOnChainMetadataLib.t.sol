// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../TestPlus.sol";
import { SoundOnChainMetadataLib as M } from "../../../contracts/modules/utils/SoundOnChainMetadataLib.sol";
import { DynamicBufferLib } from "solady/utils/DynamicBufferLib.sol";
import { JSONParserLib } from "solady/utils/JSONParserLib.sol";
import { LibString } from "solady/utils/LibString.sol";

contract SoundOnChainMetadataLibTest is TestPlus {
    using JSONParserLib for JSONParserLib.Item;
    using DynamicBufferLib for DynamicBufferLib.DynamicBuffer;

    event LogString(string s);

    function getTemplate(string memory i) public pure returns (string memory) {
        if (LibString.eqs(i, "1")) return '{"x":[["x"]],"b":[["b"]],"s":"ONE"}';
        if (LibString.eqs(i, "2")) return '{"x":[["x"]],"b":[["b"]],"s":"TWO"}';
        if (LibString.eqs(i, "3")) return '{"x":[["x"]],"b":[["b"]],"s":"THREE"}';
        return '{"x":[["x"]],"s":"?"}';
    }

    function test_walk() public {
        string memory valuesString;

        valuesString = '{"base":{"template":"1","values":{"x":11,"b":"B"}},"7":{"template":"2","values":{"x":22}},"goldenEgg":{"template":"3","values":{"x":33}}}';
        DynamicBufferLib.DynamicBuffer memory buffer;
        M.walk(111, 222, 7, false, getTemplate, valuesString, buffer.clear());
        assertEq(string(buffer.data), '{"x":22,"b":"B","s":"TWO"}');
        M.walk(111, 222, 7, true, getTemplate, valuesString, buffer.clear());
        assertEq(string(buffer.data), '{"x":33,"b":"B","s":"THREE"}');

        valuesString = '{"base":{"template":"1","values":{"x":11,"b":"B"}},"7":{"template":"2","values":{"x":22}},"goldenEgg":{"template":"3"}}';
        M.walk(111, 222, 7, true, getTemplate, valuesString, buffer.clear());
        assertEq(string(buffer.data), '{"x":22,"b":"B","s":"THREE"}');

        valuesString = '{"base":{"template":"1","values":{"x":11,"b":"B"}},"7":{"template":"2","values":{"x":22},"goldenEgg":{"template":"3","values":{"x":888}}},"goldenEgg":{"template":"4","values":{"x":999}}}';
        M.walk(111, 222, 7, true, getTemplate, valuesString, buffer.clear());
        assertEq(string(buffer.data), '{"x":888,"b":"B","s":"THREE"}');
        M.walk(111, 222, 7, false, getTemplate, valuesString, buffer.clear());
        assertEq(string(buffer.data), '{"x":22,"b":"B","s":"TWO"}');
        M.walk(111, 222, 1, false, getTemplate, valuesString, buffer.clear());
        assertEq(string(buffer.data), '{"x":11,"b":"B","s":"ONE"}');
        M.walk(111, 222, 1, true, getTemplate, valuesString, buffer.clear());
        assertEq(string(buffer.data), '{"x":999,"s":"?"}');
    }

    function test_parseSoundMetadataJSON() public {
        string
            memory templateString = '{"animation_url":[["animationURI"]],"artist":[["artist"]],"artwork":{"mimeType":[["artworkMime"]],"uri":[["artworkURI"]],"nft":null},"attributes":[{"trait_type":[["title"]],"value":"Song Edition"}],"bpm":[["bpm"]],"credits":[["credits"]],"description":[["description"]],"duration":[["duration"]],"external_url":[["externalURI"]],"genre":[["genre"]],"image":[["artworkURI"]],"isrc":[["isrc"]],"key":[["key"]],"license":[["license"]],"locationCreated":[["locationCreated"]],"losslessAudio":[["losslessAudio"]],"lyrics":[["lyrics"]],"mimeType":[["mime"]],"nftSerialNumber":[["sn"]],"name":[[["title"]," #",["sn"]]],"originalReleaseDate":[["originalReleaseDate"]],"project":[["project"]],"publisher":[["publisher"]],"recordLabel":[["recordLabel"]],"tags":[["tags"]],"title":[["title"]],"trackNumber":[["trackNumber"]],"version":[["version"]],"visualizer":[["visualizer"]]}';

        string
            memory valuesString = '{"animationURI":"","artist":"Daniel Allan","artworkMime":"image/gif","artworkURI":"ar://J5NZ-e2NUcQj1OuuhpTjAKtdW_nqwnwo5FypF_a6dE4","description":"Criteria is an 8-track project between Daniel Allan and Reo Cragun.\\n\\nA fusion of electronic music and hip-hop - Criteria brings together the best of both worlds and is meant to bring web3 music to a wider audience.\\n\\nThe collection consists of 2500 editions with activations across Sound, Bonfire, OnCyber, Spinamp and Arpeggi.","duration":105,"genre":"Pop","losslessAudio":"","mime":"audio/wave","title":"Criteria","trackNumber":1,"version":"sound-edition-20220930"}';

        JSONParserLib.Item memory template = JSONParserLib.parse(templateString);

        M._Replacements memory replacements;
        replacements.baseValues = JSONParserLib.parse(valuesString);
        replacements.sn = 123;

        assertEq(M._isLiteralPlaceholder(template.at('"animation_url"')), true);

        assertEq(M._isLiteralPlaceholder(template.at('"name"')), false);

        assertEq(M._isStringPlaceholder(template.at('"name"')), true);

        assertEq(M._literalSubstitution(template.at('"artist"'), replacements), '"Daniel Allan"');

        assertEq(M._literalSubstitution(template.at('"trackNumber"'), replacements), "1");

        DynamicBufferLib.DynamicBuffer memory buffer;

        M._walk(template, replacements, buffer);

        assertEq(
            string(buffer.data),
            '{"animation_url":"","artist":"Daniel Allan","artwork":{"mimeType":"image/gif","uri":"ar://J5NZ-e2NUcQj1OuuhpTjAKtdW_nqwnwo5FypF_a6dE4","nft":null},"attributes":[{"trait_type":"Criteria","value":"Song Edition"}],"bpm":null,"credits":null,"description":"Criteria is an 8-track project between Daniel Allan and Reo Cragun.\\n\\nA fusion of electronic music and hip-hop - Criteria brings together the best of both worlds and is meant to bring web3 music to a wider audience.\\n\\nThe collection consists of 2500 editions with activations across Sound, Bonfire, OnCyber, Spinamp and Arpeggi.","duration":105,"external_url":null,"genre":"Pop","image":"ar://J5NZ-e2NUcQj1OuuhpTjAKtdW_nqwnwo5FypF_a6dE4","isrc":null,"key":null,"license":null,"locationCreated":null,"losslessAudio":"","lyrics":null,"mimeType":"audio/wave","nftSerialNumber":123,"name":"Criteria #123","originalReleaseDate":null,"project":null,"publisher":null,"recordLabel":null,"tags":null,"title":"Criteria","trackNumber":1,"version":"sound-edition-20220930","visualizer":null}'
        );
    }

    function test_reservedSubstitution() public {
        string memory templateString;
        string memory valuesString;
        DynamicBufferLib.DynamicBuffer memory buffer;

        M._Replacements memory replacements;
        replacements.id = 333;
        replacements.sn = 222;
        replacements.tier = 11;

        templateString = '[[["title"]," #",["sn"]]]';
        valuesString = '{"title":"Hehe"}';
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), '"Hehe #222"');

        templateString = '[[["tier"],["id"],["sn"]]]';
        valuesString = '{"title":"Hehe"}';
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), '"11333222"');

        templateString = '[[["tier"],"-",["id"],"-",["sn"]]]';
        valuesString = '{"tier":"T","id":"I","sn":"S"}';
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), '"T-I-S"');

        templateString = '[[["missing"],"-",["missing"],"-",["missing"]]]';
        valuesString = '{"tier":"T","id":"I","sn":"S"}';
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), '"--"');

        templateString = '[[["sn"]]]';
        valuesString = '{"tier":"T","id":"I","sn":"S"}';
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), '"S"');

        templateString = '[[["sn"]]]';
        valuesString = "{}";
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), '"222"');

        templateString = '[["sn"]]';
        valuesString = "{}";
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), "222");

        templateString = "[[[]]]";
        valuesString = "{}";
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), "[[[]]]");

        templateString = "[[]]";
        valuesString = "{}";
        replacements.baseValues = JSONParserLib.parse(valuesString);
        M._walk(JSONParserLib.parse(templateString), replacements, buffer.clear());
        assertEq(string(buffer.data), "[[]]");
    }
}
