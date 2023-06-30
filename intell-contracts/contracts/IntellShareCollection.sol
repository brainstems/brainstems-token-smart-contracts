// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interface/IIntellSetting.sol";

contract IntellShareCollectionContract is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    AccessControl
{
    using Strings for uint256;
    using SafeMath for uint256;
    // Structure for Share Collection Info
    struct ShareCollection {
        address paymentTokenAddr;
        uint256 softcap;
        uint256 maxTotalSupply;
        uint256 totalInvestmentAmount;
        uint256 price;
        uint256 launchEndTime;
        uint256 shareCollectionId;
        bool withdrawn;
        bool blocked;
        bool paused;
        bool forUSInvestors;
        bool cancelled;
        string ipfsHash;
    }

    error ShareCollectionNotFound();
    error NotEnoughSupply();
    error NotIntellModelNFT();
    error UnverifiedMessage();

    event CollectionURIUpdated(uint256 __id, string __uri);

    // Mapping of share collections
    mapping(uint256 => ShareCollection[]) private _shareCollections;

    // Mapping of launched share collection ids
    mapping(uint256 => bool) private _shareCollectionLaunched;

    // Intell Setting
    IIntellSetting public intellSetting;

    // The token name
    string public name;

    // The token symbol
    string public symbol;

    // The next Intell Share Collection Id
    uint256 public nextIntellShareCollectionId = 0;

    /**
     * @dev Sets name/symbol/intell setting in construction
     *
     * @param __name The token name
     * @param __symbol The token symbol
     * @param __intellSetting The instance of intellSetting
     * Date: 2023-05-18
     */
    constructor(
        string memory __name,
        string memory __symbol,
        IIntellSetting __intellSetting
    ) ERC1155("") {
        name = __name;
        symbol = __symbol;
        intellSetting = __intellSetting;
    }

    /* ============================================== */
    /* ================== Modifiers ================= */
    /* ============================================== */

    /**
     * @dev Checks if share collection exists
     *
     * @param __id The shsare collection id
     * Date: 2023-05-18
     * Author: Created by Isom D.
     */
    modifier onlyExistingShareCollection(uint256 __id) {
        if (!shareCollectionExists(__id)) {
            revert ShareCollectionNotFound();
        }
        _;
    }

    /**
     * @dev Checks if share collections exists
     *
     * @param __ids The share collection id(s)
     * Date: 2023-05-18
     */

    modifier onlyExistingShareCollectionBatch(uint256[] calldata __ids) {
        for (uint256 i = 0; i < __ids.length; i++) {
            if (!shareCollectionExists(__ids[i])) {
                revert ShareCollectionNotFound();
            }
        }
        _;
    }

    modifier onlyCreator() {
        _;
    }

    /**
     * @dev Checks if caller is from Intell Model NFT Contract
     * Date: 2023-06-07
     * Author: Created by Isom D.
     */

    modifier onlyIntellModelNFT() {
        require(
            intellSetting.intellModelNFTContractAddr() == msg.sender &&
                msg.sender != tx.origin,
            "Ownable: CALLER IS NOT INTELL MODEL NFT ADDRESS"
        );
        _;
    }

    /* ============================================== */
    /* ================== Internal ================= */
    /* ============================================== */

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `ids` and `amounts` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):

     * Date: 2023-05-18
     */

    function _beforeTokenTransfer(
        address __operator,
        address __from,
        address __to,
        uint256[] memory __ids,
        uint256[] memory __amounts,
        bytes memory __data
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(
            __operator,
            __from,
            __to,
            __ids,
            __amounts,
            __data
        );

        // if (__from == address(0) && __ids.length > 0) {
        //     for (uint256 i = 0; i < __ids.length; i++) {
        //         if (_shareCollections[__ids[i]].maxTotalSupply != 0) {
        //             if (
        //                 totalSupply(__ids[i]) >
        //                 _shareCollections[__ids[i]].maxTotalSupply
        //             ) revert NotEnoughSupply();
        //         }
        //     }
        // }
    }

    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    function verifyMessage(
        bytes memory message,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 hash = keccak256(message);
        return recoverSigner(hash, signature) == intellSetting.truthHolder();
    }

    /* ============================================== */
    /* ================== For Creators ============== */
    /* ============================================== */

    function getCreator(uint256 __intellTokenId) public view returns (address) {
        return
            IERC721Enumerable(intellSetting.intellModelNFTContractAddr())
                .ownerOf(__intellTokenId);
    }

    function cancel(uint256 __intellTokenId) public {
        uint256 _status = getStatus(__intellTokenId);
        require(_status > 1 && _status < 4, "NOT CAN CANCEL!");
        require(
            getCreator(__intellTokenId) == msg.sender,
            "THE CALLER IS NOT OWNER AS CREATOR!"
        );

        uint256 oldShareCollectionLength = _shareCollections[__intellTokenId]
            .length;
        _shareCollections[__intellTokenId][oldShareCollectionLength - 1]
            .cancelled = true;
    }

    function getStatus(uint256 __intellTokenId) public view returns (uint256) {
        //0: Not launched
        //1: Cancelled
        //2: Unsuccess
        //3: In progress
        //4: Success
        uint256 oldShareCollectionLength = _shareCollections[__intellTokenId]
            .length;
        ShareCollection memory lastShareCollection = _shareCollections[
            __intellTokenId
        ][oldShareCollectionLength - 1];

        if (oldShareCollectionLength > 0) {
            if (lastShareCollection.cancelled) return 1;
            if (lastShareCollection.launchEndTime > block.timestamp) return 3;
            if (
                lastShareCollection.softcap <=
                totalSupply(lastShareCollection.shareCollectionId)
            ) return 4;
            else return 2;
        } else {
            return 0;
        }
    }

    function validation(bytes memory data) internal view returns(bool) {
        (
            address _USER_ADDR,
            uint256 _INTELL_MODEL_TOKEN_ID,
            uint256 _MAX_TOTAL_SUPPLY,
            uint256 _MINT_PRICE,
            bool _USER_SUSPENDED,
            bool _APPROVED,
            bool _HAS_SHARE
        ) = abi.decode(
                data,
                (
                    address,
                    uint256,
                    uint256,
                    uint256,
                    bool,
                    bool,
                    bool
                )
            );

        // Validation
        require(_HAS_SHARE, "NO SHARE");
        require(
            getStatus(_INTELL_MODEL_TOKEN_ID) < 3,
            "CAN NOT CREATE NEW SHARE COLLECTION!"
        );
        require(_MAX_TOTAL_SUPPLY > 0 && _MINT_PRICE > 0, "INVALID INPUT DATA");
        require(
            getCreator(_INTELL_MODEL_TOKEN_ID) == msg.sender,
            "THE CALLER MUST BE CREATOR!"
        );
        require(_APPROVED, "MUST BE APPROVED FROM ADMIN");
        require(_USER_ADDR == msg.sender, "THE CALLER MUST BE OWNER!");
        require(!_USER_SUSPENDED, "YOU WAS BLOCKED FROM TIEX DAO ADMIN!");

        return true;

    }

    /**
     * @dev releases new share collection
     */

    function releaseShareCollection(
        bytes memory __shareCollection,
        bytes memory __shareCollectionSignature,
        bytes memory __validation,
        bytes memory __validationSignature
    ) external {
        // Verifys signature using ECDSA
        if (!verifyMessage(__shareCollection, __shareCollectionSignature) && !verifyMessage(__validation, __validationSignature)) {
            revert UnverifiedMessage();
        }

        require(validation(__validation), "Params are invalid!");

        nextIntellShareCollectionId++;

        // Decode params from bytes
        (
            address _PAYMENT_TOKEN_ADDR,
            uint256 _INTELL_MODEL_TOKEN_ID,
            uint256 _MAX_TOTAL_SUPPLY,
            uint256 _MINT_PRICE,
            uint256 _DURATION,
            uint256 _SOFTCAP,
            bool _FOR_ONLY_US_INVESTOR,
            string memory _IPFS_HASH
        ) = abi.decode(
                __shareCollection,
                (
                    address,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    bool,
                    string
                )
            );



        // Creates new collection
        _shareCollections[_INTELL_MODEL_TOKEN_ID].push(
            ShareCollection({
                paymentTokenAddr: _PAYMENT_TOKEN_ADDR,
                softcap: _SOFTCAP,
                maxTotalSupply: _MAX_TOTAL_SUPPLY,
                totalInvestmentAmount: 0,
                price: _MINT_PRICE,
                launchEndTime: block.timestamp.add(_DURATION),
                withdrawn: false,
                blocked: false,
                paused: false,
                cancelled: false,
                forUSInvestors: _FOR_ONLY_US_INVESTOR,
                ipfsHash: _IPFS_HASH,
                shareCollectionId: nextIntellShareCollectionId
            })
        );
    }

    /**
     * @dev Used to edit the token URI of an Edition.
     *
     * Emits a {EditionURIUpdated} event.
     *
     */
    function editURI(
        uint256 __intellTokenId,
        string calldata __ipfsHash
    ) external {
        require(
            msg.sender == intellSetting.admin(),
            "THE CALLER MUST BE ADMIN"
        );
        require(getStatus(__intellTokenId) > 0, "NOT LAUNCHED YET!");

        uint256 _shareCollectionLength = _shareCollections[__intellTokenId]
            .length;

        for (uint256 i = 0; i < _shareCollectionLength; i++) {
            _shareCollections[__intellTokenId][i].ipfsHash = __ipfsHash;
        }

        emit CollectionURIUpdated(__intellTokenId, __ipfsHash);
    }
    

    function shareCollectionExists(uint256 __id) public view returns (bool) {
        return _shareCollectionLaunched[__id];
    }

    /**
     * @dev See {ERC1155-supportsInterface} and {AccessControl-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
