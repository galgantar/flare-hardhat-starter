const { ethers } = require("hardhat");


const STATE_CONNECTOR_ADDRESS = "0x0c13aDA1C7143Cf0a0795FFaB93eEBb6FAD6e4e3";


async function main() {
    const [deployer] = await ethers.getSigners()

    console.log("Deploying contracts with the account:", deployer.address)

    console.log("Account balance:", (await deployer.getBalance()).toString())

    const Factory = await ethers.getContractFactory("PaymentVerification")
    const dao = await Factory.deploy(STATE_CONNECTOR_ADDRESS);

    console.log("Contract address:", dao.address)
   
    await dao.deployed()
    console.log("Verifying code...")
    await hre.run("verify:verify", {
        address: dao.address,
        constructorArguments: [STATE_CONNECTOR_ADDRESS],
    })
    console.log("Verified!")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
