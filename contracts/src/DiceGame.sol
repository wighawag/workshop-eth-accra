// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <= 0.9.0;


import "hardhat/console.sol";


/**
*@title Dice Game.
*@author ABossOfMyself.
*@notice Created a Dice Game contract that allows users to roll the dice to try and win the prize. If players roll either a "0", "1", or "2" they will win the current prize amount.
*/


contract DiceGame {
    event CommitmentMade(address indexed player, uint24 indexed epoch, bytes29 commitmentHash);
	event CommitmentVoid(address indexed player, uint24 indexed epoch);
	event CommitmentRevealed(
		address indexed player,
		uint24 indexed epoch,
		bytes29 indexed commitmentHash,
		bytes32 secret,
		uint8 num
	);
    event WinningWithdrawn(address indexed player, uint24 indexed epoch, uint8 roll, uint256 amount);


    uint256 internal constant COMMIT_PHASE_DURATION = 24 * 3600;
	uint256 internal constant RESOLUTION_PHASE_DURATION = 24 * 3600;
    uint256 internal constant ENTRY_COST = 0.002 ether;

    struct Commitment {
		bytes29 hash;
		uint24 epoch;
	}
    struct Game {
        uint256 prize;
        address[][8] players;
    }
    mapping(address => Commitment) _commitments;
    bytes32 rollHash;
    mapping(uint256 => Game) _games;

    function _epoch() internal view virtual returns (uint24 epoch, bool commiting) {
		uint256 epochDuration = COMMIT_PHASE_DURATION + RESOLUTION_PHASE_DURATION;
		uint256 timePassed = _timestamp();
		epoch = uint24(timePassed / epochDuration);
		commiting = timePassed - (epoch * epochDuration) < COMMIT_PHASE_DURATION;
	}

    function _timestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    function commit(bytes29 commitmentHash) external payable {
        require(msg.value >= ENTRY_COST *2, "Failed to send enough value");
        (uint24 epoch, bool commiting) = _epoch();
        
        require(commiting, "InResolutionPhase");

        _games[epoch].prize += msg.value / 2;

        Commitment storage commitment = _commitments[msg.sender];

        require(uint232(commitmentHash) != 0, "InvalidCommitmentHash");

		
		require(uint232(commitment.hash) == 0, "PreviousCommitmentNotResolved");

        _commitments[msg.sender] = Commitment({hash: commitmentHash, epoch: epoch});

        emit CommitmentMade(msg.sender, epoch, commitmentHash);
    }

    function reveal(bytes32 secret, uint8 num) external {
        Commitment storage commitment = _commitments[msg.sender];
		(uint24 epoch, bool commiting) = _epoch();

        require(num <9, "INVALID_CHOICE"); // Player need to be careful

        _games[epoch].players[num].push(msg.sender);

		require(!commiting, "InCommitmentPhase");
		require(uint232(commitment.hash) != 0, "NothingToResolve");
		require(commitment.epoch == epoch, "InvalidEpoch");

        bytes29 commitmentHash = _commitments[msg.sender].hash;
        require(uint232(commitmentHash) != 0, "NoCommitmentToReveal");

        bytes32 computedHash = keccak256(abi.encode(secret, num));

        require(computedHash == commitmentHash, "CommitHashNotMatching");

        rollHash = rollHash ^ secret;

        payable(msg.sender).transfer(ENTRY_COST); // we return the extra value used to ensure player reveal

        emit CommitmentRevealed(msg.sender, epoch, commitmentHash, secret, num);
    }

    function acknowledgedFailedReveal() external {
		Commitment storage commitment = _commitments[msg.sender];
		(uint24 epoch, ) = _epoch();
		require(uint232(commitment.hash) != 0, "NothingToResolve");
        require(commitment.epoch != epoch, "CanStillResolve");
		_commitments[msg.sender].hash = bytes29(0);
        emit CommitmentVoid(msg.sender, epoch);
	}

    function claimWinnings(uint24 epoch, uint256 i) external {
    
        uint8 roll = uint8(uint256(rollHash) % 8);
        address[] storage winners = _games[epoch].players[roll];
        address winner = winners[i];
        require(winner != address(0), "AlreadyClaimed");

        _games[epoch].players[roll][i] = address(0);

        uint256 amount = _games[epoch].prize / winners.length;

        (bool sent, ) = winner.call{value: amount}("");

        require(sent, "Failed to send Ether");

        emit WinningWithdrawn(winner, epoch, roll, amount);
    }

}