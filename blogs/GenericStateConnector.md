# Usage of Flare State connector, part 1

# Introduction

The blockchain world has evolved at a rapid pace, bringing forth a myriad of decentralized technologies and diverse networks. In this dynamic landscape, the demand for blockchain interoperability has never been higher. As various blockchains continue to carve out their niches, the need for them to communicate and share data seamlessly has become a pressing necessity. Enter the Flare State Connector, a solution that bridges the gap between disparate blockchains, enabling the smooth exchange of information and synchronization of smart contracts and state changes. In a world where collaboration and connectivity are paramount, the Flare State Connector stands out as a pivotal player, addressing the growing demand for interoperability in the blockchain space. In this blog we will explore the significance of bridging data across blockchains and how the Flare State Connector is shaping the future of decentralized collaboration.

## Flare state connector

The State Connector is a smart contract running on the Flare network that allows any smart contract on the Flare network to query non-changing, verifiable information from other blockchains such as BTC or XRP. The State Connector ensures decentralized and secure data access by leveraging a set independent attestation providers. These providers fetch necessary information globally and transmit it to the Flare network. The State Connector's smart contract validates consensus among received answers before publishing the results, ensuring a robust and tamper-resistant process.

## Overlapped CCCR protocol

Flare state connector protocol operates in **attestation rounds**. Each attestation round has 4 consecutive phases:
- **Collect**: Users send their requests to the State Connector contract which forwards them to every attestation provider.
- **Choose**: Attestation Providers vote on which requests they will be able to answer in the current round.
- **Commit**: Attestation providers send **obfuscated** answers to the State Connector, so they cannot cheat by peeking at each other's submissions.
- **Reveal**: Attestation providers send the **deobfuscation** key so their previous answers are revealed. When all data is available, answers are made public if there is enough consensus.

For each round attestation providers form a Merkle tree containing hashes of all the attestation requests that were marked valid in Choose phrase. The Merkle root than gets submitted to State connector smart contract where it is made public for anyone to use.

<!-- TODO: add diagram -->

