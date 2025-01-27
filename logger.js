const Barnowl = require('barnowl');
const BarnowlMinew = require('barnowl-minew');
const Barnacles = require('barnacles');
const BarnaclesLogfile = require('barnacles-logfile');
const Raddec = require('raddec');
const RaddecFilter = require('raddec-filter');
const express = require('express');
const http = require('http');


// -----------------------------------------------------------------------------
// To filter only on specific devices, uncomment the
// acceptedTransmitterSignatures and add all devices signatures to the array
// -----------------------------------------------------------------------------
const FILTER_PARAMETERS = {
    // acceptedTransmitterSignatures: [ 'e55264d41659/0', '112233445566/0' ]
}

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

let barnowl = new Barnowl({ enableMixing: true });
let app = express();
let server = http.createServer(app);
server.listen(3001, function() { console.log('Listening on port 3001'); });
let options = { app: app, express: express, route: "/minew",
                isPreOctetStream: false }; // Set true for G1 firmware v2/3
barnowl.addListener(BarnowlMinew, {}, BarnowlMinew.HttpListener, options);

barnowl.on('raddec', (raddec) => {
  raddec.timestamp = Date.now();
  //console.log(raddec);
    if((raddec !== null) && filter.isPassing(raddec)) {
      raddec.transmitterIdType = Raddec.identifiers.TYPE_RND48;
      barnacles.handleRaddec(raddec);
    }
});
