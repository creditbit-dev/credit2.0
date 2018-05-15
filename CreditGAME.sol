//LATEST version

pragma solidity ^0.4.21;

import "./Interfaces/IERC20Token.sol";
import "./Utils/Owned.sol";
import "./Utils/SafeMath.sol";
import "./Utils/LinkedList.sol";

contract ICreditBIT{
    function claimGameReward(address _champion, uint _lockedTokenAmount, uint _lockTime) returns (uint error);
}

contract CreditGAME is Owned, SafeMath, LinkedList{
    
    mapping(address => bool) approvedGames;
    mapping(address => GameLock) gameLocks;
    mapping(address => bool) public isGameLocked;
    
    uint public amountLocked = 0;
    

    struct GameLock{
        address gameAddress;
        uint amount;
        uint lockDuration;
    }
    
    event LockParameters(address gameAddress, uint totalParticipationAmount, uint tokenLockDuration);
    event UnlockParameters(address gameAddress, uint totalParticipationAmount);
    event CleanUp(address gameAddress);
    
    uint public totalTokenAmount = 0;

    //SET TOKEN ADDRESS BEFORE DEPLOY
    address public tokenAddress = 0x692a70d2e424a56d2c6c27aa97d1a86395877b3a;
    
    function setTokenAddress(address _tokenAddress) onlyOwner public {
        tokenAddress = _tokenAddress;
    }
    
    function addApprovedGame(address _gameAddress) onlyOwner public{
        approvedGames[_gameAddress] = true;
    }
    
    function removeApprovedGame(address _gameAddress) onlyOwner public{
        approvedGames[_gameAddress] = false;
    }
    
    function isGameApproved(address _gameAddress) view public returns(bool){
        if(approvedGames[_gameAddress] == true){
            return true;
        }else{
            return false;
        }
    }
    
    /**
     * Funds must be transfered by calling contract before calling this contract. 
     * msg.sender is address of calling contract that must be approved.
     * 
     **/
    function createLock(address _winner, uint _totalParticipationAmount, uint _tokenLockDuration) public {
        require(approvedGames[msg.sender] == true);
        require(isGameLocked[msg.sender] == false);
        
        //Create gameLock
        GameLock memory gameLock = GameLock(msg.sender, _totalParticipationAmount, _tokenLockDuration);
        gameLocks[msg.sender] = gameLock;
        isGameLocked[msg.sender] = true;
        addItem(msg.sender);
        amountLocked = safeAdd(amountLocked, _totalParticipationAmount);
        totalTokenAmount = IERC20Token(tokenAddress).balanceOf(address(this));
        emit LockParameters(msg.sender, _totalParticipationAmount, _tokenLockDuration);
        
        //Transfer game credits to winner
        ICreditBIT(tokenAddress).claimGameReward(_winner, _totalParticipationAmount, _tokenLockDuration);
    }
    
    function checkInternalBalance() public view returns(uint256 tokenBalance) {
        return IERC20Token(tokenAddress).balanceOf(address(this));
    }
    
    /**
     * Method called by game contract
     * msg.sender is address of calling contract that must be approved.
     **/
    function removeLock() public{
        require(approvedGames[msg.sender] == true);
        require(isGameLocked[msg.sender] == true);
        require(checkIfLockCanBeRemoved(msg.sender) == true);
        GameLock memory gameLock = gameLocks[msg.sender];
        
        //transfer tokens to game contract
        IERC20Token(tokenAddress).transfer(msg.sender, gameLock.amount);
        
        //clean up
        amountLocked = safeSub(amountLocked, gameLock.amount);
        totalTokenAmount = IERC20Token(tokenAddress).balanceOf(address(this));
        
        delete(gameLocks[msg.sender]);
        isGameLocked[msg.sender] = false;
        emit UnlockParameters(msg.sender, gameLock.amount);
    }
    
    /**
     * Method called by game contract when last participant has withdrawn
     * msg.sender is address of calling contract that must be approved.
     **/
    function cleanUp() public{
        require(approvedGames[msg.sender] == true);
        require(isGameLocked[msg.sender] == false);
        removeItem(msg.sender);
        emit CleanUp(msg.sender);
    }
    
    function getGameLock(address _gameAddress) public view returns(address, uint, uint){
        require(isGameLocked[_gameAddress] == true);
        GameLock memory gameLock = gameLocks[_gameAddress];
        return(gameLock.gameAddress, gameLock.amount, gameLock.lockDuration);
    }
    
    function checkIfLockCanBeRemoved(address _gameAddress) public view returns(bool){
        require(approvedGames[_gameAddress] == true);
        require(isGameLocked[_gameAddress] == true);
        GameLock memory gameLock = gameLocks[_gameAddress];
        if(gameLock.lockDuration < block.number){
            return true;
        }else{
            return false;
        }
    }
    
    //Debugging purposes
    function getCurrentBlock() public view returns(uint){
        return block.number;
    }

}