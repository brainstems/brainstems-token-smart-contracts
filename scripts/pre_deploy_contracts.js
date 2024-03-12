const { exec } = require("child_process");
const minimist = require("minimist");
const argv = minimist(process.argv.slice(2));
const args = argv._;

// Parse arguments
if (!args.includes("--network")) {
  console.error("No network specified. Use the --network flag to specify one.");
  process.exit(1);
}

const env = {
  DEPLOY_TOKEN: args.includes("-token"),
  ...process.env, // Include existing environment variables
};

// Prepare the Hardhat command
const network = args[args.indexOf("--network") + 1];
if (!network || network === true || network.startsWith("-")) {
  console.error("Wrong network specified. Use the --network flag to specify one like: '--network localhost'.");
  process.exit(1);
}

const command = `npx hardhat run scripts/deploy_contracts.js --network ${network}`;

// Execute the Hardhat script with environment variables
exec(command, { env }, (error, stdout, stderr) => {
  if (error) {
    console.error(`exec error: ${error}`);
    return;
  }
  console.log(`stdout: ${stdout}`);
  if (stderr) {
    console.error(`stderr: ${stderr}`);
  }
});