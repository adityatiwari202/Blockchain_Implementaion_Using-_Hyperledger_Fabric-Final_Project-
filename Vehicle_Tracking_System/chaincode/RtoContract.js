'use strict';


const {Contract} = require('fabric-contract-api');



class RtoContract extends Contract 
{

    constructor() 
	{
		super('org.centralized-vehicle.regnet');
    }    

    async instantiate(ctx) 
	{
		console.log('Chaincode Instantiated');
	}
	
	
	async searchUser(ctx, name, id) 
	{		

		const obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.public', [name,id]);
		let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!dataBuffer.toString()) 
		{
			throw new Error('No such user in the network');
		} 
		else 
		{
			return JSON.parse(dataBuffer.toString());
		}
	}

	

	async approveUser(ctx, name, id) 
	{

		if(ctx.clientIdentity.mspId=='rtoNode')
		{
			const obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.public', [name,id]);
			let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
			if (!dataBuffer.toString()) 
			{
				throw new Error('No such user in the network');
			} 

			else 
			{
				let item = JSON.parse(dataBuffer.toString());
				item.status = 'APPROVED';
				item.money = 0;
				item.updatedBy = ctx.clientIdentity.getID();
				item.updatedAt = new Date();
				
				await ctx.stub.putState(obj, Buffer.from(JSON.stringify(item)));
				return item;	
			}
		}

		else 
		{
			throw new Error('You cant perform this transcation');
		}
	}
	
	
	async searchCar(ctx,carid)
	{
		let obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.property', [carid]);
		let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!dataBuffer.toString()) 
		{
			throw new Error('This vehicle is already registered');
		} 
		return JSON.parse(dataBuffer.toString());
	}

	
	async approveCar(ctx,carid)
	{

		if(ctx.clientIdentity.mspId=='rtoNode')
		{
			let obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.property.request', [carid]);
			let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
			if (!dataBuffer.toString()) 
			{
				throw new Error('Cant perform the transaction');
			} 
			else 
			{

				let item = JSON.parse(dataBuffer.toString());
				item.status = 'REGISTERED';
				item.updatedBy = ctx.clientIdentity.getID();	
				item.updatedAt = new Date();

				let item2 = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.property', [carid]);
				await ctx.stub.putState(item2, Buffer.from(JSON.stringify(item)));
				return item;
			}
		}

		else 
		{
			throw new Error('cant perform the transaction');
		}	
	}

}

module.exports = RtoContract;