// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @custom:name Payment
 * @custom:id 0x01
 * @custom:supported BTC, DOGE, XRP
 * @author Flare
 * @notice The attestation type is used to prove that a native currency payment was carried out on some blockchain.
 * Various blockchains support different types of native payments. For each block chain, it is specified how a payment
 * transaction should be formed to be provable by this attestation type.
 * The provable payments emulate usual banking payment from entity A to entity B in native currency with an optional payment reference.
 * @custom:verification Based on transaction id, the transaction is fetched from the API of the blockchain node or relevant indexer.
 * If the transaction cannot be fetched or the transaction is in a block that does not have sufficient [number of confirmations](/specs/attestations/configs.md#finalityconfirmation), the attestation request is rejected.
 *
 * Once the transaction is received, the [payment summary](/specs/attestations/external-chains/transactions.md#payment-summary) is computed according to the source chain.
 * If summary is successfully calculated, the response is assembled from the summary.
 * Otherwise, the attestation request is rejected.
 * @custom:lut `blockTimestamp`
 */
interface Payment {
    /**
     * @notice Toplevel request
     * @param attestationType Id of the attestation type.
     * @param sourceId Id of the data source.
     * @param messageIntegrityCode `MessageIntegrityCode` that is derived from the expected response as defined [here](/specs/attestations/hash-MIC.md#message-integrity-code).
     * @param requestBody Data defining the request. Type (struct) and interpretation is determined by the `attestationType`.
     */
    struct Request {
        bytes32 attestationType;
        bytes32 sourceId;
        bytes32 messageIntegrityCode;
        RequestBody requestBody;
    }

    /**
     * @notice Toplevel response
     * @param attestationType Extracted from the request.
     * @param sourceId Extracted from the request.
     * @param votingRound The id of the state connector round in which the request was considered.
     * @param lowestUsedTimestamp The lowest timestamp used to generate the response.
     * @param requestBody Extracted from the request.
     * @param responseBody Data defining the response. The verification rules for the construction of the response body and the type are defined per specific `attestationType`.
     */
    struct Response {
        bytes32 attestationType;
        bytes32 sourceId;
        uint64 votingRound;
        uint64 lowestUsedTimestamp;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * @notice Toplevel proof
     * @param merkleProof Merkle proof corresponding to the attestation response.
     * @param data Attestation response.
     */
    struct Proof {
        bytes32[] merkleProof;
        Response data;
    }

    /**
     * @notice Request body for Payment attestation type
     * @param transactionId Id of the payment transaction.
     * @param inUtxo Index of the transaction input. Always 0 for the non-utxo chains.
     * @param utxo Index of the transaction output. Always 0 for the non-utxo chains.
     */
    struct RequestBody {
        bytes32 transactionId;
        uint256 inUtxo;
        uint16 utxo;
    }

    /**
     * @notice Response body for Payment attestation type
     * @param blockNumber Number of the block in which the transaction is included.
     * @param blockTimestamp The timestamps of the block in which the transaction is included.
     * @param sourceAddressHash Standard address hash of the source address.
     * @param receivingAddressHash Standard address hash of the receiving address. Zero 32-byte string if there is no receivingAddress (if `status` is not success).
     * @param intendedReceivingAddressHash Standard address hash of the intended receiving address. Relevant if the transaction was unsuccessful.
     * @param spentAmount Amount in minimal units spent by the source address.
     * @param intendedSpentAmount Amount in minimal units to be spent by the source address. Relevant if the transaction status is not success.
     * @param receivedAmount Amount in minimal units received by the receiving address.
     * @param intendedReceivedAmount Amount in minimal units intended to be received by the receiving address. Relevant if the transaction was unsuccessful.
     * @param standardPaymentReference Identifier of the transaction as defined [here](/specs/attestations/external-chains/standardPaymentReference.md).
     * @param oneToOne Indicator whether only one source and one receiver are involved in the transaction.
     * @param status Status of the transaction as described [here](/specs/attestations/external-chains/transactions.md#transaction-success-status):
     *   0 - success,
     *   1 - failed by sender's fault,
     *   2 - failed by receiver's fault.
     */
    struct ResponseBody {
        uint64 blockNumber;
        uint64 blockTimestamp;
        bytes32 sourceAddressHash;
        bytes32 receivingAddressHash;
        bytes32 intendedReceivingAddressHash;
        int256 spentAmount;
        int256 intendedSpentAmount;
        int256 receivedAmount;
        int256 intendedReceivedAmount;
        bytes32 standardPaymentReference;
        bool oneToOne;
        uint8 status;
    }
}
