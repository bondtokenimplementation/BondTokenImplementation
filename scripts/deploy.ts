import { ethers } from "hardhat";
import * as fs from 'fs';
import * as path from 'path';

interface ContractArtifacts {
  abi: string[];
  bytecode: string;
  address: string;
}

let deployer: any;

const contractNames: string[] = ["BondTokenContract", "CSRContract", "KYCContract", "DocumentContract", "StableCoin"];
const allContractArtifacts: { [contractName: string]: ContractArtifacts } = {};

async function main() {
  const jsonFileReadPath = path.join(__dirname, '../artifacts/contracts/');
  const jsonFileWritePath = path.join(__dirname, '../deployed-contracts/');

  [deployer] = await ethers.getSigners();

  if (!fs.existsSync(jsonFileWritePath)) {
    fs.mkdirSync(jsonFileWritePath, { recursive: true });
  }

  for (const contractName of contractNames) {
    const contract = await ethers.getContractFactory(contractName);

    let deployedContract;
    
    if (contractName == "StableCoin") {
        deployedContract = await ethers.deployContract(contractName, ["Euro", "EUR"]);
    } else {
        deployedContract = await ethers.deployContract(contractName);
    }
    await deployedContract.waitForDeployment();

    console.log(`Deployed ${contractName} to ${deployedContract.target}.`);
    
    let contractAbi: string [] = [];

    try {
      // Read the contents of the JSON file
      const fileContent = fs.readFileSync(jsonFileReadPath + `${contractName}.sol/${contractName}.json`, "utf-8");
      const contractJSON = JSON.parse(fileContent);
      contractAbi = contractJSON.abi; 
    } catch (error) {
      console.error("Error reading or parsing the JSON file:", (error as Error).message);
    }

    // Export ABI and Bytecode to JSON file
    const contractArtifacts: ContractArtifacts = {
      abi: contractAbi,
      bytecode: contract.bytecode,
      address: deployedContract.target as string,
    };

    // Store artifacts in the object
    allContractArtifacts[contractName] = contractArtifacts;

    // Write individual JSON files for each contract
    fs.writeFileSync(jsonFileWritePath + `${contractName}Artifacts.json`, JSON.stringify(contractArtifacts, null, 2));
  }
  
  // Write a combined JSON file with all contract artifacts
  fs.writeFileSync(jsonFileWritePath + 'AllContractArtifacts.json', JSON.stringify(allContractArtifacts, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
