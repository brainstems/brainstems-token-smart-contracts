const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");
const { config } = require("hardhat");

const DECIMALS = 18;
const parseUnits = (__num) =>
  ethers.utils.parseUnits(__num.toString(), DECIMALS);

const hexToDecimal = (hex) => parseInt(hex, 16);

const bigNumberToDecimal = (bigNumber) => hexToDecimal(bigNumber._hex, 16);

const getHardhatPrivateKey = (index) => {
  const accounts = config.networks.hardhat.accounts;
  const wallet = ethers.Wallet.fromMnemonic(
    accounts.mnemonic,
    accounts.path + `/${index}`
  );

  return wallet.privateKey;
};

module.exports = {
  parseUnits,
  DECIMALS,
  hexToDecimal,
  bigNumberToDecimal,
  getHardhatPrivateKey
};

// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.8;
 

// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "hardhat/console.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
  

// contract AirDropper is Ownable, ReentrancyGuard {  

// � � using SafeERC20 for IERC20;  

// � � bytes32 public immutable root;

// � � address tokenAddress ;

// � � mapping(address => bool) claimed;  

// � � constructor(bytes32 _root, address token) {
// � � � � root = _root;
// � � � � tokenAddress=token;
// � � }  

// � � function hasClaimed() external view returns (bool) {
// � � � � return _hasClaimed(msg.sender);
// � � }

// 	function _hasClaimed(address user) private view �returns (bool) {
// � � � � return claimed[user];
// � � }

// � � function claim(bytes32[] calldata _proof, uint amount) external nonReentrant {

// � � � � address claimer = msg.sender;
// � � � � require(!claimed[claimer], "Already claimed air drop");
// � � � � claimed[claimer] = true;
// � � � � bytes32 _leaf = keccak256(abi.encodePacked(claimer, amount));
// � � � � require(
// � � � � � � MerkleProof.verify(_proof, root, _leaf),
// � � � � � � "Incorrect merkle proof"
// � � � � );
// � � � � require( IERC20(tokenAddress).balanceOf(address(this)) > amount, 'AIRDROP CLAIM: No token to release by airdropper');
// � � � � IERC20(tokenAddress).safeTransfer(claimer, amount);
// � � }
// }
// const { ethers } = require("hardhat");

// const { MerkleTree } = require('merkletreejs');

// const keccak256 = require('keccak256');

// const toWei = (num) => ethers.utils.parseEther(num.toString())

// const fromWei = (num) => ethers.utils.formatEther(num)

// const tokenAddress = 'tokenAddress';

// const leafNodes = [

// {"address": "0x4ABda0097D7545dE58608F7E36e0C1cac68b4943", "balance": 400},

// {"address": "0x00000005Fa950023724931D2EcbA50bE1688abFf", "balance":11500},

// {"address":"0x70997970c51812dc3a010c7d01b50e0d17dc79c8","balance":7500},

// {"address":"0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc","balance":11000},

// {"address":"0x0000000a8dEA75E8f8000BF18C22948c7EAb3b9D","balance":8500},

// {"address":"0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199","balance":10500}

// ]

// const tokenAirdropSum = leafNodes.map(m=>m.balance).reduce( (previousValue, currentValue) => previousValue + currentValue, 0);

// const arr = leafNodes.map((i,ix) => {
// 	const packed = ethers.utils.solidityPack(["address", "uint256"], [ i.address, toWei(i.balance)])	
// 	return keccak256(packed);
// });

// // Generate merkleTree from leafNodes

// const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

// // Get root hash from merkle tree

// const rootHash = merkleTree.getRoot()

// module.exports = async ({ getNamedAccounts, deployments }) => {

// 	const { deploy } = deployments;
	
// 	const { deployer } = await getNamedAccounts();
	
// 	await deploy("AirDropper", {
	
// 		from: deployer,
		
// 		args: [rootHash, tokenAddress],
		
// 		log: true,
	
// 	});

// };

// module.exports.tags = ["AirDropper"];