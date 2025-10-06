# 📜 ProofStamp

> **Trustless Blockchain Timestamps for Digital Proof-of-Existence**

**ProofStamp** is a trust-minimized timestamping protocol built on the [Stacks](https://www.stacks.co/) blockchain, anchoring cryptographic proofs to the Bitcoin ledger. It enables creators, professionals, and organizations to register and verify document existence without revealing contents—establishing immutable, decentralized, and verifiable proof of existence.

---

## 🔍 System Overview

Traditional document notarization requires trusting centralized authorities. ProofStamp eliminates this dependency using a decentralized mechanism:

* **Hash-Based Timestamping:** Users submit a SHA-256 fingerprint (not the document itself).
* **Immutable Anchoring:** The fingerprint is permanently written to a smart contract on Stacks, inheriting Bitcoin’s security via Stacks' consensus.
* **Zero-Knowledge Verification:** Anyone with the original document can rehash and prove authenticity by matching against on-chain data—without disclosing content.
* **Tamper-Proof & Verifiable:** Timestamps are linked to the Bitcoin block height, guaranteeing immutability and preventing forgery or backdating.

---

## 📐 Contract Architecture

The contract is implemented in [Clarity](https://docs.stacks.co/write-smart-contracts/clarity-language), the safe, decidable smart contract language for Stacks.

### Key Modules

| Component                                | Purpose                                                     |
| ---------------------------------------- | ----------------------------------------------------------- |
| `create-proof`                           | Registers a cryptographic proof with timestamp and metadata |
| `verify-proof`                           | Authenticates document hash against existing proof          |
| `get-proof-details`                      | Retrieves proof metadata                                    |
| `hash-exists` / `get-verification-count` | Enables reverse lookup of document proofs                   |
| `update-protocol-version`                | Administrative control for protocol upgrades                |

### Core Concepts

* **Proofs:** Each proof links a `creator`, `recipient`, `content-hash`, timestamp (`block-height`), and verification status.
* **Privacy-Preserving:** No actual documents or private data are stored—only SHA-256 hashes.
* **Recipient Model:** Proofs can be assigned to a third-party recipient (e.g., a copyright lawyer, reviewer).
* **Audit Trails:** Every verification is tracked and incremented, creating a tamper-evident trail.

---

## 🧊 Data Structures

### Maps & Variables

| Storage            | Type | Description                                                                   |
| ------------------ | ---- | ----------------------------------------------------------------------------- |
| `proofs`           | Map  | Main registry keyed by `proof-id`, storing metadata                           |
| `hash-registry`    | Map  | Lookup index keyed by `content-hash`, storing proof-id and verification count |
| `user-proof-count` | Map  | Tracks how many proofs each user has created                                  |
| `total-proofs`     | Var  | Global counter incremented per new proof                                      |
| `protocol-version` | Var  | Protocol semantic versioning for upgrades                                     |

---

## 🔄 Data Flow

### 📝 Proof Creation

1. **User Inputs:** SHA-256 hash and recipient principal.
2. **Validation:** Ensures valid recipient, no self-reference, and hash structure.
3. **Storage:** Saves metadata (including `block-height`) in `proofs`, and indexes the hash.
4. **Tracking:** Updates user count and global proof counter.

### 🔍 Proof Verification

1. **Inputs:** Proof ID and the document hash to validate.
2. **Hash Match:** If the hash matches the stored `content-hash`, verification is successful.
3. **Update:** Marks proof as `verified`, increments verification counter in `hash-registry`.

---

## 📘 API Documentation

### 🔐 Public Functions

| Function                                | Description                                        |
| --------------------------------------- | -------------------------------------------------- |
| `create-proof(recipient, content-hash)` | Registers a new timestamp proof                    |
| `verify-proof(proof-id, provided-hash)` | Verifies document authenticity against stored hash |
| `update-protocol-version(new-version)`  | Contract owner can upgrade the protocol version    |

### 🧾 Read-Only Queries

| Function                       | Description                                         |
| ------------------------------ | --------------------------------------------------- |
| `get-proof-details(proof-id)`  | Returns metadata for a given proof                  |
| `get-total-proofs()`           | Returns total proofs created                        |
| `get-user-proof-count(user)`   | Returns how many proofs a specific user has created |
| `get-protocol-version()`       | Returns the current protocol version                |
| `hash-exists(hash)`            | Returns true if the hash is already registered      |
| `get-verification-count(hash)` | Returns how many times a hash has been verified     |

---

## 🚀 Example Use Cases

* **Digital Copyright Claims**
  Timestamp the existence of creative works without revealing their content.

* **Academic Research**
  Prove discovery or authorship dates for scientific findings or ideas.

* **Compliance & Audits**
  Anchor logs, legal documents, or certifications in a tamper-evident manner.

* **Supply Chain or Evidence Chain**
  Secure off-chain documents like invoices, delivery records, or legal evidence.

---

## 🔒 Security Considerations

* **No On-Chain Secrets:** Only hashes are stored—no sensitive or proprietary data ever touches the blockchain.
* **Immutable Registry:** Proofs cannot be altered or deleted once committed.
* **Permissionless Verification:** Anyone with the original document can verify authenticity.
* **Self-Proof Prevention:** Users cannot issue proofs to themselves, enforcing minimum custody rules.

---

## 🧰 Development & Deployment

To deploy or interact with the contract:

* **Language:** Clarity
* **Platform:** Stacks 2.1+
* **Dependencies:** None (standalone protocol)
* **Owner Permissions:** Only for protocol version updates

Use [Clarinet](https://docs.hiro.so/clarinet/get-started) or the [Stacks CLI](https://docs.stacks.co/understand-stacks/transactions/stacks-cli) for local development and testing.

---

## 📄 License

MIT License – open-source and available for public and commercial use.

---

## 🧭 Final Thoughts

**ProofStamp** transforms the traditional notarization model into a decentralized, privacy-preserving, and Bitcoin-secured service. Whether you're protecting intellectual property or ensuring compliance, this protocol provides a trustless foundation for timestamping in the blockchain era.
