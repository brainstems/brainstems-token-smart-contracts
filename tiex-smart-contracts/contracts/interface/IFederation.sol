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

interface IFederation {
    struct Federation {
        uint256 id;
        uint256 name;
    }

    function createFederation(
        Federation calldata federation,
        uint256[] calldata companyIds
    ) external;

    function registerAsset(uint256 federationId, uint256 assetId) external;
}
