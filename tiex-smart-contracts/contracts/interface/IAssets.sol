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
    event AssetRatesUpdated(
        uint256 indexed id,
        uint256 creatorRate,
        uint256 marketingRate,
        uint256 presaleRate
    );
    event AssetEarningsDeposited(
        uint256 indexed id,
        uint256 creatorAmount,
        uint256 marketingAmount,
        uint256 presaleAmount
    );
    event AssetEarningsWithdrawn(
        uint256 indexed id,
        address indexed contributor,
        uint256 amount
    );

    /**
     * @notice Registers an asset in the contract.
     * @param assetId identifier for the asset.
     * @param baseAsset identifier for the asset used as a basis for the one being registered, if it exists.
     * @param contributors addresses to identify the asset creator, the marketing role and the presale roles, each with their own contribution rates.
     * @param ipfsHash asset URI in the form of an IPFS hash to store additional data.
     * @param metadata asset metadata that needs to go on-chain, unlike the data stored on IPFS.
     */
    function createAsset(
        uint256 assetId,
        uint256 baseAsset,
        Contributors calldata contributors,
        string calldata ipfsHash,
        Metadata calldata metadata
    ) external;

    /**
     * @notice Upgrades an asset.
     * @param assetId identifier for the asset.
     * @param metadata updated asset metadata.
     */
    function upgradeAsset(uint256 assetId, Metadata memory metadata) external;

    /**
     * @notice Used to edit the asset URI, expected to be in the form of an IPFS hash.
     */
    function editUri(uint256 assetId, string calldata ipfsHash) external;

    /**
     * @notice Returns the detailed asset identified by the provided id.
     */
    function getAsset(uint256 assetId) external view returns (Asset memory);

    /**
     * @notice Returns the creator of the asset identified by the provided id.
     */
    function creatorOf(uint256 assetId) external view returns (address);

    /**
     * @notice Returns whether the asset identified by the provided id exists.
     */
    function assetExists(uint256 assetId) external view returns (bool);

    /**
     * @notice Returns the total amount of models stored by the contract.
     */
    function assetAmount() external view returns (uint256);
}
