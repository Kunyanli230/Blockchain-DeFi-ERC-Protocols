// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TimeLock {
    error NotOwnerError();
    error AlreadyQueuedError(bytes32 txId);
    error TimestampNotInRangeError(uint blockTimestamp, uint timestamp);
    error NotQueuedError(bytes32 txId);
    error TimestampNotYetReachedError(uint blockTimestamp, uint timestamp);
    error TimestampExpiredError(uint blockTimestamp, uint expiredAt);
    error TxFailedError();

    event Queue(bytes32 indexed txId, address indexed target, uint value, string func, bytes data, uint timestamp);
    event Execute(bytes32 indexed txId, address indexed target, uint value, string func, bytes data, uint timestamp);
    event Cancel(bytes32 indexed txId);


    uint public constant MIN_DELAY = 10;
    uint public constant MAX_DELAY = 1000;
    uint public constant GRACE_PERIOD = 1000;



    address public owner;
    mapping(bytes32 => bool) public queued;

    constructor() {
        owner = msg.sender;
    }
    receive() external payable { }
    modifier  onlyOwner() {
        if(msg.sender != owner){
            revert NotOwnerError();
        }
        _;
    }

    function queue(
        address _target, uint _value, string calldata _func, bytes calldata _data, uint _timestamp
    ) external {
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);
        if(queued[txId]) {
            revert AlreadyQueuedError(txId);
        }

        // ---| ------------|---------------------|---------
        // block         block+min             block +max

        if(_timestamp < block.timestamp + MIN_DELAY || _timestamp > block.timestamp + MAX_DELAY){
            revert TimestampNotInRangeError(block.timestamp, _timestamp);
        }

        queued[txId] = true;

        emit Queue(txId, _target, _value, _func, _data, _timestamp);
        
    }
    
    function getTxId(
        address _target, uint _value, string calldata _func, bytes calldata _data, uint _timestamp
    ) public pure returns(bytes32 txId){
        return keccak256(abi.encode(_target, _value, _func, _data, _timestamp));
    }


    function execute(
        address _target, uint _value, string calldata _func, bytes calldata _data, uint _timestamp

    ) external payable onlyOwner returns(bytes memory){
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);
        //check tx is queued
        if(!queued[txId]){
            revert NotQueuedError(txId);
        }
        //check block.timestamp > _timestamp
        if(block.timestamp < _timestamp){
            revert TimestampNotYetReachedError(block.timestamp, _timestamp);
        }
        // ------|------------------|---------
        // timestamp            timestamp + grace time
        if(block.timestamp < _timestamp + GRACE_PERIOD){
            revert TimestampExpiredError(block.timestamp, _timestamp + GRACE_PERIOD);
        }

        queued[txId] = false;
        bytes memory data;
        if(bytes(_func).length>0){
            data = abi.encodePacked(bytes4(keccak256(bytes(_func))), _data);
            //data = abi.encodeWithSelector(keccak256(bytes(_func)), _data);
        }else{
            data = _data;
        }

        //execute tx
        (bool success, bytes memory res) = _target.call{value: _value}(data);
        if(!success){revert TxFailedError();}

        emit Execute(txId, _target, _value, _func, _data, _timestamp);

        return res;

    }

    function cancel(bytes32 _txId) external onlyOwner{
        if(!queued[_txId]){revert NotQueuedError(_txId);}
        queued[_txId] = false;
        emit Cancel(_txId);
    }
}







contract TestTImeLock{
    address public timelock;
    constructor(address _timelock){
        timelock = _timelock;
    }

    function test() external {
    require(msg.sender == timelock);
    // codes for contract update
    // codes for asset transfer
    // codes for chainlink
    }

    function getTimestamp() external view returns(uint){
        return block.timestamp + 100;
    }


}


