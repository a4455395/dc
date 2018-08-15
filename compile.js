const path = require('path');
const fs = require('fs');
const solc = require('solc');

const _path = path.resolve(__dirname, 'contracts', 'all.sol');
const source = fs.readFileSync(_path, 'utf8');

// console.log(solc.compile(source, 1).contracts[':IParticipantService']);

module.exports = {
    ParticipantService: solc.compile(source, 1).contracts[':ParticipantService'],
    Project: solc.compile(source, 1).contracts[':Project']
};