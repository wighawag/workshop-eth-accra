import {expect, describe, it} from 'vitest';
import './utils/viem-matchers';
import * as crypto from 'crypto';

import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {prefix_str} from 'workshop-eth-accra-common';
import {Deployment, loadAndExecuteDeployments} from 'rocketh';

import {getConnection, fetchContract} from './connection';

import artifacts from '../generated/artifacts';
import {network} from 'hardhat';
import { encodeAbiParameters, keccak256, parseEther } from 'viem';


export function randomSecret() {
	return (`0x` +
		[...crypto.getRandomValues(new Uint8Array(32))]
			.map((m) => ('0' + m.toString(16)).slice(-2))
			.join('')) as `0x${string}`;
}


export function prepareCommitment(num: number, secret: `0x${string}`) {
	const commitmentHash = keccak256(
		encodeAbiParameters(
			[
				{type: 'bytes32', name: 'secret'},
				{type: 'uint8', name: 'num'},
			],
			[secret, num]
		)
	).slice(0, 60) as `0x${string}`;

	return {secret, hash: commitmentHash, num};
}


async function deployDiceGame() {
	const {accounts, walletClient, publicClient} = await getConnection();
	const [deployer, ...otherAccounts] = accounts;

	const hash = await walletClient.deployContract({
		...artifacts.DiceGame,
		account: deployer,
	} as any); // TODO https://github.com/wagmi-dev/viem/issues/648

	const receipt = await publicClient.waitForTransactionReceipt({hash});

	if (!receipt.contractAddress) {
		throw new Error(`failed to deploy contract`);
	}

	return {
		diceGame: await fetchContract({address: receipt.contractAddress, abi: artifacts.DiceGame.abi}),
		otherAccounts,
		walletClient,
		publicClient,
	};	
}

describe('DiceGame', function () {
	describe('Deployment', function () {
		it('Should be already deployed', async function () {
			const {deployments} = await loadAndExecuteDeployments({
				provider: network.provider as any,
			});
			const diceGame = await fetchContract(
				deployments['DiceGame'] as Deployment<typeof artifacts.DiceGame.abi>
			);
			const prefix = await diceGame.read.prize();
			expect(prefix).to.equal(0n);
		});

		

		it('Should be able to commit', async function () {
			const {diceGame, otherAccounts, publicClient} = await loadFixture(deployDiceGame);
			const txHash = await diceGame.write.commit([`0x0000000000000000000000000000000000000000000000000000000001`], {
				account: otherAccounts[0],
				value: parseEther('0.004')
			});
			expect(await publicClient.waitForTransactionReceipt({hash: txHash})).to.includeEvent(
				diceGame.abi,
				'CommitmentMade'
			);
		});

		it('Should be able to commit and reveal', async function () {
			const {diceGame, otherAccounts, publicClient} = await loadFixture(deployDiceGame);
			const  {hash, num, secret} = prepareCommitment(3, randomSecret());
			const txHash = await diceGame.write.commit([hash], {
				account: otherAccounts[0],
				value: parseEther('0.004')
			});
			expect(await publicClient.waitForTransactionReceipt({hash: txHash})).to.includeEvent(
				diceGame.abi,
				'CommitmentMade'
			);

			// await diceGame.write.increaseTime([24*3600], {
			// 	account: admin,
			// });

			const txHashForReveal = await diceGame.write.reveal([secret, num], {
				account: otherAccounts[0],
			});

			

			
			expect(await publicClient.waitForTransactionReceipt({hash: txHashForReveal})).to.includeEvent(
				diceGame.abi,
				'CommitmentRevealed'
			);
		});
	});
});
