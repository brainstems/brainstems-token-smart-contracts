// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IUtility {
    function verifyMessage(
        bytes memory message,
        bytes memory signature,
        address truthHolder
    ) external pure returns (bool);
}
