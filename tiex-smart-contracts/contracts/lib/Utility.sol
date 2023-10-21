// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interface/IUtility.sol";

contract Utility is IUtility {
    /**
     * @notice Verifies bytes message
     */
    function verifyMessage(
        bytes memory message,
        bytes memory signature,
        address truthHolder
    ) external pure returns (bool) {
        bytes32 hash = keccak256(message);
        return recoverSigner(hash, signature) == truthHolder;
    }

    /**
     * @notice Recovers signer
     */
    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) private pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }
}