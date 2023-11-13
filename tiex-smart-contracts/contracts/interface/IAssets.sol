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
    // TODO: update all comments

    // Struct to represent a contribution to a model
    // TODO: revise
    struct Contribution {
        uint256 modelId; // The ID of the model
        uint256 contributionRate; // The rate of the contribution
    }

    // Struct to represent the metadata of an asset
    struct Metadata {
        string name;
        uint256 version;
        string description;
        bytes fingerprint;
        bool trained; // Whether the model is trained or not
        bytes watermark; // The fingerprint of the watermark
        // TODO: revise
        uint256 performance; // The performance of the model
    }

    struct Asset {
        address creator;
        Contribution[] contributedModels;
        Metadata metadata;
        uint256 allAssetsIndex;
        uint256 ownedAssetsIndex;
        string uri;
    }

    // Event emitted when a new IP is allocated to a creator
    // TODO: revise provider
    event AllocateIP(
        address provider,
        uint256 indexed assetId,
        Asset asset,
        uint256 startTime
    );

    // Event emitted when an IP is removed
    event RemoveIP(
        address creator,
        address to,
        uint256 indexed assetId,
        uint256 removedTime
    );

    // Event emitted when the URI of an asset is updated
    event assetUriUpdated(uint256 indexed assetId, string ipfsHash);

    // Event emitted when the contribution rates of a model are updated
    event ContributationRatesUpdated(
        uint256 indexed modelId,
        Contribution[] contributionRates
    );

    // Event emitted when an asset is upgraded
    event UpgradeAsset(uint256 indexed assetId, Metadata metadata);

    // Event emitted when the metadata of an asset is updated
    event UpdateAssetMetadata(uint256 indexed assetId, Metadata metadata);

    // Error thrown when an invalid creator address is provided
    error ErrorInvalidCreator(address creator);

    // Error thrown when an asset ID that is already allocated is used
    error ErrorAlreadyAllocated(uint256 assetId);

    // Error thrown when an invalid provider address is provided
    error ErrorInvalidProvider(address provider);

    // Error thrown when an out of bounds index is used for a creator
    error ErrorOutOfBounds(address creator, uint256 index);

    // Error thrown when a non-existent asset ID is used
    error ErrorAssetNotFound(uint256 assetId);

    // Error thrown when an invalid contribution rate is used
    error ErrorInvalidContributionRate(uint256 contributionRate);

    // Error thrown when an asset that is already trained is used
    error ErrorAlreadyTrained(uint256 assetId);

    // Error thrown when invalid metadata is provided for an asset
    error ErrorInvalidMetadata(uint256 assetId);

    // TODO: revise
    /**
     * @notice Upgrades a stubbed model to a trained model.
     * @param __modelId uint256 must exist.
     * @param __newModelFingerprint bytes is the new fingerprint of the model.
     *
     * Emits a {UpgradeModel} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must not be trained already.
     * - The `__newModelFingerprint` must not be empty.
     */
    function upgradeStubbedModelToTrainedModel(
        uint256 __modelId,
        bytes memory __newModelFingerprint
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
     * @param __modelId The ID of the model to be updated.
     * @param __modelMetadata The new metadata of the model.
     *
     * Emits an {UpdateModelMetadata} event.
     *
     * Requirements:
     * - The caller must have the `DEFAULT_ADMIN_ROLE`.
     * - The model with the given `__modelId` must exist.
     * - The `__modelMetadata` must be valid.
     */
    function updateModelMetadata(
        uint256 __modelId,
        Metadata calldata __modelMetadata
    ) external;

    /**
     * @notice Allocates `modelId` as TIEx IP to `creator`.
     * @param __modelId uint256 must not exist.
     * @param __creator address cannot be the zero address.
     * @param __ipfsHash string is for Metadata of model
     * @param __contributors Contribution struct is for contribution rate of each model
     *
     * Emits a {AllocateTIExIP} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must not exist.
     */
    function giveCreatorTIExIP(
        uint256 __modelId,
        address __creator,
        string calldata __ipfsHash,
        Contribution[] calldata __contributors,
        Metadata calldata __modelMetadata
    ) external;

    /**
     * @notice Updates the contribution rates of a model.
     *
     * Emits a {ContributationRatesUpdated} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must exist.
     */
    function updateContributionRates(
        uint256 __modelId,
        Contribution[] calldata __contributors
    ) external;

    /**
     * @notice Destroys `modelId`.
     * @param __modelId must exist.
     *
     * Emits a {RemoveTIExIP} event.
     *
     * Requirement:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     */
    function removeModel(uint256 __modelId) external;

    /**
     * @notice Used to edit the model URI.
     *
     * Emits a {TIExModelURIUpdated} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must exist.
     */
    function editURI(uint256 __modelId, string calldata __ipfsHash) external;

    /**
     * @notice Used to get the detail of model
     * @param __modelId uint256 must exist
     */
    function getAsset(uint256 __modelId) external view returns (Asset memory);

    /**
     * @notice Returns the number of models in ``creator``'s account.
     */
    function assetBalanceOf(address __creator) external view returns (uint256);

    /**
     * @notice Returns the creator of the `modelId` model.
     * @param __modelId uint256 ID of the model must exist.
     */
    function creatorOf(uint256 __modelId) external view returns (address);

    /**
     * @notice Returns whether `__modelId` exists.
     *
     * Models start existing when TIEx are allocated,
     * and stop existing when TIEx are removed (`removeModel`).
     */
    function modelExists(uint256 __modelId) external view returns (bool);

    /**
     * @notice Returns a model ID owned by `creator` at a given `index` of its model list.
     * Use along with {modelBalanceOf} to enumerate all of ``creator``'s models.
     */
    function modelOfCreatorByIndex(
        address __creator,
        uint256 __index
    ) external view returns (uint256);

    /**
     * @notice Returns the total amount of models stored by the contract.
     */
    function totalModelSupply() external view returns (uint256);

    /**
     * @notice Returns a model ID at a given `index` of all the models stored by the contract.
     * Use along with {totalModelSupply} to enumerate all models.
     */
    function modelByIndex(uint256 __index) external view returns (uint256);

    /**
     * @notice Returns model ids allocated from account of creator.
     */
    function modelsOfCreator(
        address __creator
    ) external view returns (uint256[] memory);
}
