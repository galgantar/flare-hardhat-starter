import { Payment } from "@flarenetwork/state-connector-protocol/dist/generated/types/typescript/index.js"
import { nameToAbi } from "@flarenetwork/flare-periphery-contract-artifacts";
import { encodeAttestationName } from '@flarenetwork/state-connector-protocol/dist/libs/ts/utils.js';
import { ethers } from "ethers";
import dotenv from "dotenv";
import PaymentVerificationData from './PaymentVerification.json' assert { type: "json" };
dotenv.config();


// Initialize script variables
const provider = new ethers.providers.JsonRpcProvider(process.env.FLARE_RPC);
const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const BTC_TRANSACTION_ID = "0xc7ad677219c4a06db666890e4384ee9522390d6b99c67746a82ffbe65fcac80c";


// Function to prepare attestation request using API endpoint, parameter object, returns object.
async function prepareRequest() {
    const attestationType = Payment.TYPE;
    const sourceType = encodeAttestationName("testBTC");
    // Attestation Request object to be sent to API endpoint
    const requestNoMic = {
        "attestationType": attestationType,
        "sourceId": sourceType,
        "requestBody": {
            "transactionId": BTC_TRANSACTION_ID,
            "inUtxo": "0x0",
            "utxo": "0x0"
        }
    }
    const response = await fetch(
        `${process.env.ATTESTER_BASE}/verifier/btc/Payment/prepareRequest`,
        {
            method:"POST",
            headers:{ "X-API-KEY": process.env.API_KEY, "Content-Type": "application/json" },
            body: JSON.stringify(requestNoMic)
        }
    );
    const data = await response.json();
    console.log("Prepared request:", data);
    return data;
}

// Function to request attestation from the StateConnector protocol, parameter object, returns Number.
async function getAttestation(data) {
    const stateConnector = new ethers.Contract(
        process.env.STATE_CONNECTOR_ADDRESS,
        nameToAbi("StateConnector", "coston").data,
        signer
    );

    // Call to the StateConnector protocol to provide attestation.
    const tx = await stateConnector.requestAttestations(data.abiEncodedRequest);
    const receipt = await tx.wait();

    const blockNumber = receipt.blockNumber;
    const block = await provider.getBlock(blockNumber);

    const BUFFER_TIMESTAMP_OFFSET = Number(await stateConnector.BUFFER_TIMESTAMP_OFFSET());
    const BUFFER_WINDOW = Number(await stateConnector.BUFFER_WINDOW());

    // Calculate roundId
    const roundId = Math.floor((block.timestamp - BUFFER_TIMESTAMP_OFFSET) / BUFFER_WINDOW);
    console.log("scRound:", roundId);
    return roundId;
}

// Function to verify attestation using verifier's API, parameters Number and Object.
async function testAttestation(scRound, requestData) {
    const attestationProof = {
        "roundId": scRound,
        "requestBytes": requestData.abiEncodedRequest
    };
    const response = await fetch(
        `${process.env.ATTESTER_BASE}/attestation-client/api/proof/get-specific-proof`,
        {
            method:"POST",
            headers: { "X-API-KEY": process.env.API_KEY, "Content-Type": "application/json" },
            body:JSON.stringify(attestationProof)
        }
    );
    
    // Verified attestation proof from verifiers API endpoint.
    const responseData = await response.json();
    const payment = { 
        data: responseData.data.response,
        merkleProof: responseData.data.merkleProof
    }
    console.log("Response", responseData);
    console.log("Payment", payment);

    const verifier = new ethers.Contract(
        process.env.VERIFIER_ADDRESS,
        PaymentVerificationData.abi,
        signer
    );
    const tx = await verifier.verifyPayment(payment);
    console.log("Verification tx:", tx);
}

async function runSCPipeline() {
    try {
        const preparedData = await prepareRequest();
        let scRound = await getAttestation(preparedData);
        
        scRound = 769582;
        // wait 6 minutes
        // await new Promise(resolve => setTimeout(resolve, 6 * 60 * 1000));
        testAttestation(scRound, preparedData);
    }
    catch (error) {
        console.error(error);
    }
}

runSCPipeline();
