// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract IntellMarketplace {
    using Strings for uint256;
    using SafeMath for uint256;

    struct OrderStatus {
        address seller;
        address collection;
        uint256 tokenId;
        uint256 price;
        uint256 startTime;
        uint256 duration;
        bytes32 orderHash;
    }

    address public truthHolder = 0xF8AbE936Ff2bCc9774Db7912554c4f38368e05A2;
    IERC20 public intellToken =
        IERC20(0xd9145CCE52D386f254917e481eB44e9943F39138);

    mapping(bytes32 => bool) private orderHashStatus;

    function buyIntellShareNFT(bytes calldata message, bytes calldata signature)
        external
    {
        require(
            verifyMessage(message, signature),
            "Need to sign from truth holder"
        );

        (
            address buyer,
            address seller,
            address collection,
            uint256 tokenId,
            uint256 price,
            uint256 startTime,
            uint256 duration,
            bytes32 orderHash
        ) = abi.decode(
                message,
                (
                    address,
                    address,
                    address,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    bytes32
                )
            );

        IERC721Enumerable nftCollection = IERC721Enumerable(collection);

        require(buyer == msg.sender && msg.sender == tx.origin, "Not bot");

        // Buyer Status
        require(buyerStatus(buyer, price), "buyer status is invalid");
        // Order Status
        require(
            getOrderHashStatus(
                OrderStatus(
                    seller,
                    collection,
                    tokenId,
                    price,
                    startTime,
                    duration,
                    orderHash
                )
            ),
            "Order is invalid"
        );

        // transfers nft to buyer
        nftCollection.safeTransferFrom(seller, buyer, tokenId, "");

        // transfers INTELL token to seller
        intellToken.transferFrom(buyer, seller, price);

        orderHashStatus[orderHash] = true;
    }

    function cancel(bytes calldata message, bytes calldata signature) external {
        require(
            verifyMessage(message, signature),
            "Need to sign from truth holder"
        );

        (
            address seller,
            address collection,
            uint256 tokenId,
            uint256 price,
            uint256 startTime,
            uint256 duration,
            bytes32 orderHash
        ) = abi.decode(
                message,
                (address, address, uint256, uint256, uint256, uint256, bytes32)
            );

        require(
            msg.sender == seller && seller == tx.origin,
            "Not bot or owner"
        );

        require(
            getOrderHashStatus(
                OrderStatus(
                    seller,
                    collection,
                    tokenId,
                    price,
                    startTime,
                    duration,
                    orderHash
                )
            ),
            "Order is invalid"
        );

        orderHashStatus[orderHash] = true;
    }

    function getOrderHashStatus(OrderStatus memory _orderStatus)
        public
        view
        returns (bool)
    {
        bytes32 _orderHash = keccak256(
            abi.encode(
                _orderStatus.seller,
                _orderStatus.collection,
                _orderStatus.tokenId,
                _orderStatus.price,
                _orderStatus.startTime,
                _orderStatus.duration
            )
        );

        IERC721Enumerable nftCollection = IERC721Enumerable(
            _orderStatus.collection
        );

        // ================= The sold collection exists in factory contract and was not BLOCKED? ===============
        //                                                                                             ========
        //\\\\\\\\\\\\\\\\\/////////////////////\\\\\\\\\\\\\\\\\\\\\\////////////////\\\\\\\\\\\\\\\\\========
        //                                                                                             ========
        // ====================================================================================================
        if (_orderStatus.price == 0) return false;

        if (
            _orderStatus.seller == address(0) ||
            _orderStatus.collection == address(0)
        ) return false;

        if (_orderHash != _orderStatus.orderHash) return false;

        if (!nftCollection.isApprovedForAll(_orderStatus.seller, address(this)))
            return false;

        if (nftCollection.ownerOf(_orderStatus.tokenId) != _orderStatus.seller)
            return false;

        if (orderHashStatus[_orderStatus.orderHash]) return false;

        if (_orderStatus.startTime.add(_orderStatus.duration) < block.timestamp)
            return false;

        return true;
    }

    function buyerStatus(address buyer, uint256 price)
        public
        view
        returns (bool)
    {
        if (buyer == address(0)) return false;
        if (intellToken.allowance(buyer, address(this)) < price) return false;
        if (intellToken.balanceOf(buyer) < price) return false;
        return true;
    }

    function recoverSigner(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    function verifyMessage(bytes memory message, bytes memory signature)
        internal
        view
        returns (bool)
    {
        bytes32 hash = keccak256(message);
        return recoverSigner(hash, signature) == truthHolder;
    }
}
