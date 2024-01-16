// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "../interface/types/Payment.sol";
import "../interface/external/IMerkleRootStorage.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PaymentVerification {
   using MerkleProof for bytes32[];

   IMerkleRootStorage public immutable merkleRootStorage;

   constructor(IMerkleRootStorage _merkleRootStorage) {
      merkleRootStorage = _merkleRootStorage;
   }

   function verifyPayment(
      Payment.Proof calldata _proof
   ) external view returns (bool _proved) {
      return
         _proof.merkleProof.verify(
            merkleRootStorage.merkleRoot(_proof.data.votingRound),
            keccak256(abi.encode(_proof.data))
         );
   }
}
   