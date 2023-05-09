'use strict';

const PublicContract = require('./PublicContract.js');
const RtoContract = require('./RtoContract.js');

module.exports.PublicContract = PublicContract;
module.exports.RtoContract = RtoContract;

module.exports.contracts = [PublicContract,RtoContract];