// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IIntellSetting {
    function admin() external view returns(address);
    function truthHolder() external view returns(address);
    function intellShareCollectionLaunchPrice() external view returns(uint256);
    function intellTokenAddr() external view returns(address);
    function intellShareCollectionContractAddr() external view returns(address);
    function intellModelNFTContractAddr() external view returns(address);
    function modelRegisterationPrice() external view returns(uint256);
}