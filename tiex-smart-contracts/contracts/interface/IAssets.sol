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

interface IAssets {
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

    struct Asset {
        uint256 baseAsset;
        Metadata metadata;
        Contributors contributors;
        string uri;
    }

    event AssetCreated(uint256 indexed id, Asset asset);
    event AssetUriUpdated(uint256 indexed id, string ipfsHash);
    event AssetUpgraded(uint256 indexed id, Metadata metadata);
    event AssetMarketingAddressUpdated(uint256 indexed id, address marketing);
    event AssetPresaleAddressUpdated(uint256 indexed id, address presale);
    event Distribute(uint256 indexed modelId, uint256 amount, uint256 when);

    error InvalidCreator(address creator);
    error AssetAlreadyExists(uint256 assetId);
    error InvalidProvider(address provider);
    error OutOfBounds(address creator, uint256 index);
    error AssetNotFound(uint256 assetId);
    error InvalidContributionRate(uint256 contributionRate);
    error ModelAlreadyTrained(uint256 assetId);
    error InvalidMetadata(uint256 assetId);
    error ErrorShareCollectionNotFound(uint256 modelId);
    error ErrorTIExShareCollectionReleasedAlready(uint256 modelId);
    error ErrorNotEnoughSupply();
    error ErrorShareCollectionPaused(uint256 modelId);
    error ErrorShareCollectionBlocked(uint256 modelId);
    error ErrorTIExPaused();
    error ErrorExceedMaxSharePurchase();
    error ErrorInvalidSignature();
    error ErrorInvalidParam();
    error ErrorInvalidNonce();
    error ErrorDeadlineReached();
    error ErrorInvalidMsgSender();
    event TIExCollectionURIUpdated(uint256 indexed modelId, string uri);

    /**
     * @notice Upgrades an asset by updating its fingerprint and incrementing its version.
     * @param assetId The ID of the asset to be upgraded.
     * @param metadata The new fingerprint of the asset.
     *
     * Emits an {UpgradeAsset} event.
     *
     * Requirements:
     * - The caller must have the `DEFAULT_ADMIN_ROLE`.
     * - The asset with the given `assetId` must exist.
     * - The `fingerprint` must not be empty.
     */
    function upgradeAsset(uint256 assetId, Metadata memory metadata) external;

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
        uint256 baseAsset,
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
     * @notice Returns the total amount of models stored by the contract.
     */
    function assetAmount() external view returns (uint256);
}
