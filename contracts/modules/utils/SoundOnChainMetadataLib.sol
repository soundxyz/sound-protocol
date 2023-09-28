// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { DynamicBufferLib } from "solady/utils/DynamicBufferLib.sol";
import { JSONParserLib } from "solady/utils/JSONParserLib.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibOps } from "@core/utils/LibOps.sol";

library SoundOnChainMetadataLib {
    using JSONParserLib for JSONParserLib.Item;
    using DynamicBufferLib for DynamicBufferLib.DynamicBuffer;

    // =============================================================
    //                     REPLACEMENT OPERATION
    // =============================================================

    /**
     * @dev Traverses the JSON template and performs substitutions, collecting the results in `buffer`.
     * @param id          The token ID.
     * @param sn          The serial number of the token (index of the token in its tier + 1).
     * @param tier        The token tier.
     * @param isGoldenEgg Whether the token is a golden egg.
     * @param getTemplate The function to return a template string, given the template ID.
     * @param valuesJSON  The values JSON.
     * @param buffer      The dynamic buffer to collect the results into.
     */
    function walk(
        uint256 id,
        uint256 sn,
        uint8 tier,
        bool isGoldenEgg,
        function(string memory) view returns (string memory) getTemplate,
        string memory valuesJSON,
        DynamicBufferLib.DynamicBuffer memory buffer
    ) internal view {
        _Replacements memory replacements;
        replacements.sn = sn;
        replacements.id = id;
        replacements.tier = tier;
        replacements.isGoldenEgg = isGoldenEgg;
        JSONParserLib.Item memory root = JSONParserLib.parse(valuesJSON);

        string memory templateId;

        string[6] memory k = ['"values"', '"v"', '"template"', '"t"', '"goldenEgg"', '"g"'];

        JSONParserLib.Item memory goldenEggRoot = _getAtEither(root, k[4], k[5]);
        replacements.goldenEggValues = _getAtEither(goldenEggRoot, k[0], k[1]);
        if (replacements.isGoldenEgg) {
            JSONParserLib.Item memory t = _getAtEither(goldenEggRoot, k[2], k[3]);
            if (t.isString()) templateId = t.value();
        }

        JSONParserLib.Item memory tierRoot = root.at(LibString.escapeJSON(LibString.toString(tier), true));
        replacements.tierValues = _getAtEither(tierRoot, k[0], k[1]);
        if (bytes(templateId).length == 0) {
            JSONParserLib.Item memory t = _getAtEither(tierRoot, k[2], k[3]);
            if (t.isString()) templateId = t.value();
        }
        if (replacements.isGoldenEgg) {
            JSONParserLib.Item memory tierGoldenEggRoot = _getAtEither(tierRoot, k[4], k[5]);
            replacements.tierGoldenEggValues = _getAtEither(tierGoldenEggRoot, k[0], k[1]);
            JSONParserLib.Item memory t = _getAtEither(tierGoldenEggRoot, k[2], k[3]);
            if (t.isString()) templateId = t.value();
        }

        JSONParserLib.Item memory baseRoot = _getAtEither(root, '"base"', '"b"');
        replacements.baseValues = _getAtEither(baseRoot, k[0], k[1]);
        if (bytes(templateId).length == 0) {
            JSONParserLib.Item memory t = _getAtEither(baseRoot, k[2], k[3]);
            if (t.isString()) templateId = t.value();
        }

        _walk(JSONParserLib.parse(getTemplate(JSONParserLib.decodeString(templateId))), replacements, buffer);
    }

    // =============================================================
    //                       INTERNAL HELPERS
    // =============================================================

    struct _Replacements {
        JSONParserLib.Item tierGoldenEggValues;
        JSONParserLib.Item goldenEggValues;
        JSONParserLib.Item tierValues;
        JSONParserLib.Item baseValues;
        uint256 id;
        uint256 sn;
        uint8 tier;
        bool isGoldenEgg;
        string tierKey;
        uint48 templateId;
    }

    function _getAtEither(
        JSONParserLib.Item memory item,
        string memory keyA,
        string memory keyB
    ) internal pure returns (JSONParserLib.Item memory found) {
        found = item.at(keyA);
        if (found.isUndefined()) found = item.at(keyB);
    }

    function _walk(
        JSONParserLib.Item memory item,
        _Replacements memory replacements,
        DynamicBufferLib.DynamicBuffer memory buffer
    ) internal pure {
        if (_isLiteralPlaceholder(item)) {
            buffer.p(bytes(_literalSubstitution(item, replacements)));
        } else if (_isStringPlaceholder(item)) {
            buffer.p(bytes(_stringSubstitution(item, replacements)));
        } else {
            unchecked {
                JSONParserLib.Item[] memory children = item.children();
                if (item.isObject()) {
                    buffer.p("{");
                    for (uint256 i; i != children.length; ++i) {
                        JSONParserLib.Item memory child = children[i];
                        if (i != 0) buffer.p(",");
                        buffer.p(bytes(child.key())).p(":");
                        _walk(child, replacements, buffer);
                    }
                    buffer.p("}");
                } else if (item.isArray()) {
                    buffer.p("[");
                    for (uint256 i; i != children.length; ++i) {
                        JSONParserLib.Item memory child = children[i];
                        if (i != 0) buffer.p(",");
                        _walk(child, replacements, buffer);
                    }
                    buffer.p("]");
                } else if (!item.isUndefined()) {
                    buffer.p(bytes(item.value()));
                }
            }
        }
    }

    function _getAtKey(_Replacements memory replacements, string memory key)
        internal
        pure
        returns (JSONParserLib.Item memory found)
    {
        if (replacements.isGoldenEgg) {
            found = replacements.tierGoldenEggValues.at(key);
            if (!found.isUndefined()) return found;
            found = replacements.goldenEggValues.at(key);
            if (!found.isUndefined()) return found;
        }
        found = replacements.tierValues.at(key);
        if (!found.isUndefined()) return found;
        found = replacements.baseValues.at(key);
    }

    function _stringSubstitution(JSONParserLib.Item memory item, _Replacements memory replacements)
        internal
        pure
        returns (string memory)
    {
        unchecked {
            DynamicBufferLib.DynamicBuffer memory buffer;
            JSONParserLib.Item[] memory children = item.at(0).children();
            for (uint256 i; i != children.length; ++i) {
                JSONParserLib.Item memory child = children[i];
                if (child.isString()) {
                    buffer.p(bytes(JSONParserLib.decodeString(child.value())));
                } else {
                    string memory key = child.at(0).value();
                    JSONParserLib.Item memory found = _getAtKey(replacements, key);
                    if (found.isUndefined()) {
                        buffer.p(bytes(_reservedSubstitution(key, replacements)));
                    } else {
                        if (found.isString()) {
                            buffer.p(bytes(JSONParserLib.decodeString(found.value())));
                        } else {
                            buffer.p(bytes(found.value()));
                        }
                    }
                }
            }
            return LibString.escapeJSON(buffer.s(), true);
        }
    }

    function _literalSubstitution(JSONParserLib.Item memory item, _Replacements memory replacements)
        internal
        pure
        returns (string memory)
    {
        string memory key = item.at(0).at(0).value();
        JSONParserLib.Item memory found = _getAtKey(replacements, key);
        if (found.isUndefined()) {
            string memory r = _reservedSubstitution(key, replacements);
            return bytes(r).length == 0 ? "null" : r;
        }
        return found.value();
    }

    function _reservedSubstitution(string memory key, _Replacements memory replacements)
        internal
        pure
        returns (string memory result)
    {
        if (LibString.eqs(key, '"id"')) return LibString.toString(replacements.id);
        if (LibString.eqs(key, '"sn"')) return LibString.toString(replacements.sn);
        if (LibString.eqs(key, '"tier"')) return LibString.toString(replacements.tier);
    }

    function _isLiteralPlaceholder(JSONParserLib.Item memory item) internal pure returns (bool) {
        return _isArrayOfOne(item) && _isArrayOfOne(item = item.at(0)) && item.at(0).isString();
    }

    function _isStringPlaceholder(JSONParserLib.Item memory item) internal pure returns (bool) {
        unchecked {
            if (!_isArrayOfOne(item)) return false;
            item = item.at(0);
            if (!item.isArray()) return false;
            JSONParserLib.Item[] memory children = item.children();
            for (uint256 i; i != children.length; ++i) {
                JSONParserLib.Item memory child = children[i];
                if (child.isString()) continue;
                if (_isArrayOfOne(child) && child.at(0).isString()) continue;
                return false;
            }
            return children.length != 0;
        }
    }

    function _isArrayOfOne(JSONParserLib.Item memory item) internal pure returns (bool) {
        return item.isArray() && item.size() == 1;
    }
}
