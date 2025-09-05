// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CounterV1 {
    uint256 public count;         // slot0 in implementation layout (safe due to EIP-1967)
    function inc() external { count += 1; }
}

contract CounterV2 {
    uint256 public count;         // same layout
    function inc() external { count += 1; }
    function dec() external { count -= 1; } // underflow auto-reverts in ^0.8
}


/// @notice Admin can change admin and upgrade implementation; non-admin calls are delegated.
/// @dev Storage uses EIP-1967 slots to avoid collisions with implementation state.
contract SimpleProxy {
    // EIP-1967 slots: keccak256("eip1967.proxy.implementation") - 1, same for admin.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant _ADMIN_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event Upgraded(address indexed implementation);

    constructor(address _admin, address _implementation) {
        require(_admin != address(0), "admin = zero");
        require(_implementation.code.length > 0, "impl !contract");
        _setAdmin(_admin);
        _setImplementation(_implementation);
    }

    // --------- Views (public getters) ---------
    function admin() public view returns (address) {
        return _getAdmin();
    }

    function implementation() public view returns (address) {
        return _getImplementation();
    }

    // --------- Admin-only ops ---------
    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "Not authorized");
        _;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "admin = zero");
        address prev = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(prev, newAdmin);
    }

    function upgradeImplementation(address newImplementation) external onlyAdmin {
        require(newImplementation.code.length > 0, "impl !contract");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    // --------- Fallback / delegation ---------
    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {
        _delegate(_getImplementation());
    }

    // --------- internals ---------
    function _delegate(address impl) internal {
        require(impl != address(0), "impl not set");
        assembly {
            // Copy calldata to memory
            calldatacopy(0, 0, calldatasize())
            // delegatecall to impl
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // copy returndata
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
        }
    }

    function _getAdmin() internal view returns (address a) {
        bytes32 slot = _ADMIN_SLOT;
        assembly { a := sload(slot) }
    }

    function _setAdmin(address a) internal {
        bytes32 slot = _ADMIN_SLOT;
        assembly { sstore(slot, a) }
    }

    function _getImplementation() internal view returns (address i) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { i := sload(slot) }
    }

    function _setImplementation(address i) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { sstore(slot, i) }
    }
}
