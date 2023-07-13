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
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interface/IIntellSetting.sol";

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: APPROVE_FAILED"
        );
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FROM_FAILED"
        );
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }
}

contract IntellShareCollectionContract is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply
{
    using Strings for uint256;
    using SafeMath for uint256;

    // Structure for Share Collection Info
    struct ShareCollection {
        address paymentTokenAddr; // Payment token address
        uint256 softcap; // Softcap
        uint256 maxTotalSupply; // Hardcap
        uint256 totalInvestmentAmount; // total investment amount from investors
        uint256 price; // price per a share
        uint256 launchEndTime; // end time
        uint256 intellModelNFTTokenId; // Intell Model NFT token id
        bool withdrawn; // if withdrawn already
        bool paused; // if sale paused
        bool blocked; // if the share collection is availabe to trade
        bool forUSInvestors; // if it's for only U.S investors
        bool cancelled; // if cancelled
        string ipfsHash; // IPFS hash for metadata of model
    }

    error ShareCollectionNotFound();
    error NotEnoughSupply();
    error NotIntellModelNFT();
    error UnverifiedMessage();

    event ReleaseNewShareCollection(uint256 __whenLaunched, uint256 __intellModelNFTTokenId, uint256 __nextIntellShareCollectionId);
    event CollectionURIUpdated(uint256 __id, string __uri);
    event CollectionSaleCancelled(uint256 __id);
    event Refund(
        uint256 __collectionId,
        uint256 __refundAmount,
        uint256 __burnAmount
    );
    event Withdraw(
        address __creator,
        uint256 __shareCollectionId,
        uint256 __investmentAmount
    );

    // Mapping of share collection ids and share collections strucutre
    mapping(uint256 => ShareCollection) private _shareCollections;

    // Mapping of IntellModelNFT TokenId and Share collection ids
    mapping(uint256 => uint256[]) private _shareCollectionIds;

    // Mapping of launched share collection ids
    mapping(uint256 => bool) private _shareCollectionLaunched;

    // Tracks user investment in each shares
    mapping(address => mapping(uint256 => uint256))
        private _userInvestmentTracker;

    // So far, the amount of investment in total on TIEX DAO
    uint256 private _totalInvestmentAmount;

    // The total amount of investment of an user account
    mapping(address => uint256) private _userInvestmentAmountInTotal;

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
     */
    modifier onlyExistingShareCollectionBatch(uint256[] calldata __ids) {
        for (uint256 i = 0; i < __ids.length; i++) {
            if (!shareCollectionExists(__ids[i])) {
                revert ShareCollectionNotFound();
            }
        }
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

        // Checks if all transfers except burn and mint are possible.
        // Filters out shares that have sold successfully and are not blocked.
        if (__from != address(0) || __to != address(0)) {
            for (uint256 i = 0; i < __ids.length; i++) {
                require(
                    getStatus(__ids[i]) == 5 ||
                        !_shareCollections[__ids[i]].blocked,
                    "TRANSFER IS AVAILABE WHEN THE SALE IS SUCCESSFUL"
                );
            }
        }
    }

    // Recovers signer
    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    // Verifies bytes message
    function verifyMessage(
        bytes memory message,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 hash = keccak256(message);
        return recoverSigner(hash, signature) == intellSetting.truthHolder();
    }

    // Checks validation to release new share collection
    function validation(bytes memory data) internal view returns (bool) {
        (
            address _USER_ADDR,
            uint256 _INTELL_MODEL_NFT_TOKEN_ID,
            bool _USER_SUSPENDED,
            bool _APPROVED,
            bool _HAS_SHARE
        ) = abi.decode(data, (address, uint256, bool, bool, bool));

        // Validation
        uint256 __shareCollectionLength = _shareCollectionIds[
            _INTELL_MODEL_NFT_TOKEN_ID
        ].length;

        if (__shareCollectionLength > 0) {
            uint256 __lastShareCollectionIndex = __shareCollectionLength - 1;
            uint256 __status = getStatus(__lastShareCollectionIndex);
            require(
                __status == 1 || __status == 2,
                "CAN NOT CREATE NEW SHARE COLLECTION!"
            );
        }

        require(_HAS_SHARE, "NO SHARE");
        require(
            getCreator(_INTELL_MODEL_NFT_TOKEN_ID) == msg.sender,
            "THE CALLER MUST BE CREATOR!"
        );
        require(_APPROVED, "MUST BE APPROVED FROM ADMIN");
        require(_USER_ADDR == msg.sender, "THE CALLER MUST BE OWNER!");
        require(!_USER_SUSPENDED, "YOU WAS BLOCKED FROM TIEX DAO ADMIN!");

        return true;
    }

    /* ============================================== */
    /* ================== Public ============= */
    /* ============================================== */

    // Get IERC20 instance for payment token
    function paymentToken() public view returns (IERC20) {
        return IERC20(intellSetting.intellTokenAddr());
    }

    function getCreator(
        uint256 __intellModelTokenId
    ) public view returns (address) {
        return
            IERC721Enumerable(intellSetting.intellModelNFTContractAddr())
                .ownerOf(__intellModelTokenId);
    }

    // 0: Not launched
    // 1: Cancelled
    // 2: Unsuccess
    // 3: In progress
    // 4: All Sold
    // 5: Success
    function getStatus(
        uint256 __shareCollectionId
    ) public view returns (uint256) {
        ShareCollection memory __shareCollection = _shareCollections[
            __shareCollectionId
        ];
        if (!_shareCollectionLaunched[__shareCollectionId]) return 0; // Not Launched
        if (__shareCollection.cancelled) return 1; // Cancelled by creator
        if (
            __shareCollection.launchEndTime <= block.timestamp &&
            __shareCollection.softcap > totalSupply(__shareCollectionId)
        ) return 2; // Unsuccess
        if (
            __shareCollection.launchEndTime > block.timestamp &&
            __shareCollection.maxTotalSupply > totalSupply(__shareCollectionId)
        ) return 3; // In progress
        if (
            __shareCollection.launchEndTime > block.timestamp &&
            __shareCollection.maxTotalSupply == totalSupply(__shareCollectionId)
        ) return 4; // All Sold
        if (
            __shareCollection.launchEndTime <= block.timestamp &&
            __shareCollection.softcap <= totalSupply(__shareCollectionId)
        ) return 5; // Success

        return 0;
    }

    function uri(
        uint __id
    ) public view virtual override returns (string memory) {
        return
            string(
                abi.encodePacked("ipfs://", _shareCollections[__id].ipfsHash)
            );
    }

    function shareCollectionExists(uint256 __id) public view returns (bool) {
        return _shareCollectionLaunched[__id];
    }

    function shareCollections(
        uint256 __shareCollectionId
    ) external view returns (ShareCollection memory) {
        return _shareCollections[__shareCollectionId];
    }

    function shareCollectionIds(
        uint256 __intellModelNFTTokenId
    ) external view returns (uint256[] memory) {
        return _shareCollectionIds[__intellModelNFTTokenId];
    }

    function userInvestmentAmountInTotal(
        address __user
    ) external view returns (uint256) {
        return _userInvestmentAmountInTotal[__user];
    }

    function totalInvestmentAmount() external view returns (uint256) {
        return _totalInvestmentAmount;
    }

    function userInvestmentTracker(
        address __user,
        uint256 __shareCollectionId
    ) external view returns (uint256) {
        return _userInvestmentTracker[__user][__shareCollectionId];
    }

    /* ============================================== */
    /* ================== For Investors ============= */
    /* ============================================== */

    function adopt(bytes calldata message, bytes calldata signature) external {
        require(verifyMessage(message, signature), "NO SIGNER");

        (
            address _USER_ADDR,
            bool _KYC_VERIFICATION_AS_INVESTOR,
            bool _USER_SUSPENDED,
            bool _FROM_US,
            uint256 _AMOUNT,
            uint256 _SHARE_COLLECTION_ID
        ) = abi.decode(message, (address, bool, bool, bool, uint256, uint256));

        ShareCollection memory __shareCollection = _shareCollections[
            _SHARE_COLLECTION_ID
        ];
        bool __FOR_US_INVESTORS = __shareCollection.forUSInvestors;
        uint256 __paymentTokenAmount = __shareCollection.price * _AMOUNT;

        require(_AMOUNT > 0, "THIS IS REQUIRED VALID");
        require(
            (__FOR_US_INVESTORS && _FROM_US && _KYC_VERIFICATION_AS_INVESTOR) ||
                (!__FOR_US_INVESTORS && !_FROM_US),
            "KYC is required"
        );

        require(
            shareCollectionExists(_SHARE_COLLECTION_ID),
            "NOT LAUNCHED YET!"
        );
        require(
            getStatus(_SHARE_COLLECTION_ID) == 3,
            "THIS SHARE COLLECTION SALE IS NOT ONGOING!"
        );
        require(!_USER_SUSPENDED, "THE INVESTOR ACCOUNT IS SUSPENDED!");
        require(
            __shareCollection.launchEndTime >= block.timestamp,
            "SALE DURATION WAS EXPIRED"
        );
        require(
            totalSupply(_SHARE_COLLECTION_ID) + _AMOUNT <=
                __shareCollection.maxTotalSupply,
            "EXCEED MAX SUPPLY"
        );

        require(!__shareCollection.paused, "SALE STOPPED");
        require(tx.origin == msg.sender && msg.sender == _USER_ADDR, "NO BOT");
        require(
            IERC20(intellSetting.intellTokenAddr()).balanceOf(msg.sender) >=
                __paymentTokenAmount,
            "INSUFFICIENT BALANCE"
        );

        TransferHelper.safeTransferFrom(
            intellSetting.intellTokenAddr(),
            msg.sender,
            address(this),
            __paymentTokenAmount
        );
        _mint(_USER_ADDR, _SHARE_COLLECTION_ID, _AMOUNT, "");
        _shareCollections[_SHARE_COLLECTION_ID]
            .totalInvestmentAmount = _shareCollections[_SHARE_COLLECTION_ID]
            .totalInvestmentAmount
            .add(__paymentTokenAmount);
        _userInvestmentTracker[msg.sender][
            _SHARE_COLLECTION_ID
        ] = _userInvestmentTracker[msg.sender][_SHARE_COLLECTION_ID].add(
            __paymentTokenAmount
        );
        _userInvestmentAmountInTotal[msg.sender] = _userInvestmentAmountInTotal[
            msg.sender
        ].add(__paymentTokenAmount);
        _totalInvestmentAmount = _totalInvestmentAmount.add(
            __paymentTokenAmount
        );
    }

    function refundWhenCancelledOrUnsuccess(
        uint256 __shareCollectionId
    ) external {
        uint256 __status = getStatus(__shareCollectionId);
        require(
            __status == 1 || __status == 2,
            "CAN CLAIM WHEN CANCELLED OR UNSUCCESS!"
        );

        uint256 __balance = balanceOf(_msgSender(), __shareCollectionId);
        uint256 __amountInvested = _userInvestmentTracker[msg.sender][
            __shareCollectionId
        ];

        burn(_msgSender(), __shareCollectionId, __balance);

        TransferHelper.safeTransfer(
            intellSetting.intellTokenAddr(),
            msg.sender,
            __amountInvested
        );

        _shareCollections[__shareCollectionId]
            .totalInvestmentAmount = _shareCollections[__shareCollectionId]
            .totalInvestmentAmount
            .sub(__amountInvested);

        _userInvestmentTracker[msg.sender][__shareCollectionId] = 0;

        _userInvestmentAmountInTotal[msg.sender] = _userInvestmentAmountInTotal[
            msg.sender
        ].sub(__amountInvested);

        _totalInvestmentAmount = _totalInvestmentAmount.sub(__amountInvested);

        emit Refund(
            __shareCollectionId,
            _userInvestmentTracker[msg.sender][__shareCollectionId],
            __balance
        );
    }

    /* ============================================== */
    /* ================== For Creators ============== */
    /* ============================================== */

    // Cancels shares sale
    function cancel(uint256 __shareCollectionId) public {
        uint256 __status = getStatus(__shareCollectionId);
        uint256 __intellModelNFTTokenId = _shareCollections[__shareCollectionId]
            .intellModelNFTTokenId;

        require(__status == 3 || __status == 4, "CAN NOT CANCEL!");
        require(
            getCreator(__intellModelNFTTokenId) == msg.sender,
            "THE CALLER IS NOT OWNER AS CREATOR!"
        );

        _shareCollections[__shareCollectionId].cancelled = true;

        emit CollectionSaleCancelled(__shareCollectionId);
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
        if (
            !verifyMessage(__shareCollection, __shareCollectionSignature) &&
            !verifyMessage(__validation, __validationSignature)
        ) {
            revert UnverifiedMessage();
        }

        require(validation(__validation), "Params are invalid!");

        nextIntellShareCollectionId++;

        // Decode params from bytes
        (
            address _PAYMENT_TOKEN_ADDR,
            uint256 _INTELL_MODEL_NFT_TOKEN_ID,
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
        _shareCollectionLaunched[nextIntellShareCollectionId] = true;

        _shareCollectionIds[_INTELL_MODEL_NFT_TOKEN_ID].push(
            nextIntellShareCollectionId
        );

        _shareCollections[nextIntellShareCollectionId] = ShareCollection({
            paymentTokenAddr: _PAYMENT_TOKEN_ADDR,
            softcap: _SOFTCAP,
            maxTotalSupply: _MAX_TOTAL_SUPPLY,
            totalInvestmentAmount: 0,
            price: _MINT_PRICE,
            launchEndTime: block.timestamp.add(_DURATION),
            withdrawn: false,
            paused: false,
            cancelled: false,
            blocked: false,
            forUSInvestors: _FOR_ONLY_US_INVESTOR,
            ipfsHash: _IPFS_HASH,
            intellModelNFTTokenId: _INTELL_MODEL_NFT_TOKEN_ID
        });

        // Commission to release new share collection
        uint256 paymentTokenAmount = intellSetting.intellShareCollectionLaunchPrice();

        //Checks if user account has enough payment tokens to register
        require(
            paymentToken().balanceOf(msg.sender) >= paymentTokenAmount,
            "THE ERC20 TOKEN AMOUNT SENT IS NOT CORRECT OR INSUFFIENT ERC20 TOKEN AMOUNT SENT."
        );

        // Pays commission
        paymentToken().transferFrom(
            msg.sender,
            address(this),
            paymentTokenAmount
        );

        emit ReleaseNewShareCollection(block.timestamp, _INTELL_MODEL_NFT_TOKEN_ID, nextIntellShareCollectionId);
    }

    // Pauses
    function pause(uint256 __shareCollectionId, bool __val) external {
        uint256 __intellModelNFTTokenId = _shareCollections[__shareCollectionId]
            .intellModelNFTTokenId;
        require(
            getCreator(__intellModelNFTTokenId) == msg.sender,
            "THE CALLER MUST BE CREATOR!"
        );

        _shareCollections[__shareCollectionId].paused = __val;
    }

    // Withdraws investment
    function withdraw(
        bytes calldata message,
        bytes calldata signature
    ) external {
        require(verifyMessage(message, signature), "NO SIGNER");

        (
            bool _CAN_WITHDRAW,
            address _USER_ADDR,
            uint256 _SHARE_COLLECTION_ID
        ) = abi.decode(message, (bool, address, uint256));
        ShareCollection memory __shareCollection = _shareCollections[
            _SHARE_COLLECTION_ID
        ];
        uint256 __intellModelNFTTokenId = __shareCollection
            .intellModelNFTTokenId;

        require(
            __shareCollection.launchEndTime < block.timestamp,
            "NOT FINISHED YET"
        );
        require(!__shareCollection.withdrawn, "ALREADY WITHDRAWN");
        require(
            getStatus(_SHARE_COLLECTION_ID) == 5,
            "IF THE SALE IS SUCCESSFUL, IT CAN BE WITHDRAWN"
        );
        require(_CAN_WITHDRAW, "THE ADMIN HAS NOT APPROVED THE WITHDRAWAL YET");
        require(
            getCreator(__intellModelNFTTokenId) == msg.sender &&
                msg.sender == _USER_ADDR,
            "THE CALLER MUST BE CREATOR!"
        );

        uint256 __amount = __shareCollection.totalInvestmentAmount;
        _shareCollections[_SHARE_COLLECTION_ID].withdrawn = true;

        TransferHelper.safeTransfer(
            intellSetting.intellTokenAddr(),
            msg.sender,
            __amount
        );

        emit Withdraw(msg.sender, _SHARE_COLLECTION_ID, __amount);
    }

    /* ============================================== */
    /* ================== For Admin ============== */
    /* ============================================== */

    /**
     * @dev Used to edit the token URI of an Edition.
     *
     * Emits a {EditionURIUpdated} event.
     *
     */
    function editURI(
        uint256 __shareCollectionId,
        string calldata __ipfsHash
    ) external {
        require(
            msg.sender == intellSetting.admin(),
            "THE CALLER MUST BE ADMIN"
        );

        require(
            _shareCollectionLaunched[__shareCollectionId],
            "NOT LAUNCHED YET!"
        );

        _shareCollections[__shareCollectionId].ipfsHash = __ipfsHash;

        emit CollectionURIUpdated(__shareCollectionId, __ipfsHash);
    }

    function setBlock(uint256 __shareCollectionId) external {
        require(
            msg.sender == intellSetting.admin(),
            "THE CALLER MUST BE ADMIN"
        );
        require(
            !_shareCollections[__shareCollectionId].blocked,
            "BLOCKED ALREADY!"
        );

        _shareCollections[__shareCollectionId].blocked = true;
    }

    function setUnblock(uint256 __shareCollectionId) external {
        require(
            msg.sender == intellSetting.admin(),
            "THE CALLER MUST BE ADMIN"
        );
        require(
            _shareCollections[__shareCollectionId].blocked,
            "UNBLOCKED ALREADY!"
        );

        _shareCollections[__shareCollectionId].blocked = false;
    }
}
