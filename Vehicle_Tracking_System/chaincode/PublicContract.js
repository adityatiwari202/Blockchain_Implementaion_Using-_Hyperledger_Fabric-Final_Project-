'use strict';


const {Contract} = require('fabric-contract-api');




class PublicContract extends Contract 
{

	constructor() 
	{
		super('org.centralized-vehicle.regnet.publiccontract');	
    }   
	 
    async instantiate(ctx) 
	{
		console.log('Chaincode Instantiated');
	}
	
	async searchUser(ctx,name,id) 
	{		

		const obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.public', [name,id]);
		let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!dataBuffer.toString()) 
		{
			throw new Error('Cant perform transaction');
		} 
		else 
		{
			return JSON.parse(dataBuffer.toString());
		}
	}



	async searchCar(ctx,carId)
	{

		let obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.property', [carId]);
		let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!dataBuffer.toString()) 
		{
			throw new Error('No such vehicle exists');
		}

		return JSON.parse(dataBuffer.toString());
	}

    

	async enrollRequest(ctx,name,phone,id) 
	{
		
		if(ctx.clientIdentity.mspId!='publicNode')
		{
			throw new Error('Cant perform the Transaction');
		}
		
		const obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.public', [name,id]);	
		let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (dataBuffer.toString()) 
		{

			throw new Error('Invalid User Details. An user with this name & aadhaarNo already exists.');
		} 
		else 
		{
			
			let obj2 = 
			{
				
				name: name,
				phone:phone,
				id: id,
				status:'PENDING',
				createdBy: ctx.clientIdentity.getID(),
				createdAt: new Date(),
				updatedAt: new Date()
			}
			
			await ctx.stub.putState(obj, Buffer.from(JSON.stringify(obj2)));
			return obj2;
		}
	}


	

	async enrollCar(ctx,carId,price,status,name,id)
	{

		if('publicNode'!=ctx.clientIdentity.mspId)
		{
			throw new Error('Cant perform the Transaction');
		}

		
		const obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.public', [name,id]);
		let userDataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!userDataBuffer.toString()) 
		{
			throw new Error('Invalid User Details.');
		} 

		
		let obj2 = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.property.request', [carId]);
		let propDataBuffer = await ctx.stub.getState(obj2).catch(err => console.log(err));
		if (propDataBuffer.toString()) 
		{
			throw new Error('Car already registered');
		}


		
		

		let obj3 = 
		{
			carId: carId,
			price: parseInt(price),
			status: status,
			owner: obj,
			createdBy: ctx.clientIdentity.getID(),
			createdAt: new Date(),
			updatedBy: ctx.clientIdentity.getID(),
			updatedAt: new Date()
		};

		await ctx.stub.putState(obj2, Buffer.from(JSON.stringify(obj3)));
		return obj3;	
	}
	

	 
	 
	async fillWallet(ctx, name, id, amount) 
	{

		if(ctx.clientIdentity.mspId!='publicNode')
		{
			throw new Error('Cant perform the transaction');
		}

		const obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.public', [name,id]);
		let dataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!dataBuffer.toString()) 
		{
			throw new Error('Cant perform the Transaction');
		}

		
			
			let obj2 = JSON.parse(dataBuffer.toString());
			obj2.money += parseInt(amount);
			await ctx.stub.putState(obj, Buffer.from(JSON.stringify(obj2)));
			return obj2;

		
	}

	



	




	
	

	
	
	
	async updateCarStatus(ctx,cardId,status,name,id)
	{

		if(ctx.clientIdentity.mspId!='publicNode')
		{
			throw new Error('Cant perform this transaction');
		}
		
		
		let obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.property', [cardId]);
		let propDataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!propDataBuffer.toString()) 
		{
			throw new Error('Car already exists');
		}
		
		const obj2 = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.public', [name,id]);
		let userDataBuffer = await ctx.stub.getState(obj2).catch(err => console.log(err));
		if (!userDataBuffer.toString()) 
		{
			throw new Error('No such user found');
		} 

		
		

		let obj3 = JSON.parse(propDataBuffer.toString());
		if(obj2 == obj3.owner)
		{	
			obj3.status = status;
			obj3.updatedBy = ctx.clientIdentity.getID();	
			obj3.updatedAt = new Date();

			await ctx.stub.putState(obj, Buffer.from(JSON.stringify(obj3)));
			return obj3;

		} 
		else 
		{
			throw new Error('Cant perform Transaction as vehicle is others');
		}
	}



	
	async buyCar(ctx,carId,name,id)
	{
		
		if(ctx.clientIdentity.mspId!='publicNode')
		{
			throw new Error('Cant perform the transaction');
		}

		
		let obj = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.property', [carId]);
		let propDataBuffer = await ctx.stub.getState(obj).catch(err => console.log(err));
		if (!propDataBuffer.toString()) 
		{
			throw new Error('No such Car Exists');
		}
		
		const obj2 = ctx.stub.createCompositeKey('org.centralized-vehicle.regnet.user', [name,id]);
		let userDataBuffer = await ctx.stub.getState(obj2).catch(err => console.log(err));
		if (!userDataBuffer.toString()) 
		{
			throw new Error('Invalid User Details. No user exists with provided name & aadhaarNo combination.');
		} 

		
		let obj3 = JSON.parse(propDataBuffer.toString());
		if(obj3.status!='OPEN')
		{	
			throw new Error('Car cant be sold');
		}

		if(obj2 != obj3.owner)
		{

			let userObject = JSON.parse(userDataBuffer.toString());

			if(userObject.money >= obj3.price)
			{

				let ownerDataBuffer = await ctx.stub.getState(obj2).catch(err => console.log(err));
				let ownerUserObject = JSON.parse(ownerDataBuffer.toString());

				
				userObject.money = userObject.money - obj3.price;	
				ownerUserObject.money = ownerUserObject.money  + obj3.price;

				obj3.owner = obj2;
				obj3.status = 'REGISTERED';
				obj3.updatedBy = ctx.clientIdentity.getID();	
				obj3.updatedAt = new Date();

				await ctx.stub.putState(obj2, Buffer.from(JSON.stringify(userObject)));
				await ctx.stub.putState(obj, Buffer.from(JSON.stringify(obj3)));
				return obj3;
			}
			throw new Error('Not enough money');
		} 

		else 
		{
			throw new Error('Cant perform transaction');
		}
	}

	
}

module.exports = PublicContract;
