pragma solidity ^0.4.21;

import "../Utils/SafeMath.sol";
import "../Utils/Owned.sol";
import "../Interfaces/IERC20Token.sol";

contract CreditGAMEInterface {
    function isGameApproved(address _gameAddress) view public returns(bool);
    function createLock(address _winner, uint _totalParticipationAmount, uint _tokenLockDuration) public;
    function removeLock() public;
    function cleanUp() public;
    function checkIfLockCanBeRemoved(address _gameAddress) public view returns(bool);
}


contract LuckyTree is Owned, SafeMath{
    
    uint public leafPrice;
    uint public gameStart;
    uint public gameDuration;
    uint public tokenLockDuration;
    uint public totalParticipationAmount;
    uint public totalLockedAmount;
    uint public numberOfLeafs;
    uint public participantIndex;
    bool public fundsTransfered;
    address public winner;
    mapping(uint => address) public participants;
    mapping (uint => uint) public participationAmount;
    mapping(address => bool) public hasParticipated;
    mapping(address => bool) public hasWithdrawn;
    mapping(address => uint) public participantIndexes;
    mapping(uint => address) public leafOwners;
    
    event GameWinner(address winner);
    event GameEnded(uint block);
    event GameStarted(uint block);
    event GameFailed(uint block);
    event GameLocked(uint block);
    event GameUnlocked(uint block);
    
    enum state{
        pending,
        running,
        paused,
        finished,
        closed
    }
    
    state public gameState;
    
    address public tokenAddress = 0x692a70d2e424a56d2c6c27aa97d1a86395877b3a;
    address public creditGameAddress = 0x0dcd2f752394c41875e259e00bb44fd505297caf;

    
    function LuckyTree(
        uint _leafPrice,
        uint _gameStart,
        uint _gameDuration,
        uint _tokenLockDuration) public{
        
        leafPrice = _leafPrice;
        gameStart = _gameStart;
        //gameStart = block.number + 2;
        gameDuration = _gameDuration;
        //gameDuration = block.number + 5;
        tokenLockDuration = gameDuration + tokenLockDuration;
        //tokenLockDuration = gameDuration + 3;
        
        gameState = state.pending;
        totalParticipationAmount = 0;
        numberOfLeafs = 0;
        participantIndex = 0;
        fundsTransfered = false;
        winner = 0x0;
    }
    
    function random() internal view returns(uint){
        return uint(keccak256(block.number, block.difficulty, numberOfLeafs));
    }
    
    function setTokenAddress(address _tokenAddress) public onlyOwner{
        tokenAddress = _tokenAddress;
    }
    
    function setCreditGameAddress(address _creditGameAddress) public onlyOwner{
        creditGameAddress = _creditGameAddress;
    }
    
    /**
     * Method called when game ends. 
     * Check that more than 1 wallet contributed
     **/
    function pickWinner() internal{
        if(numberOfLeafs > 0){
            if(participantIndex == 1){
                //a single account contributed - just transfer funds back
                IERC20Token(tokenAddress).transfer(leafOwners[0], totalParticipationAmount);
                emit GameFailed(block.number);
            }else{
                uint leafOwnerIndex = random() % numberOfLeafs;
                winner = leafOwners[leafOwnerIndex];
                emit GameWinner(winner);
                lockFunds(winner);
            }
        }
        gameState = state.closed;
    }
    
    /**
     * Method called when winner is picked
     * Funds are transferred to game contract and lock is created by calling game contract
     **/
    function lockFunds(address _winner) internal{
        require(totalParticipationAmount != 0);
        require(CreditGAMEInterface(creditGameAddress).isGameApproved(address(this)) == true);
        //transfer and lock tokens on game contract
        IERC20Token(tokenAddress).transfer(creditGameAddress, totalParticipationAmount);
        CreditGAMEInterface(creditGameAddress).createLock(_winner, totalParticipationAmount, tokenLockDuration);
        totalLockedAmount = totalParticipationAmount;
        emit GameLocked(block.number);
    }
    
    /**
     * Method for manually Locking fiunds
     **/
    function manualLockFunds() public onlyOwner{
        require(totalParticipationAmount != 0);
        require(CreditGAMEInterface(creditGameAddress).isGameApproved(address(this)) == true);
        require(gameState == state.closed);
        //transfer and lock tokens on game contract
        IERC20Token(tokenAddress).transfer(creditGameAddress, totalParticipationAmount);
        CreditGAMEInterface(creditGameAddress).createLock(winner, totalParticipationAmount, tokenLockDuration);
        totalLockedAmount = totalParticipationAmount;
        emit GameLocked(block.number);
    }
    
    
    function closeGame() public onlyOwner{
        gameState = state.closed;
    }
    
    /**
     * Method called by participants to unlock and transfer their funds 
     * First call to method transfers tokens from game contract to this contractđ
     * Last call to method cleans up the game contract
     **/
    function unlockFunds() public {
        require(gameState == state.closed);
        require(hasParticipated[msg.sender] == true);
        require(hasWithdrawn[msg.sender] == false);
        
        if(fundsTransfered == false){
            require(CreditGAMEInterface(creditGameAddress).checkIfLockCanBeRemoved(address(this)) == true);
            CreditGAMEInterface(creditGameAddress).removeLock();
            fundsTransfered = true;
            emit GameUnlocked(block.number);
        }
        
        hasWithdrawn[msg.sender] = true;
        uint index = participantIndexes[msg.sender];
        uint amount = participationAmount[index];
        IERC20Token(tokenAddress).transfer(msg.sender, amount);
        totalLockedAmount = IERC20Token(tokenAddress).balanceOf(address(this));
        if(totalLockedAmount == 0){
            CreditGAMEInterface(creditGameAddress).cleanUp();
        }
    }
    
    function checkInternalBalance() public view returns(uint256 tokenBalance) {
        return IERC20Token(tokenAddress).balanceOf(address(this));
    }
    
    function receiveApproval(address _from, uint256 _value, address _to, bytes _extraData) public {
        require(_to == tokenAddress);
        require(_value == leafPrice);
        require(gameState != state.closed);
        //check if game approved;
        require(CreditGAMEInterface(creditGameAddress).isGameApproved(address(this)) == true);

        uint tokensToTake = processTransaction(_from, _value);
        IERC20Token(tokenAddress).transferFrom(_from, address(this), tokensToTake);
    }

    function processTransaction(address _from, uint _value) internal returns (uint) {
        require(gameStart <= block.number);
        
        uint valueToProcess = 0;
        
        if(gameStart <= block.number && gameDuration >= block.number){
            if(gameState != state.running){
                gameState = state.running;
                emit GameStarted(block.number);
            }
            // take tokens
            leafOwners[numberOfLeafs] = _from;
            numberOfLeafs++;
            totalParticipationAmount += _value;
            
            //check if contributed before
            if(hasParticipated[_from] == false){
                hasParticipated[_from] = true;
                
                participants[participantIndex] = _from;
                participationAmount[participantIndex] = _value;
                participantIndexes[_from] = participantIndex;
                participantIndex++;
            }else{
                uint index = participantIndexes[_from];
                participationAmount[index] = participationAmount[index] + _value;
            }
            
            valueToProcess = _value;
            return valueToProcess;
        
        }else if(gameDuration < block.number){
            gameState = state.finished;
            pickWinner();
            return valueToProcess;
        }
    }

    function manuallyProcessTransaction(address _from, uint _value) onlyOwner public {
        require(_value == leafPrice);
        require(IERC20Token(tokenAddress).balanceOf(address(this)) >= _value + totalParticipationAmount);

        if(gameState == state.running && block.number < gameDuration){
            uint tokensToTake = processTransaction(_from, _value);
            IERC20Token(tokenAddress).transferFrom(_from, address(this), tokensToTake);
        }

    }

    function salvageTokensFromContract(address _tokenAddress, address _to, uint _amount) onlyOwner public {
        require(_tokenAddress != tokenAddress);
        IERC20Token(_tokenAddress).transfer(_to, _amount);
    }
}