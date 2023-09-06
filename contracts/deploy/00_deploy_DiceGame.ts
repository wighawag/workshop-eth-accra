import {execute} from 'rocketh';
import 'rocketh-deploy-proxy';
import {context} from './_context';

export default execute(
	context,
	async ({deployViaProxy, accounts, artifacts}) => {
		const contract = await deployViaProxy(
			'DiceGame',
			{
				account: accounts.deployer,
				artifact: artifacts.DiceGame
			},
			{
				owner: accounts.deployer,
			}
		);
	},
	{tags: ['DiceGame', 'DiceGame_deploy']}
);
