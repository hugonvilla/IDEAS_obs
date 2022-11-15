const dgram = require('dgram');
const server = dgram.createSocket('udp4');
const Barnacles = require('barnacles');
const BarnaclesLogfile = require('barnacles-logfile');
const Raddec = require('raddec');
const RaddecFilter = require('raddec-filter');


// -----------------------------------------------------------------------------
// To filter only on specific devices, uncomment the
// acceptedTransmitterSignatures and add all devices signatures to the array
// -----------------------------------------------------------------------------
const FILTER_PARAMETERS = {
    //acceptedTransmitterSignatures: [ 'e55264d41659/3', '112233445566/3' ]
}
const RADDEC_PORT = process.env.RADDEC_PORT || 50001;
const BARNACLES_OPTIONS = {
    packetProcessors: [
      { processor: require('advlib-ble'),
        libraries: [ require('advlib-ble-services'),
                     require('advlib-ble-manufacturers') ] }
    ]
};
const BARNACLES_LOGFILE_OPTIONS = { eventsToLog: { raddec:{}, dynamb: {} } };


let filter = new RaddecFilter(FILTER_PARAMETERS);
let barnacles = new Barnacles(BARNACLES_OPTIONS);
barnacles.addInterface(BarnaclesLogfile, BARNACLES_LOGFILE_OPTIONS);

server.on('message', function(msg) {
  try {
    let raddec = new Raddec(msg);

    if((raddec !== null) && filter.isPassing(raddec)) {
      barnacles.handleRaddec(raddec);
    }
  }
  catch(error) {};
});

server.bind(RADDEC_PORT);

console.log('barnacles instance is listening for raddecs on port', RADDEC_PORT);