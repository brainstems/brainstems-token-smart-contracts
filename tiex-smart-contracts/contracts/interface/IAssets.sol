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

// TODO: update all comments
interface IAssets {
    // TODO: revise fields
    struct Metadata {
        string name;
        uint256 version;
        string description;
        bytes fingerprint;
        bool trained;
        bytes watermarkFingerprint;
        uint256 performance;
    }

    struct Contributors {
        address creator;
        address marketing;
        address presale;
        uint256 creatorRate;
        uint256 marketingRate;
        uint256 presaleRate;
    }

    // TODO: revise fields
    struct Asset {
        Metadata metadata;
        Contributors contributors;
        uint256 index;
        uint256 creatorIndex;
        string uri;
    }

    // TODO: revise all event fields

    event AssetCreated(
        address provider,
        uint256 indexed assetId,
        Asset asset,
        uint256 startTime
    );

    event AssetRemoved(
        address creator,
        address to,
        uint256 indexed assetId,
        uint256 removedTime
    );

    event AssetUriUpdated(uint256 indexed assetId, string ipfsHash);

    // Event emitted when an asset is upgraded
    event AssetUpgraded(uint256 indexed assetId, Metadata metadata);

    // Event emitted when the metadata of an asset is updated
    event AssetMetadataUpdated(uint256 indexed assetId, Metadata metadata);

    // TODO: revise error usage
    error InvalidCreator(address creator);

    error AssetAlreadyExists(uint256 assetId);

    // Error thrown when an invalid provider address is provided
    error InvalidProvider(address provider);

    // Error thrown when an out of bounds index is used for a creator
    error OutOfBounds(address creator, uint256 index);

    // Error thrown when a non-existent asset ID is used
    error AssetNotFound(uint256 assetId);

    // Error thrown when an invalid contribution rate is used
    error InvalidContributionRate(uint256 contributionRate);

    // Error thrown when an asset that is already trained is used
    error ModelAlreadyTrained(uint256 assetId);

    // Error thrown when invalid metadata is provided for an asset
    error InvalidMetadata(uint256 assetId);

    /// @notice Indicates that a share collection cannot be found
    error ErrorShareCollectionNotFound(uint256 modelId);

    /// @notice Indicates that a share collection with the specified
    /// model ID has already been released.
    error ErrorTIExShareCollectionReleasedAlready(uint256 modelId);

    /// @notice Indicates that there is not enough supply available for share sale.
    error ErrorNotEnoughSupply();

    /// @notice Indicates that a share collection with the specified model ID has been
    /// paused and is currently not available.
    error ErrorShareCollectionPaused(uint256 modelId);

    /// @notice Indicates that the share collection with the specified model ID is blocked.
    error ErrorShareCollectionBlocked(uint256 modelId);

    /// @notice Indicates that the TIEx is currently paused.
    error ErrorTIExPaused();

    /// @notice Indicates that the maximum limit for share purchases has been exceeded.
    error ErrorExceedMaxSharePurchase();

    /// @notice Indicates that the signature provided for authentication or verification
    /// purposes is invalid or cannot be verified.
    error ErrorInvalidSignature();

    /// @notice Indicates that one or more parameters provided in the request are invalid or missing.
    error ErrorInvalidParam();

    /// @notice Indicates that the provided nonce (a unique identifier) is invalid or has already been used.
    error ErrorInvalidNonce();

    // @notice Indicates that the deadline for a certain operation has been reached.
    error ErrorDeadlineReached();

    // @notice Indicates that the msg.sender() is invalid
    error ErrorInvalidMsgSender();

    /// @notice Emitted when the URI associated with a model is updated.
    event TIExCollectionURIUpdated(uint256 indexed modelId, string uri);

    /// @notice Emitted when the truth holder address is updated.
    event TIExTruthHolderUpdated(address newTruthHolder);

    /// @notice Emitted when the price of a share for a specific model is updated.
    event TIExSharePriceUpdated(uint256 indexed modelId, uint256 newPrice);

    /// @notice Emitted when the maximum supply of shares for a model is updated.
    event TIExMaxSupplyUpdated(uint256 indexed modelId, uint256 newMaxSupply);

    /// @notice Emitted when the maximum share purchase limit for a model is updated.
    event TIExMaxSharePurchaseUpdated(
        uint256 indexed modelId,
        uint256 newMaxSharePurchase
    );

    /// @notice Emitted when a share collection for a model is blocked or disabled.
    event TIExShareCollectionBlocked(uint256 indexed modelId);

    /// @notice Emitted when a previously blocked share collection for a model is unblocked or enabled.
    event TIExShareCollectionUnblocked(uint256 indexed modelId);

