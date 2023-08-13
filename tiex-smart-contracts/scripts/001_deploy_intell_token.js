// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { green } = require("console-log-colors");
const { parseUnits } = require("../test/helper");
const prompt = require("prompt-sync")({ sigint: true });

async function main() {
  console.log(green("******** Deploy IntellTokenContract.sol*********"));

  while (1) {
    let recipient = prompt("Recipient wallet address (multi-sig): ");

    const isAddress = hre.ethers.utils.isAddress(recipient);
    if (isAddress) {
      recipient = hre.ethers.utils.getAddress(recipient);
      const IntelligenceInvestmentToken = await hre.ethers.getContractFactory(
        "IntelligenceInvestmentToken"
      );
      const intelligenceInvestmentToken =
        await IntelligenceInvestmentToken.deploy(recipient);

      await intelligenceInvestmentToken.deployed();
      console.log(green(`Deployed to ${intelligenceInvestmentToken.address}`));

      try {
        await hre.run("verify:verify", {
          address: intelligenceInvestmentToken.address,
          constructorArguments: [recipient],
        });
      } catch (error) {
        console.log(error);
      }

      break;
      
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// const prompt = require('prompt-sync')({sigint: true});

// // Random number from 1 - 10
// const numberToGuess = Math.floor(Math.random() * 10) + 1;
// // This variable is used to determine if the app should continue prompting the user for input
// let foundCorrectNumber = false;

// while (!foundCorrectNumber) {
//   // Get user input
//   let guess = prompt('Guess a number from 1 to 10: ');
//   // Convert the string input to a number
//   guess = Number(guess);

//   // Compare the guess to the secret answer and let the user know.
//   if (guess === numberToGuess) {
//     console.log('Congrats, you got it!');
//     foundCorrectNumber = true;
//   } else {
//     console.log('Sorry, guess again!');
//   }
// }
