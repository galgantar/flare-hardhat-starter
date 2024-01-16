<!-- -- Krovni komentarji:

- Fokus je napačen. Demo je Crosschain Multisig enabled by FDC (DAO je samo primer)
- Če že, naj bosta bloga 2: 1. Fokusiran na tehnologijo (Crosschain Multisig solution enabled by FDC) // 2. Primer uporabe DAO
- A govorimo od State connectorju ali o FDC?
- Dajet pogledat excel, tam je že polno uporabnega texta -->

# Crosschain Multisig enabled by Flare State Connector

<!-- -- spremeniti naslov -->

### Introduction

Enabling secure and efficient multi-signature transactions across different blockchain networks, fostering seamless collaboration and fund management in decentralized environments is a complex task. Flare offers a solution, which we will showcase by implementing a cross-chain DAO (decentralized autonomous organisation). DAOs are a well-known decentralized collaborative use cases in Web3. This blog will guide you on how to use Flare State connector for cross-chain multisig application based on the DAO example.

<!-- -- Govorite o problemu (e.g. Enabling secure and efficient multi-signature transactions across different blockchain networks, fostering seamless collaboration and fund management in decentralized environments is complex) in samo naredite nastavek na rešitev (Flare has a solution which we'll showcase with DAO because DAOs are a well known decentralised collaborative use case in web 3 // This demo will guide you how to use FDA for crosschain multisig application based on the DAO example). -->

### Why Flare?

Flare introduces groundbreaking protocols that seamlessly integrate with existing blockchain infrastructures, providing a robust foundation for developing cross-chain multisignature solutions. With Flare, organizations and developers can leverage its innovative capabilities to enhance secure multisignature services across various blockchain networks. As Flare addresses the evolving needs of the decentralized landscape, it becomes a pivotal solution for entities operating in decentralized finance (DeFi), decentralized autonomous organizations (DAOs), and cross-chain collaborations, providing a distinctive edge in achieving secure and interoperable transactions. The protocol in the center of this solution is Flare State Connector.

<!-- -- Spremenite naslov poglavja

--  *Govorite o rešitvi* (e.g. Flare incorporates protocols that enable a creation of crosschain multisig solutions) in potem omenite še ostale usecase (e.g. Primarly identified target group are organisations and other (non-Flare) developers offering multisig services, preferebly on multichain (not CROSSCHAIN). One example is TotalSig. Those organisations usually cater to blockchain developers and organizations engaged in decentralized finance (DeFi), decentralized autonomous organizations (DAOs), and cross-chain collaborations. Additionally, cryptocurrency exchanges, financial institutions, and businesses operating on multiple blockchain networks may encounter challenges related to secure multi-signature transactions across different chains.).

-- highlight that these features or usecases, are made possible by Flare Network.  -->

### What is Flare State Connector?

Cross-chain multisig relies on the Flare State Connector, a fundamental component that plays a pivotal role in facilitating efficient cross-chain communication. The State Connector allows applications to be built on Flare that can use data from external blockchains and the internet securely. Its developer-friendly integration and adaptability to future innovations make it ideal for developers to build applications that are multi-chain or cross-chain. Delving into the rationale behind selecting Flare is essential, showcasing its distinct technical advantages over other options and elucidating the decision to build the demo specifically on the Flare network.

You can learn more about Flare State Connector system [here](https://flare.network/stateconnector/).

<!-- -- Crosschain multisig requires Flare state connector … emphasize the role of the Flare State Connector in facilitating efficient cross-chain communication, underscore its contribution to real-time data synchronization, enhanced security measures, scalability, and performance, and highlight its developer-friendly integration and adaptability to future innovations

-- Also, state connector can be used for ….

-- It's important to delve into the rationale behind choosing Flare, why other options were dismissed, the decision to build the demo specifically on Flare, and underscore the distinct technical advantages it offers developers.  -->

### Dapp Architecture

We are using [Nextjs](https://nextjs.org/) and [React](https://react.dev/) with [Typescript](https://www.typescriptlang.org/) for frontend, [MantineUI](https://mantine.dev/) for UI components and [Harthat](https://hardhat.org/) for Solidity development environment.

The entire code for the application is available on [**main github repo**](https://git.aflabs.org/flare-external/flare-demos-general), all smart contracts are available on [**smart contract github repo**](https://github.com/505-solutions/identity-link-contracts/tree/luka-develop).

To bootstrap your Flare development journey you can use [Flare Hardhat starter](https://github.com/flare-foundation/flare-hardhat-starter) for Hardhat or [Flare Foundry starter](https://github.com/flare-foundation/flare-foundry-starter).

The initial steps are straightforward. We set up the folder structure, and initial components and install all the necessary packages. Wallet connection is handled by [WalletConnect](https://walletconnect.com/) and we use [typechain-ethers](https://www.npmjs.com/search?q=typechain-ethers) package for type-safe interactions with smart contracts. Communication with the State Connector verifiers and attestation clients is achieved through [OpenAPI](https://swagger.io/specification/) specification and we use [swagger-typescript-api](https://www.npmjs.com/package/swagger-typescript-api) package to appropriate type-signatures for the client.

We deploy the smart contract on the Coston testnet using `npx hardhat run scripts/deploy.js --network coston` . The deploy script also has configured [automatic code verification](https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify) on the block explorer. Once deployed, we can view our contract on [Coston block explorer.](https://coston-explorer.flare.network/address/0xC751B9A998cc66986bFd6fC022c4b1Dd894cf9F9) Now we are ready to create our first proposal!

DAO members can create **Proposals** - predefined agreements that represent an agreement with a contractor for payment for a services or a reward to a specific DAO member for involvement in the organization.

The proposal is specified by the receiver address (who is the recipient of the funds) and the amount of FLR token that will be sent. We will implement a `k of n` type of multisig meaning that out of n signers (addresses on the external chain eg. `XRP`, `DOGE`, `BTC`) specified on the proposal creation at least k of them must sign the proposal in order for the proposal to be executed. We will consider transaction on an external chain with a specific memo field as as valid signature that connects the external transaction to yes vote on the proposal on Flare smart contract.

The lifecycle of a proposal is described in the following steps:

- Proposal creation (any DAO member can create a proposal)
- Signature of the proposal on external chains (designated DAO members sign the transaction)
- Verification of signature (anyone that wishes to prove this signature can request verification - for the purposes of this demo this will be done by the user)
- Attestation request (this is usually done by the same entity that requested attestaion)
- CrossChainDAO smart contract call with Merkle proof (this is usually done by the same entity that requests attestation)
- Proposal execution (smart contract can set specific restrictions who can execute proposals)

#### Proposal creation

The smart contract defines two crucial structs: `Signer` and `Proposal`. `Signer` encapsulates information about individuals participating in the decision-making process, including their unique identifier, signer address, and chain ID. On the other hand, `Proposal` stores details about each proposed action, such as a unique identifier, payment reference, signatures from participating signers, and an execution status.

In our smart contract, Signers and Proposals are described as the following structures:

```solidity
struct Signer {
    uint256 signerId;
    bytes32 signerAddress;
    uint32 chainId;
}

struct Proposal {
    uint256 proposalId; // used to reference the proposal in contract calls
    uint256 paymentReference;
    bool[] hasSigned; // Boolean mask for signers.
    bool executed;
}

Signer[] public signers; // Specific signer's id is element index.
Proposal[] public proposals; // Specific proposal's id is element index.
uint32 public consensusThreshold; // How many signatures is required
```

In the smart contract, new proposal is created by calling the `newProposal` function. Creation of a new proposal requires you to specify `address _receiver` — who is going to receive funds if the proposal is executed and `uint256 _amount` — how much funds is receiver about to get. We also need to define **6 signers** — DAO authorities on different chains and **a consensus treshold **— the number of signers needed to execute the proposal.

Once the proposal is created we calculate **payment reference** as keccak hash of proposal data: `uintk256(keccak256(abi.encodePacked(_proposalId,_receiver,_amount)))` . Payment reference attached as a memo field in external transactions serves as an anchor that tells the smart contract which specific proposal a DAO member is trying to sign.

For demo purposes, the `simulateSignatures` function allows presigning proposals. In a real-world scenario, signers would only be able to individually sign proposals through the `signProposal` function.

The contract emits events for key actions, enhancing transparency and providing hooks for external applications. These events include `NewProposal`, `NewSignature`, `NewExecution`, and `NewMessage`, each capturing different stages of the DAO's decision-making lifecycle.

### Signing the proposal on external chains

Once we have a `proposalId` we ask DAO members to sign the proposal by creating a transaction on their respective chain (XRP testnet in our case) and include proposal payment reference in the memo field. For demo purposes, there is a`simulateSignatures` function in our smart contract that allows you to simulate 2 signatures manually. **If you wish to deploy a smart contract in a real world scenario you must remove that function!**

There is also a “Create XRP transaction” button on the frontend that allows you to quickly create a testnet XRP transaction with the correct memo field using [XRP public ledger — XRPL](https://xrpl.org/index.html) with a dummy DAO member address.

### Verification of signature

Once the testnet XRP transaction is created we have to verify it using one of the State connector verifiers. Flare State connector supports many different attestation types and we will use `Payment` attestation type. We achieve this with an API call to `{{VERIFIER_URL}}/verifier/xrp/Payment/prepareRequest` with parameters:

```
{
  // Payment attestation type
  "attestationType": "0x5061796d656e7400000000000000000000000000000000000000000000000000",
  // Testnet XRP
  "sourceId": "0x7465737458525000000000000000000000000000000000000000000000000000",
  "requestBody": {
    "transactionId": "<TRANSACTION_ID>",
    "inUtxo": "0x0",
    "utxo": "0x0"
  }
}
```

The response we get contains `abiEncodedRequest` — binary request for attestation.

```
{
    "status": "VALID",
    "abiEncodedRequest": "0x5061796d656e740000000000000000000000000000000000000000000000000074657374585250000000000000000000000000000000000000000000000000006b32d4363aca5365852edfdd837d83080b5f3d679d967dabdacc6da670fe304a440c72cd24270d433c308557d1fb4280cea67cb8b0874bdcf3ddd84e20b89de700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
}
```

### Attestation request

We can use `abiEncodedRequest` from before to request attestation on Coston [**state connector contract**](https://coston-explorer.flare.network/address/0x0c13aDA1C7143Cf0a0795FFaB93eEBb6FAD6e4e3) by calling `requestAttestations(abiEncodedRequest)`. This will let the entire set of attestation providers know, that you wish to have proof that the transaction with the attached payment reference has happened.

In State connector requests and answers are submitted sequentially in attestation rounds. Each attestation round has 4 consecutive phases, called Collect, Choose, Commit and Reveal. You can learn more about Flare’s CCCR (Collect, Choose, Commit, Reveal) protocol [here](https://docs.flare.network/tech/state-connector/). Once we request attestation our request is a part of a specific round numbered with `roundId`. RoundId is calculated based on the timestamp of the block in which attestation request contract call has been made. The following code calculates roundId:

```
  // request attestation
  const response = await stateConnectorCoston2.requestAttestations(
    calldata.toString(),
  );

  // wait 5s to confirm transaction
  await new Promise((res) => setTimeout(res, 5000));

  // record the transaction block timestamp
  let transaction: providers.TransactionResponse =
    await provider.getTransaction(response.hash);
  let block: providers.Block = await provider.getBlock(
    transaction.blockNumber!,
  );
  let timestamp = block.timestamp;

  // retrieve constants from the smart contract
  let BUFFER_TIMESTAMP_OFFSET = Number(
    await stateConnectorCoston2.BUFFER_TIMESTAMP_OFFSET(),
  );
  let BUFFER_WINDOW = Number(await stateConnectorCoston2.BUFFER_WINDOW());

  // calculate roundId
  let roundId = Math.floor(
    (timestamp - BUFFER_TIMESTAMP_OFFSET) / BUFFER_WINDOW,
  );
  return Number(roundId);
```

Next you have to wait 6 minutes during which the attestation providers verify the validity of the transaction on their own nodes and vote on which transactions are valid. If our transaction is marked as valid by votes it is included in the Merkle tree for that round. When each round has been finalized, Merkle root for that round gets submitted and stored in State connector smart contract.

### Merkle proof retrieval

After the round in which we requestet attestation has been finalised we are ready to retrieve our Merkle proof that we will use to prove the validity of our XRP transaction. Each attestation provider holds a copy of the entire merkle tree for the round and is thus able to produce merkle proof for each specific transaction. We retrieve the Merkle proof by calling `/attestation-client/api/proof/get-specific-proof` with the calldata from before:

```
{
    "roundId": 689667,
    "requestBytes": "0x5061796d656e7400000000000000000000000000000000000000000000000000585250000000000000000000000000000000000000000000000000000000000068f3c06d0fca2ebbd4b7e8776163cf7425c4f3d97b8e99e906e36c3a0333cb9bea91d251fa8a7978b469982d2892d519050821c7d507dffe58a62766c7b4c60100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
}
```

If everything goes as expected, the attestation provider response JSON should contain `merkleProof` that cryptographically proves that the hash of our Payment struct is indeed present in this round’s Merkle tree. Here is the structure of the expected JSON response:

```
{
  "status": "OK",
  "data": {
      "roundId": 762819,
      "hash": "0x02dc51d44e30ab0fd2d5183895dc4de7376f50f423125a3aacaf9fa2812b0aef",
      "requestBytes": "0x5061796d656e74000000000000000000000000000000000000000000000000007465737458525000000000000000000000000000000000000000000000000000b68a043499513bc114dc0611c463e8182dc88bbebee89e1783d1db8a1102418a391f0bf66825ba07e8fa7f7131ba1023218a237ebd5b7505e69a5ac8c0d8884d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "request": {
          // ...
      },
      "response": {
          "attestationType": "0x5061796d656e7400000000000000000000000000000000000000000000000000",
          "lowestUsedTimestamp": "1704724152",
          "requestBody": {
              // ...
          },
          "responseBody": {
              "blockNumber": "44380330",
              "blockTimestamp": "1704724152",
              "intendedReceivedAmount": "1000000",
              "intendedReceivingAddressHash": "0x7f5b4967a9fbe9b447fed6d4e3699051516b6afe5f94db2e77ccf86470bfd74d",
              "intendedSpentAmount": "1000012",
              "oneToOne": true,
              "receivedAmount": "1000000",
              "receivingAddressHash": "0x7f5b4967a9fbe9b447fed6d4e3699051516b6afe5f94db2e77ccf86470bfd74d",
              "sourceAddressHash": "0xe6365fcca6cf75e11c7029891d3865939626dbe7eb496ad4d573da00e0b09d5c",
              "spentAmount": "1000012",
              "standardPaymentReference": "0x8DD0435E32B90C732DE8E786B61FEF2EEC9FF0C9BC7605F295E14E464A2B1700",
              "status": "0"
          },
          "sourceId": "0x7465737458525000000000000000000000000000000000000000000000000000",
          "votingRound": "762819"
      },
      "merkleProof": [
          "0xbd3036e14b72200725871ff0ef3935c9d8f551d669b30ff5043af7ce71aa36e4",
          "0x6224c25d2381a7e5a68ccd34725fcfe3231bfeb2f147b43f68f534fe6540fd3d"
      ]
  }
}
```

### Smart contract call with Merkle proof

Assuming our XRP transaction was voted valid by attestation providers we can now proceed to proving that our XRP transaction happened on our Coston smart contract. For that we want our Cross chain DAO smart contract to retrieve Merkle root from state connector smart contract. This has been done on contract deployment by using Solidity’s interface in the constructor of our Cross chain DAO smart contract.

```
contract CrossChainDao is PaymentVerification {

  constructor(IMerkleRootStorage _stateConnector, bytes32[] memory _signerAddress, uint32[] memory _signerChainId, uint32 _consensusThreshold)
    // Pass the state connector address to the constructor
    PaymentVerification(_stateConnector) {
    // Verify that arrays are of equal length
    uint256 _length = _signerAddress.length;
    require(_length == _signerChainId.length, "Arrays must be of equal length");

    // Verify that consensusThreshold is less than or equal to the length of the signer array
    require(_consensusThreshold <= _length, "Consensus threshold must be less than or equal to the length of the signer array");

    consensusThreshold = _consensusThreshold;
    for (uint256 i = 0; i < _length; i++) {
        signers.push(Signer(signers.length, _signerAddress[i], _signerChainId[i]));
    }
  }

  // ...
}
```

Equipped with our Merkle proof we can now prove the XRP transaction on our Cross Chain DAO smart contract. We achieve this by calling `signProposal` function in which we pass our Merkle proof as `Payment.Proof` :

```
function signProposal(uint32 _proposalId, uint256 _signerId, address payable _receiver, uint256 _amount, Payment.Proof calldata _proof) external {

  // Check that signer address for this payment matches selected signer's address
  bytes32 _signerAddress = signers[_signerId].signerAddress;
  require(_signerAddress == _proof.data.responseBody.sourceAddressHash, "ChainId does not match");

  // Verify that the proposal hasn't already been executed
  require(proposals[_proposalId].executed == false, "Proposal already executed");

  // Check that signer has not already signed
  require(proposals[_proposalId].hasSigned[_signerId] == false, "Signer has already signed");

  // Verify that _receiver and _amount match proposal
  require(proposals[_proposalId].paymentReference == paymentReferenceHash(_receiver, _amount, _proposalId), "Proposal does not match");

  // Verify payment reference from proposal matches payment reference from proof
  require(bytes32(proposals[_proposalId].paymentReference) == _proof.data.responseBody.standardPaymentReference, "Payment reference does not match");

  // Verify payment execution with the Flare State Connector.
  require(this.verifyPayment(_proof), "State Connector verification failed.");

  // Mark signer as signed and emit event
  proposals[_proposalId].hasSigned[_signerId] = true;
  emit NewSignature(msg.sender, proposals[_proposalId], _signerId, _receiver, _amount);
}
```

The first few lines of this functions preform basic checks that the external transactions matches our criteria (source address must be inside our signer set and the transaction must have the correct memo field).

Most importantly our function calls `this.verifyPayment` function which internally checks if the Merkle proof that we had passed is valid based on the Merkle root for that roundId on the State connector smart contract. This is the core functionality of Flare State connector that enables it to query external chain data in this case proving that this exact transaction has indeed happened on the XRP blockchain. If everything goes well the `NewSignature` event is transmitted.

### Proposal execution

On our frontend, we listen to `newSignature` event using ethers.js hooks and React `useRef` hook:

```
// prevent javascript from deallocating our listener object
const persistentListenerRef = useRef<any>(null);

// ...

persistentListenerRef.current = CrossChainDaoCoston.on(
    "NewSignature",
    async (
      sender: string,
      proposal: CrossChainDao.ProposalStruct,
      signerId: BigNumber,
      receiver: string,
      amount: BigNumber,
    ) => {
      notifications.show({
        title: "Proposal signed",
        message: `Proposal #${proposal.proposalId.toString()}`,
        color: "green",
      });
      // update the new state of the proposal
      setProposal(proposal);
    },
  );
```

Once we have met the signer threshold we are ready to execute the proposal. To do this we call `executeProposal` function:

```
function executeProposal(uint32 _proposalId, address payable _receiver, uint256 _amount) external payable {
  // Verify that _receiver and _amount match proposal
  require(proposals[_proposalId].paymentReference == paymentReferenceHash(_receiver, _amount, _proposalId), "Proposal does not match");

// count valid signatures
uint32 _signerCount;
for (uint32 i = 0; i < proposals[_proposalId].hasSigned.length; i++) {
    if (proposals[_proposalId].hasSigned[i] == true) {
        _signerCount++;
    }
}
// ensure that the treshold has been met
require(_signerCount >= consensusThreshold, "Consensus threshold not met");
// transfer the funds
_receiver.transfer(_amount);
proposals[_proposalId].executed = true;
emit NewExecution(msg.sender, proposals[_proposalId], _receiver, _amount);
}
```

When `executeProposal` function is called it ensures that the consensus threshold has been met and then transfers the funds according to the initial proposal policy. In the real world, this would mean paying a contractor for a service that benefited the DAO or rewarding a DAO member. When the proposal has been executed a new event is transmitted, allowing our frontend to display the success message.

### Conclusion

In conclusion, the Flare Network's State Connector system demonstrates powerful cross-chain capabilities by enabling smart contracts on the EVM-based Coston network, to securely interact with and verify transactions on external chains, like the XRP blockchain. The presented smart contract, serving as a cross-chain DAO, seamlessly integrates with the State Connector to verify XRP transactions through Merkle proofs. The Flare Network's innovative system facilitates trustless communication and coordination between distinct blockchain ecosystems, offering a reliable mechanism for cross-chain transactions and data verification.

<!-- -- Spet spremeniti fokus
-- Opcijsko: Napovedati naslednji blog, kjer pa lahko govorimo samo o DAOtih -->
