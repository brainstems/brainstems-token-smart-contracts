// SPDX-License-Identifier: MIT

        /*.----------------.  .----------------.  .----------------.  .----------------. 
        | .--------------. || .--------------. || .--------------. || .--------------. |
        | |  _________   | || |     _____    | || |  _________   | || |  ____  ____  | |
        | | |  _   _  |  | || |    |_   _|   | || | |_   ___  |  | || | |_  _||_  _| | |
        | | |_/ | | \_|  | || |      | |     | || |   | |_  \_|  | || |   \ \  / /   | |
        | |     | |      | || |      | |     | || |   |  _|  _   | || |    > `' <    | |
        | |    _| |_     | || |     _| |_    | || |  _| |___/ |  | || |  _/ /'`\ \_  | |
        | |   |_____|    | || |    |_____|   | || | |_________|  | || | |____||____| | |
        | |              | || |              | || |              | || |              | |
        | '--------------' || '--------------' || '--------------' || '--------------' |
        '----------------'  '----------------'  '----------------'  '----------------' */

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TIExBaseIPAllocationUpgradeable.sol";

contract TIExShareCollections is
    Initializable,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155SupplyUpgradeable,
    PausableUpgradeable,
    TIExBaseIPAllocationUpgradeable
    
{
    using Strings for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct TIExShareCollection {
        uint256 maxSupply; // maximum share supply
        uint256 totalInvestment; // total investment (INTELL token)
        uint256 withdrawnAmount; // amount withdrawn
        uint256 price; // price per share (INTELL token)
        uint256 launchStartTime; // when launched
        uint256 maxSharePurchase; // maximum share purchase per account
        bool paused; // whether sale paused or not
        bool blocked; // whether the share collection is availabe to trade or not
        bool forOnlyUSInvestors; // whether it's for only U.S investors or not
    }

    error ErrorTIExShareCollectionNotFound();
    error ErrorTIExShareCollectionReleasedAlready(uint256 modelId);
    error ErrorNotEnoughSupply();
    error ErrorShareCollectionPaused(uint256 modelId);
    error ErrorShareCollectionNotExistsOrBlocked(uint256 modelId);
    error ErrorExceedMaxSharePurchase();
    error ErrorInvalidSignature();
    error ErrorInvalidCountry();
    error ErrorInvalidAmount();
    error ErrorInvalidParam();
    error ErrorInvalidNonce();

    event TIExShareCollectionReleased(uint256 __modelId, TIExShareCollection __shareCollection);
    event TIExCollectionURIUpdated(uint256 __modelId, string __uri);
    event TIExShareCollectionUpdated(uint256 __modelId, TIExShareCollection oldShareCollection, TIExShareCollection newShareCollection);
    event TIExPaymentTokenUpdated(IERC20 oldPaymentToken, IERC20 newPaymentToken);
    event TIExTruthHolderUpdated(address oldTruthHolder, address newTruthHolder);
    event TIExSharePriceUpdated(uint256 __modelId, uint256 __oldPrice, uint256 __newPrice);
    event TIExMaxSupplyUpdated(uint256 __modelId, uint256 __oldMaxSupply, uint256 __newMaxSupply);
    event TIExMaxSharePurchaseUpdated(uint256 __modelId, uint256 __oldMaxSharePurchase, uint256 __newMaxSharePurchase);
    event TIExShareCollectionBlocked(uint256 __modelId);
    event TIExShareCollectionUnblocked(uint256 __modelId);
    event TIExShareCollectionPaused(uint256 __modelId);
    event TIExShareCollectionUnpaused(uint256 __modelId);
    event TIExInvestorPositionUpdated(uint256 __modelId, bool __oldInvestorPosition, bool __newInvestorPosition);

    // The token name
    string public name;

    // The token symbol
    string public symbol;

    // Mapping of share collctions
    mapping(uint256 => TIExShareCollection) private _shareCollections;

    // Mapping of share collection released
    mapping(uint256 => bool) private _shareCollectionExists;

    // Mapping the number of shares purchased per account in every share collection
    mapping(uint256 => mapping(address => uint256)) public purchasedPerAccount;

    // The truth holder
    address public truthHolder;

    // The payment token (ERC20: INTELL token)
    IERC20 public paymentToken;

    // Mapping nonce used
    mapping(uint256 => bool) public nonceUsed;


    /**
     * @notice Sets name/symbol/truth holder/payment token and grants initial roles to owner upon construction.
     */
    function initialize(address __truthHolder, IERC20 __paymentToken, address __admin) public virtual initializer {

        name = "TIEx Share Collections";
        symbol = "TIExSHARE";

        truthHolder = __truthHolder;
        paymentToken = __paymentToken;

        __TIExBaseIPAllocation_init();
        __Context_init_unchained();
		__ERC165_init_unchained();
		__ERC1155_init_unchained("");
		__ERC1155Burnable_init_unchained();
		__Pausable_init_unchained();
        __TIExBaseIPAllocation_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, __admin);
    }



    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////
    
    /**
    * @notice Checks if modelId not paused
    * @param __modelId uint256 must be of existing Share Collection
    *
    */
    modifier whenShareCollectionNotPaused(uint256 __modelId) {
        if (_shareCollections[__modelId].paused) {
            revert ErrorShareCollectionPaused(__modelId);
        }
        _;
    }

    /**
    * @notice Checks if modelIds exist and not blocked batch
    * @param __modelIds uint256[] must be of existing Share Collections
    *
    */
    modifier whenShareCollectionsExistAndNotBlockedBatch(uint256[] memory __modelIds) {
        for (uint256 i = 0; i < __modelIds.length; i++) {
            if (_shareCollections[__modelIds[i]].blocked || !shareCollectionExists(__modelIds[i]))
                revert ErrorShareCollectionNotExistsOrBlocked(__modelIds[i]);
        }
        _;
    }

    /**
     * @notice Checks if Share Collection exists.
     * @param __modelId must be of existing Share Collection.
     */
    modifier onlyExistingShareCollection(uint256 __modelId) {
        if (!shareCollectionExists(__modelId)) {
            revert ErrorTIExShareCollectionNotFound();
        }
        _;
    }

    /**
     * @notice Checks if Share Collection doesn't exist.
     * @param __modelId uint256 must be of existing Share Collection.
     */
    modifier onlyNotExistingShareCollection(uint256 __modelId) {
        if (shareCollectionExists(__modelId)) {
            revert ErrorTIExShareCollectionReleasedAlready(__modelId);
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    ////////////////////////////////////////////////////////////////////////////

    function _beforeTokenTransfer(
        address __operator,
        address __from,
        address __to,
        uint256[] memory __modelIds,
        uint256[] memory __amounts,
        bytes memory __data
    )
        internal
        virtual
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
        whenNotPaused
        whenShareCollectionsExistAndNotBlockedBatch(__modelIds)
    {
        super._beforeTokenTransfer(
            __operator,
            __from,
            __to,
            __modelIds,
            __amounts,
            __data
        );
    }

    /**
     * @notice See { TIExBaseIPAllocationUpgradeable }
     *
     */

    function _afterRemoveModel(uint256 __modelId) internal virtual override(TIExBaseIPAllocationUpgradeable) {
        if(_shareCollectionExists[__modelId]) {
            _shareCollectionExists[__modelId] = false;
            delete _shareCollections[__modelId];
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Used to release a new Share Collection.
     * @param __maxSupply uint256 must be great more than 0
     * @param __price uint256 must be great more than 0
     * @param __maxSharePurchase uint256 must be great more than 0
     * @param __forOnlyUSInvestors bool the position of investor
     * Emits a {TIExShareCollectionReleased} event.
     *
     */
    function releaseShareCollection(
        uint256 __maxSupply,
        uint256 __modelId,
        uint256 __price,
        uint256 __maxSharePurchase,
        bool __forOnlyUSInvestors
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyNotExistingShareCollection(__modelId)
        onlyExistingModelId(__modelId)
    {
        if (__maxSupply > 0 && __price > 0 && __maxSharePurchase > 0) {
            _shareCollections[__modelId] = TIExShareCollection({
                maxSupply: __maxSupply,
                totalInvestment: 0,
                withdrawnAmount: 0,
                price: __price,
                launchStartTime: block.timestamp,
                paused: true,
                blocked: false,
                forOnlyUSInvestors: __forOnlyUSInvestors,
                maxSharePurchase: __maxSharePurchase
            });

            _shareCollectionExists[__modelId] = true;

            emit TIExShareCollectionReleased(__modelId, _shareCollections[__modelId]);
        } else revert ErrorInvalidParam();
    }

    /**
    * @notice Updates truth holder address
    */
    function updateTruthHolder(address __truthHolder) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(__truthHolder == address(0) || __truthHolder == truthHolder) revert ErrorInvalidParam();
        emit TIExTruthHolderUpdated(truthHolder, __truthHolder);
        truthHolder = __truthHolder;
    }

    /**
    * @notice Updates payment token 
    */
    function updatePaymentToken(IERC20 __paymentToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(address(__paymentToken) == address(0) || address(paymentToken) == address(__paymentToken)) revert ErrorInvalidParam();
        emit TIExPaymentTokenUpdated(paymentToken, __paymentToken);
        paymentToken = __paymentToken;
    }

    /**
    * @notice Pauses selling shares
    */
    function setPause(uint256 __modelId) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId) {
        if(_shareCollections[__modelId].paused) revert ErrorInvalidParam();
        _shareCollections[__modelId].paused = true;
        emit TIExShareCollectionPaused(__modelId);
    }

    /**
    * @notice Unpauses selling shares
    */
    function setUnpause(uint256 __modelId) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId) {
        if(!_shareCollections[__modelId].paused) revert ErrorInvalidParam();
        _shareCollections[__modelId].paused = false;
        emit TIExShareCollectionUnpaused(__modelId);
    }

    /**
    * @notice Blocks a share collection
    */
    function setBlock(uint256 __modelId) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId) {
        if(_shareCollections[__modelId].blocked) revert ErrorInvalidParam();
        _shareCollections[__modelId].blocked = true;
        emit TIExShareCollectionBlocked(__modelId);
    }

    /**
    * @notice Unblocks a share collection
    */
    function setUnblock(uint256 __modelId) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId) {
        if(!_shareCollections[__modelId].blocked) revert ErrorInvalidParam();
        _shareCollections[__modelId].blocked = false;
        emit TIExShareCollectionUnblocked(__modelId);
    }

    /**
    * @notice Updates the price per share
    */
    function updateSharePrice(uint256 __modelId, uint256 __price) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId)  {
        if (__price == 0 || __price == _shareCollections[__modelId].price) revert ErrorInvalidParam();
        emit TIExSharePriceUpdated(__modelId, _shareCollections[__modelId].price, __price);
        _shareCollections[__modelId].price = __price;
    }

    /**
    * @notice Updates maxSupply 
    */
    function updateMaxSupply(uint256 __modelId, uint256 __maxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId)  {
        if (__maxSupply == 0 || __maxSupply == _shareCollections[__modelId].maxSupply) revert ErrorInvalidParam();
        emit TIExMaxSupplyUpdated(__modelId, _shareCollections[__modelId].maxSupply, __maxSupply);
        _shareCollections[__modelId].maxSupply = __maxSupply;
    }

    /**
    * @notice Updates maxSharePurchase
    */
    function updateMaxSharePurchase(uint256 __modelId, uint256 __maxSharePurchase) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId)  {
        if (__maxSharePurchase == 0 || __maxSharePurchase == _shareCollections[__modelId].maxSharePurchase) revert ErrorInvalidParam();
        emit TIExMaxSharePurchaseUpdated(__modelId, _shareCollections[__modelId].maxSharePurchase, __maxSharePurchase);
        _shareCollections[__modelId].maxSharePurchase = __maxSharePurchase;
    }

    /**
    * @notice Updates the available position for investors
    */
    function updateInvestorPosition(uint256 __modelId, bool __forOnlyUSInvestors) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingShareCollection(__modelId) {
        if(__forOnlyUSInvestors == _shareCollections[__modelId].forOnlyUSInvestors) revert ErrorInvalidParam();
        emit TIExInvestorPositionUpdated(__modelId, _shareCollections[__modelId].forOnlyUSInvestors, __forOnlyUSInvestors);
        _shareCollections[__modelId].forOnlyUSInvestors = __forOnlyUSInvestors;
    }

    /**
    * @notice Resumes operating the platform
    */
    function resume() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
    * @notice Pauses operating the platform  
    */
    function emergency() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    ////////////////////////////////////////////////////////////////////////////
    // MINTER
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Used to mint token(s) for a one account.
     * @param __modelId uint256 must exist
     * @param __amount uint256 must be great more than 0
     *
     */
    function buyShares(
        uint256 __modelId,
        uint256 __amount,
        uint256 __nonce,
        bool __usInvestor,
        bytes calldata __signature
    )
        external
        whenShareCollectionNotPaused(__modelId)
    {
        // abi: [address, bool, bool, address, string], [account, approved, usInvestor, to, actionName]
        bytes memory message = abi.encode(msg.sender, true, __usInvestor, address(this), __nonce);
        uint256 paymentTokenAmount = _shareCollections[__modelId].price.mul(__amount);

        if (nonceUsed[__nonce]) revert ErrorInvalidNonce();
        if (__amount == 0) revert ErrorInvalidAmount();
        if (!verifyMessage(message, __signature)) revert ErrorInvalidSignature();
        if (__usInvestor != _shareCollections[__modelId].forOnlyUSInvestors) revert ErrorInvalidCountry();
        if (totalSupply(__modelId).add(__amount) > _shareCollections[__modelId].maxSupply) revert ErrorNotEnoughSupply();
        if (purchasedPerAccount[__modelId][msg.sender].add(__amount) > _shareCollections[__modelId].maxSharePurchase) revert ErrorExceedMaxSharePurchase();

        nonceUsed[__nonce] = true;
        paymentToken.safeTransferFrom(msg.sender, address(this), paymentTokenAmount);
        _shareCollections[__modelId].totalInvestment = _shareCollections[__modelId].totalInvestment.add(paymentTokenAmount);
        purchasedPerAccount[__modelId][msg.sender] += __amount;
        _mint(msg.sender, __modelId, __amount, "");

    }

    ////////////////////////////////////////////////////////////////////////////
    // READS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns whether or not an shareCollection exists.
     */
    function shareCollectionExists(uint256 __modelId)
        public
        view
        returns (bool)
    {
        if (_shareCollectionExists[__modelId]) {
            return true;
        }
        return false;
    }

    /**
     * @notice Returns an Share Collection Status.
     
     */
    function shareCollection(uint256 __modelId)
        external
        view
        onlyExistingShareCollection(__modelId)
        returns (TIExShareCollection memory, string memory)
    {
        return (_shareCollections[__modelId], string(abi.encodePacked("ipfs://", _modelURIs[__modelId])));
    }

    /**
     * @notice Returns the model URI.
     *
     */
    function uri(uint256 __modelId)
        public
        view
        override
        onlyExistingModelId(__modelId)
        returns (string memory)
    {
        return string(abi.encodePacked("ipfs://", _modelURIs[__modelId]));
    }

    /**
     * @notice See {ERC1155-supportsInterface} and {AccessControl-supportsInterface}.
     *
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    ////////////////////////////////////////////////////////////////////////////
    // PRIVATES
    ////////////////////////////////////////////////////////////////////////////

    // Verifies bytes message
    function verifyMessage(
        bytes memory message,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 hash = keccak256(message);
        return recoverSigner(hash, signature) == truthHolder;
    }

    // Recovers signer
    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) private pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    ////////////////////////////////////////////////////////////////////////////
    // CREATORS
    ////////////////////////////////////////////////////////////////////////////
    
    // function withdraw(uint256 __modelId) external onlyExistingShareCollection(__modelId) whenNotPaused whenShareCollectionNotPaused(__modelId) {}
}
