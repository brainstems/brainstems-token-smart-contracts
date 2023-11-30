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

pragma solidity ^0.8.7;

interface IMembership {
    struct Ecosystem {
        uint256 id;
        string name;
    }

    // company
    struct Member {
        uint256 id;
        string name;
    }

    function createEcosystem(Ecosystem calldata ecosystem) external;

    function createCompany(Member calldata member) external;

    function addMember(uint256 ecosystemId, uint256 memberId) external;

    function removeMember(uint256 ecosystemId, uint256 memberId) external;

    function addUser(
        uint256 ecosystemId,
        uint256 memberId,
        address user
    ) external;

    function removeUser(
        uint256 ecosystemId,
        uint256 memberId,
        address user
    ) external;
}
