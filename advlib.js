/**
 * Copyright reelyActive 2015-2021
 * We believe in an open Internet of Things
 */


const utils = require('./utils');


/**
 * Process raw advertising packets into semantically meaningful information.
 * @param {Object} data The packet(s) as an array of, or as individual
 *                      hexadecimal-strings or Buffers.
 * @param {Array} processors The packet processor(s) to use, in order of
 *                priority.
 * @param {Array} interpreters The optional interpreter(s) to use, in order of
 *                priority.
 * @return {Object} The processed packets as JSON.
 */
function process(data, processors, interpreters) {
  
 try
{
if(!data || !Array.isArray(processors) || (processors.length < 1)) {
    return null;
  }

  let packets = data;
  let processedPackets = {};
  let isSomeValidPacket = false;
  let isSinglePacket = !Array.isArray(data);

  if(isSinglePacket) {
    packets = [ data ];
  }

  packets.forEach(function(packet) {
    let processedPacket = invokeProcessors(packet, processors);
    if(processedPacket !== null) {
      isSomeValidPacket = true;
      mergeProperties(processedPackets, processedPacket);
    }
  });
  
  if(isSomeValidPacket) {
    invokeInterpreters(processedPackets, interpreters);

    return processedPackets;
  }
} 
catch(e)
{
console.log("HELLO ERROR: "+e);
}
  return null;
}


/**
 * Process raw advertising packets into semantically meaningful information.
 * @param {Object} data The packet as a hexadecimal-string or Buffer.
 * @param {Array} processors The packet processor(s) to use, in order of
 *                priority.
 * @return {Object} The processed packet as JSON.
 */
function invokeProcessors(data, processors) {
  for(let cProcessor = 0; cProcessor < processors.length; cProcessor++) {
    let processor = processors[cProcessor].processor;
    let libraries = processors[cProcessor].libraries;
    let options = processors[cProcessor].options;
    let isValidProcessor = utils.hasFunction(processor, 'process');

    if(isValidProcessor) {
      let processedPacket = processor.process(data, libraries, options);
      if(processedPacket !== null) {
        return processedPacket;
      }
    } 
  }

  return null;
}


/**
 * Interpret processed packet to add/refine semantically meaningful information.
 * @param {Object} processedPacket The processed packet as JSON.
 * @param {Array} interpreters The packet interpreter(s) to use, in order of
 *                priority.
 */
function invokeInterpreters(processedPacket, interpreters) {
  if(Array.isArray(interpreters)) {
    for(const interpreter of interpreters) {
      let isValidInterpreter = utils.hasFunction(interpreter, 'interpret');

      if(isValidInterpreter) {
        interpreter.interpret(processedPacket);
      }
    }
  }
}


/**
 * Merge the properties of the source object into the target object, handling
 * duplicate properties appropriately.
 * @param {Object} target The target properties.
 * @param {Object} source The source properties.
 */
function mergeProperties(target, source) {
  for(property in source) {
    let isDuplicateProperty = target.hasOwnProperty(property);

    if(isDuplicateProperty) {
      switch(property) {
        case 'uuids':
        case 'deviceIds':
        case 'serviceData':
        case 'manufacturerSpecificData':
          source[property].forEach(function(item) {
            let isDuplicate = target[property].includes(item);
            if(!isDuplicate) {
              target[property].push(item);
            }
          }); 
          break;
        case 'interactionDigest':
          let isSameDigest = (target[property].timestamp ===
                              source[property].timestamp);
          if(isSameDigest) {
            source[property].interactions.forEach(function(interaction, index) {
              let isBeyond = (index >= target[property].interactions.length);
              if(isBeyond) {
                target[property].interactions.push(interaction);
              }
              else if(entry) {
                target[property].interactions[index] = interaction;
              }
            });
          }
          break;
      }
    }
    else {
      target[property] = source[property];
    }
  }
}


module.exports.process = process;