You can read more about Flare state connector [here](https://docs.flare.network/tech/state-connector/).

## Getting external data on Flare

In this blog we will focus on the *payment attestation type* - special type of attestation design to verify that a specific transaction on external chain has indeed happened. We will write a simple script that will allow our smart contract deployed on Flare's testnet Coston to validate a BTC transaction. Let us say we have made a transaction on BTC and would like to prove its validity. We will achieve this in the following steps:

- **Verification of the transaction**: We submit our BTC transaction to the verifier of our choice. The verifier than returns the JSON containing all the information about the transaction as well as binary string representing encoded attestation request to be submitted to State connector smart contract.

- **Attestation request**: The binary calldata gets submitted to State connector smart contract. Smart contract than transmits an event informing attestation providers about your request.

- **CCCR phases**: Waiting for all four stages of overlapped CCCR protocol to finalize.

- **Merkle proof extraction**: Using our preferred attestation provider we extract Merkle proof - array of hashes that together with Merkle root stored in State connector smart contract proves that our transaction is indeed part of the Merkle tree for the specific round.

- **Submitting Merkle proof**: Once we have our Merkle proof we submit it along with BTC transaction data to our smart contract.

In the following section we will look into each of those steps more carefully and implemented them.

## Verification of the transaction

Suppose we have created a BTC transaction. The first thing we need to do in order to verify it on Flare is to verify it with a verifier of our choice. This is done by calling the `$/verifier/btc/Payment/prepareRequest` API:

```
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
```

If the selected verifier is able to find this transaction on their own node the API will return the following JSON:

```
Prepared request: {
  status: 'VALID',
  abiEncodedRequest: '0x5061796d656e7400000000000000000000000000000000000000000000000000746573744254430000000000000000000000000000000000000000000000000065f4f76d253550a8cb5749156c2c263cb1b38767b61bf31f9b2f1a0e7d1dee35c7ad677219c4a06db666890e4384ee9522390d6b99c67746a82ffbe65fcac80c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
}
```

The `abiEncodedRequest` is a binary object containing all the information about our BTC transaction that we can submit to State connector smart contract.


## Attestation request

The next step is to request attestation on State connector smart contract. For that we will need a small amount of CFLR to cover gas fees. You can get testnet CFLR using [CFLR faucet](https://faucet.towolabs.com/). The attestation request is achieved through a function on State connector smart contract:

```
async function getAttestation(data) {
    const stateConnector = new ethers.Contract(
        process.env.STATE_CONNECTOR_ADDRESS,
        nameToAbi("StateConnector", "coston").data,
        signer
    );

    // Call to the StateConnector protocol to provide attestation.
    const tx = await stateConnector.requestAttestations(data.abiEncodedRequest);
    const receipt = await tx.wait();

    // Get block number of the block containing contract call
    const blockNumber = receipt.blockNumber;
    const block = await provider.getBlock(blockNumber);

    // Get constants from State connector smart contract
    const BUFFER_TIMESTAMP_OFFSET = Number(await stateConnector.BUFFER_TIMESTAMP_OFFSET());
    const BUFFER_WINDOW = Number(await stateConnector.BUFFER_WINDOW());

    // Calculate roundId
    const roundId = Math.floor((block.timestamp - BUFFER_TIMESTAMP_OFFSET) /BUFFER_WINDOW);
    console.log("scRound:", roundId);
    return roundId;
}
```

Once we have requested attestation we can calculate `roundId` - id of the round that was in collect phase the moment we requested attestation. We now have to wait 6 minutes for Overlapped CCCR protocol to finalize our round.


## CCCR phases

When we requested attestation in the round with our fixed `roundId` the CCCR protocol was in the **collect phase** for that round meaning that attestation providers were collecting and storing attestation requests. Next is the **choose phase** in which attestation providers are voting which of the requests they can confirm based on the state of their own nodes. At the end of choose phase the entire set of attestation providers agree upon which attestation requests they will confirm in this round.

Following choose phase comes **commit phase**. By this phase every attestation provider has his own copy of Merkle tree containing hashes of responses to attestation request as leaves (every attestation provider has an exact copy of the same tree). In the commit phase each provider submits an obfuscated version of their merkle root. Lastly the CCCR reaches **reveal phase** where the each provider submits an unobfuscated version of the Merkle root. If there is enough consensus State connector smart contract makes the final merkle root public.


<!-- TODO: another diagram? -->

## Merkle proof extraction

The next step is to extract Merkle proof from our attestation client. We will use this Merkle proof to show that our requested transaction is indeed part of Merkle tree of valid requests assembled by the attestation providers. To extract the merkle proof we use `/attestation-client/api/proof/get-specific-proof` API endpoint:

```
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
    console.log("Response", responseData);

    // ...
}
```

If everything went we will get the following JSON output:

```
Response {
  status: 'OK',
  data: {
    roundId: 769582,
    hash: '0x235171cc4141718a563a357e08bc2021edeae6d07d30bb7a2cefcf679637cb8f',
    requestBytes: '0x5061796d656e7400000000000000000000000000000000000000000000000000746573744254430000000000000000000000000000000000000000000000000065f4f76d253550a8cb5749156c2c263cb1b38767b61bf31f9b2f1a0e7d1dee35c7ad677219c4a06db666890e4384ee9522390d6b99c67746a82ffbe65fcac80c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    request: {
      attestationType: '0x5061796d656e7400000000000000000000000000000000000000000000000000',
      messageIntegrityCode: '0x65f4f76d253550a8cb5749156c2c263cb1b38767b61bf31f9b2f1a0e7d1dee35',
      requestBody: [Object],
      sourceId: '0x7465737442544300000000000000000000000000000000000000000000000000'
    },
    response: {
      attestationType: '0x5061796d656e7400000000000000000000000000000000000000000000000000',
      lowestUsedTimestamp: '1705308051',
      requestBody: [Object],
      responseBody: [Object],
      sourceId: '0x7465737442544300000000000000000000000000000000000000000000000000',
      votingRound: '769582'
    },
    merkleProof: [
      '0x18252f7fdc5c33e4096209d5dddbecfb693784e504b82701a783ebd7e645038c',
      '0x3bc5b4db65c9d4e2df0fcf070a38e9fcbc84f87656a159506d3b733073c3ec5f'
    ]
  }
}
```

As we can see the response contains all the data about our BTC transaction as well as `merkleProof` that proves that our BTC transaction is a part of a merkle tree for the round `769582`.


## Submitting Merkle proof

Lastly we submit our merkle proof to the verifier. The verifier is a simple smart contract with a purpose of verifying Merkle proofs against public merkle root on the State connector smart contract. For the purpose of this blog we have deployed a verifier on Coston testnet [here](https://coston-explorer.flare.network/address/0xc04eBd5b0A304D6C8362d85947fD5096D2226558). To submit a Merkle proof we simply call `verifyPayment` function with our payment object:

```
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
```

Running this we get:

```
Verification tx: true
```

Which means that the verifier has accepted our Merkle proof and concluded the entire process. Any smart contract can now use the deployed verifier and trust that if the `verifier.verifyPayment(payment)` returned true it may release collateral, open a position, send wrapped token or any kind of action that required BTC payment in exchange.

## Conclusion

In the context of larger application this entire pipeline would be integrated and triggered every time our dApp would need data from an external blockchain. Through its innovative approach, leveraging independent attestation providers and an overlapped CCCR protocol, the Flare State connector ensures decentralized and secure data access. This blog has provided an exploration of the attestation rounds, the Merkle tree structure, and the practical implementation of the Flare State Connector for verifying transactions on external chains. With the ability to bridge data effectively, the Flare State Connector is shaping the future of decentralized collaboration by facilitating trustless interactions between different blockchain networks.