    /// @notice Emitted when a share collection for a model is paused.
    event TIExShareCollectionPaused(uint256 indexed modelId);

    /// @notice Emitted when a previously paused share collection for a model is unpaused.
    event TIExShareCollectionUnpaused(uint256 indexed modelId);

    /// @notice Emitted when the investor position of share collection is updated.
    /// e.g. U.S. investor => Non-U.S. investor or Non-U.S. investor => U.S. Investor
    event TIExShareCollectionInvestorPositionUpdated(
        uint256 indexed modelId,
        bool newInvestorPosition
    );

    /// @notice Emitted when the marketing address is update.
    event TIExMarketingAddressUpdated(address newMarketingAddress);

    /// @notice Emitted when the presale address is updated.
    event TIExPresaleAddressUpdated(address newPresaleAddress);

    /// @notice Emitted when reserve address is updated.
    event TIExReserveAddressUpdated(address newReserveAddress);

    /// @notice Emitted when distributing funds fromm investors to creators, marketing etc.
    event Distribute(uint256 indexed modelId, uint256 amount, uint256 when);

    /**
     * @notice Upgrades a stubbed model to a trained model.
     * @param assetId uint256 must exist.
     * @param fingerprint bytes is the new fingerprint of the model.
     *
     * Emits a {UpgradeModel} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must not be trained already.
     * - The `__newModelFingerprint` must not be empty.
     */
    // TODO: revise
    function upgradeStubbedModelToTrainedModel(
        uint256 assetId,
        bytes memory fingerprint
    ) external;

    /**
     * @notice Upgrades an asset by updating its fingerprint and incrementing its version.
     * @param assetId The ID of the asset to be upgraded.
     * @param fingerprint The new fingerprint of the asset.
     *
     * Emits an {UpgradeAsset} event.
     *
     * Requirements:
     * - The caller must have the `DEFAULT_ADMIN_ROLE`.
     * - The asset with the given `assetId` must exist.
     * - The `fingerprint` must not be empty.
     */
    function upgradeAsset(uint256 assetId, bytes memory fingerprint) external;

    /**
     * @notice Updates the metadata of a model.
     * @param assetId The ID of the model to be updated.
     * @param metadata The new metadata of the model.
     *
     * Emits an {UpdateModelMetadata} event.
     *
     * Requirements:
     * - The caller must have the `DEFAULT_ADMIN_ROLE`.
     * - The model with the given `__modelId` must exist.
     * - The `__modelMetadata` must be valid.
     */
    function updateAssetMetadata(
        uint256 assetId,
        Metadata calldata metadata
    ) external;

    /**
     * @notice Allocates `modelId` as TIEx IP to `creator`.
     * @param assetId uint256 must not exist.
     * @param ipfsHash string is for Metadata of model
     *
     * Emits a {AllocateTIExIP} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must not exist.
     */
    function createAsset(
        uint256 assetId,
        Contributors calldata contributors,
        string calldata ipfsHash,
        Metadata calldata metadata
    ) external;

    /**
     * @notice Used to edit the model URI.
     *
     * Emits a {TIExModelURIUpdated} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must exist.
     */
    function editUri(uint256 assetId, string calldata ipfsHash) external;

    /**
     * @notice Used to get the detail of model
     * @param assetId uint256 must exist
     */
    function getAsset(uint256 assetId) external view returns (Asset memory);

    /**
     * @notice Returns the number of models in ``creator``'s account.
     */
    function assetBalanceOf(address creator) external view returns (uint256);

    /**
     * @notice Returns the creator of the `modelId` model.
     * @param assetId uint256 ID of the model must exist.
     */
    function creatorOf(uint256 assetId) external view returns (address);

    /**
     * @notice Returns whether `__modelId` exists.
     *
     * Models start existing when TIEx are allocated,
     * and stop existing when TIEx are removed (`removeModel`).
     */
    function assetExists(uint256 assetId) external view returns (bool);

    /**
     * @notice Returns a model ID owned by `creator` at a given `index` of its model list.
     * Use along with {modelBalanceOf} to enumerate all of ``creator``'s models.
     */
    function creatorAssetByIndex(
        address creator,
        uint256 index
    ) external view returns (uint256);

    /**
     * @notice Returns the total amount of models stored by the contract.
     */
    function assetAmount() external view returns (uint256);

    /**
     * @notice Returns a model ID at a given `index` of all the models stored by the contract.
     * Use along with {totalModelSupply} to enumerate all models.
     */
    function assetByIndex(uint256 index) external view returns (uint256);

    /**
     * @notice Returns model ids allocated from account of creator.
     */
    function assetsByCreator(
        address creator
    ) external view returns (uint256[] memory);
}
