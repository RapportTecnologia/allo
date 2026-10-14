// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "./interfaces/IAlloTimelockController.sol";

/// @title AlloMultisigWallet
/// @notice Lightweight M-of-N multisig wallet that acts as the sole proposer
///         and executor of the AlloTimelockController.
/// @dev Each administrative action is represented as a transaction proposal.
///      Signers submit, confirm and, once the threshold is reached, execute
///      the transaction. Signer set and threshold can only be changed through
///      a successful multisig transaction that calls back into this contract.
contract AlloMultisigWallet {
    // ==========================
    // === Storage Variables ====
    // ==========================

    /// @notice Multisig transaction proposal.
    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        bool executed;
        bool cancelled;
        uint256 confirmations;
    }

    /// @notice Signers of the multisig.
    address[] public signers;

    /// @notice Whether an address is a signer.
    mapping(address => bool) public isSigner;

    /// @notice Number of confirmations required to execute a transaction.
    uint256 public threshold;

    /// @notice Total number of transactions submitted.
    uint256 public transactionCount;

    /// @notice Transaction details by id.
    mapping(uint256 => Transaction) public transactions;

    /// @notice Confirmation status per transaction and signer.
    mapping(uint256 => mapping(address => bool)) public confirmations;

    /// @notice Timelock controller this multisig interacts with.
    IAlloTimelockController public timelock;

    // ==========================
    // ========= Events =========
    // ==========================

    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event ThresholdChanged(uint256 oldThreshold, uint256 newThreshold);
    event TransactionSubmitted(
        uint256 indexed transactionId, address indexed submitter, address indexed target, uint256 value, bytes data
    );
    event TransactionConfirmed(uint256 indexed transactionId, address indexed signer);
    event TransactionRevoked(uint256 indexed transactionId, address indexed signer);
    event TransactionExecuted(uint256 indexed transactionId, address indexed target, uint256 value);
    event TransactionCancelled(uint256 indexed transactionId);

    // ==========================
    // ===== Custom Errors ======
    // ==========================

    error NOT_SIGNER();
    error INVALID_SIGNER();
    error SIGNER_ALREADY_EXISTS();
    error INVALID_THRESHOLD();
    error TX_NOT_EXISTS();
    error ALREADY_CONFIRMED();
    error NOT_CONFIRMED();
    error TX_ALREADY_EXECUTED();
    error TX_CANCELLED();
    error NOT_ENOUGH_CONFIRMATIONS();
    error EXECUTION_FAILED();
    error DUPLICATE_SIGNER();
    error ZERO_ADDRESS_NOT_ALLOWED();

    // ==========================
    // ======= Modifiers ========
    // ==========================

    modifier onlySigner() {
        if (!isSigner[msg.sender]) revert NOT_SIGNER();
        _;
    }

    modifier onlyWallet() {
        if (msg.sender != address(this)) revert NOT_SIGNER();
        _;
    }

    modifier txExists(uint256 _transactionId) {
        if (_transactionId >= transactionCount) revert TX_NOT_EXISTS();
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        if (transactions[_transactionId].executed) revert TX_ALREADY_EXECUTED();
        _;
    }

    modifier notCancelled(uint256 _transactionId) {
        if (transactions[_transactionId].cancelled) revert TX_CANCELLED();
        _;
    }

    // ==========================
    // ====== Initializer =======
    // ==========================

    /// @notice Deploys the multisig wallet and links it to the timelock.
    /// @param _signers Initial signer addresses.
    /// @param _threshold Number of confirmations required to execute a transaction.
    /// @param _timelock Address of the AlloTimelockController.
    constructor(address[] memory _signers, uint256 _threshold, address _timelock) {
        if (_signers.length == 0) revert INVALID_THRESHOLD();
        if (_threshold == 0 || _threshold > _signers.length) revert INVALID_THRESHOLD();
        if (_timelock == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();

        timelock = IAlloTimelockController(_timelock);

        for (uint256 i = 0; i < _signers.length;) {
            address signer = _signers[i];
            if (signer == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
            if (isSigner[signer]) revert DUPLICATE_SIGNER();

            isSigner[signer] = true;
            signers.push(signer);

            unchecked {
                ++i;
            }
        }

        threshold = _threshold;
    }

    // ==========================
    // === External Functions ====
    // ==========================

    /// @notice Submits a new transaction proposal.
    /// @dev Only signers can propose. The submitter automatically confirms the proposal.
    /// @param _target Target address to call.
    /// @param _value Native token value to send.
    /// @param _data Calldata to send.
    /// @return transactionId The id of the newly created proposal.
    function submitTransaction(address _target, uint256 _value, bytes calldata _data)
        external
        onlySigner
        returns (uint256 transactionId)
    {
        if (_target == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();

        transactionId = transactionCount;

        transactions[transactionId] = Transaction({
            target: _target,
            value: _value,
            data: _data,
            executed: false,
            cancelled: false,
            confirmations: 1
        });

        confirmations[transactionId][msg.sender] = true;
        transactionCount++;

        emit TransactionSubmitted(transactionId, msg.sender, _target, _value, _data);
        emit TransactionConfirmed(transactionId, msg.sender);

        return transactionId;
    }

    /// @notice Confirms an existing transaction proposal.
    /// @param _transactionId The id of the transaction to confirm.
    function confirmTransaction(uint256 _transactionId)
        external
        onlySigner
        txExists(_transactionId)
        notExecuted(_transactionId)
        notCancelled(_transactionId)
    {
        if (confirmations[_transactionId][msg.sender]) revert ALREADY_CONFIRMED();

        confirmations[_transactionId][msg.sender] = true;
        transactions[_transactionId].confirmations++;

        emit TransactionConfirmed(_transactionId, msg.sender);
    }

    /// @notice Revokes a prior confirmation.
    /// @param _transactionId The id of the transaction to revoke confirmation from.
    function revokeConfirmation(uint256 _transactionId)
        external
        onlySigner
        txExists(_transactionId)
        notExecuted(_transactionId)
        notCancelled(_transactionId)
    {
        if (!confirmations[_transactionId][msg.sender]) revert NOT_CONFIRMED();

        confirmations[_transactionId][msg.sender] = false;
        transactions[_transactionId].confirmations--;

        emit TransactionRevoked(_transactionId, msg.sender);
    }

    /// @notice Executes a transaction after the required number of confirmations is reached.
    /// @param _transactionId The id of the transaction to execute.
    function executeTransaction(uint256 _transactionId)
        external
        onlySigner
        txExists(_transactionId)
        notExecuted(_transactionId)
        notCancelled(_transactionId)
    {
        Transaction storage txn = transactions[_transactionId];

        if (txn.confirmations < threshold) revert NOT_ENOUGH_CONFIRMATIONS();

        txn.executed = true;

        (bool success,) = txn.target.call{value: txn.value}(txn.data);
        if (!success) revert EXECUTION_FAILED();

        emit TransactionExecuted(_transactionId, txn.target, txn.value);
    }

    /// @notice Cancels a transaction that has not been executed yet.
    /// @dev Requires the same confirmation threshold to avoid unilateral cancellation.
    /// @param _transactionId The id of the transaction to cancel.
    function cancelTransaction(uint256 _transactionId)
        external
        onlySigner
        txExists(_transactionId)
        notExecuted(_transactionId)
        notCancelled(_transactionId)
    {
        Transaction storage txn = transactions[_transactionId];

        if (txn.confirmations < threshold) revert NOT_ENOUGH_CONFIRMATIONS();

        txn.cancelled = true;

        emit TransactionCancelled(_transactionId);
    }

    /// @notice Adds a signer. Must be called by the multisig itself via a successful transaction.
    /// @param _signer Address of the new signer.
    function addSigner(address _signer) external onlyWallet {
        if (_signer == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (isSigner[_signer]) revert SIGNER_ALREADY_EXISTS();

        isSigner[_signer] = true;
        signers.push(_signer);

        emit SignerAdded(_signer);
    }

    /// @notice Removes a signer. Must be called by the multisig itself via a successful transaction.
    /// @param _signer Address of the signer to remove.
    function removeSigner(address _signer) external onlyWallet {
        if (!isSigner[_signer]) revert INVALID_SIGNER();
        if (signers.length - 1 < threshold) revert INVALID_THRESHOLD();

        isSigner[_signer] = false;

        uint256 signerLength = signers.length;
        for (uint256 i = 0; i < signerLength;) {
            if (signers[i] == _signer) {
                signers[i] = signers[signerLength - 1];
                signers.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit SignerRemoved(_signer);
    }

    /// @notice Replaces one signer with another. Must be called by the multisig itself.
    function replaceSigner(address _oldSigner, address _newSigner) external onlyWallet {
        if (_newSigner == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (!isSigner[_oldSigner]) revert INVALID_SIGNER();
        if (isSigner[_newSigner]) revert SIGNER_ALREADY_EXISTS();

        isSigner[_oldSigner] = false;
        isSigner[_newSigner] = true;

        uint256 signerLength = signers.length;
        for (uint256 i = 0; i < signerLength;) {
            if (signers[i] == _oldSigner) {
                signers[i] = _newSigner;
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit SignerRemoved(_oldSigner);
        emit SignerAdded(_newSigner);
    }

    /// @notice Changes the confirmation threshold. Must be called by the multisig itself.
    /// @param _threshold New threshold value.
    function changeThreshold(uint256 _threshold) external onlyWallet {
        if (_threshold == 0 || _threshold > signers.length) revert INVALID_THRESHOLD();

        uint256 oldThreshold = threshold;
        threshold = _threshold;

        emit ThresholdChanged(oldThreshold, _threshold);
    }

    /// @notice Receives native tokens forwarded to the multisig.
    receive() external payable {}

    // ==========================
    // ===== View Functions =====
    // ==========================

    /// @notice Returns the list of signers.
    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    /// @notice Returns the number of confirmations for a transaction.
    function getConfirmationCount(uint256 _transactionId) external view txExists(_transactionId) returns (uint256) {
        return transactions[_transactionId].confirmations;
    }

    /// @notice Returns the number of signers.
    function getSignerCount() external view returns (uint256) {
        return signers.length;
    }
}
