const ethers = require("ethers");
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const toWei = (num) => ethers.utils.parseEther(num.toString())
const fromWei = (num) => ethers.utils.formatEther(num)


const leafNodes = [

  { "address": "0x4ABda0097D7545dE58608F7E36e0C1cac68b4943", "balance": 400 },

  { "address": "0x00000005Fa950023724931D2EcbA50bE1688abFf", "balance": 11500 },

  { "address": "0x70997970c51812dc3a010c7d01b50e0d17dc79c8", "balance": 7500 },

  { "address": "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc", "balance": 11000 },

  { "address": "0x0000000a8dEA75E8f8000BF18C22948c7EAb3b9D", "balance": 8500 },

  { "address": "0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199", "balance": 10500 }

]

const tokenAirdropSum = leafNodes.map(m => m.balance).reduce((previousValue, currentValue) => previousValue + currentValue, 0);

const arr = leafNodes.map((i, ix) => {
  const packed = ethers.utils.solidityPack(["address", "uint256"], [i.address, toWei(i.balance)])
  return keccak256(packed);
});

// Generate merkleTree from leafNodes

const merkleTree = new MerkleTree(arr, keccak256, { sortPairs: true });

// Get root hash from merkle tree

const rootHash = merkleTree.getHexRoot();
const proofs = arr.map(arrr => merkleTree.getHexProof(arrr))

console.log(rootHash)
console.log(proofs)

