// index.js
import { dryrun, message, createDataItemSigner, result } from "@permaweb/aoconnect";
import { PermissionType } from 'arconnect';

export async function dryRunArweave(data) {
  try {
    const dryRunResult = await dryrun(data);
    console.log('Dry run result:', dryRunResult);
    return dryRunResult;
  } catch (error) {
    console.error('Dry run error:', error);
    return null;
  }
}

export async function signData(data) {
  try {
    const signer = createDataItemSigner();
    const signedData = await signer.sign(data);
    console.log('Signed data:', signedData);
    return signedData;
  } catch (error) {
    console.error('Sign data error:', error);
    return null;
  }
}

export async function PingPong() {
  console.log('Starting PingPong function');

  const data = { key: 'value' };

  if (!window.arweaveWallet) {
    console.error('ArConnect is not installed.');
    return;
  }

  try {
    await window.arweaveWallet.connect(['ACCESS_ADDRESS', 'SIGN_TRANSACTION']);
    console.log('ArConnect permissions granted.');
  } catch (error) {
    console.error('Error requesting ArConnect permissions:', error);
    return;
  }

  try {
    const address = await window.arweaveWallet.getActiveAddress();
    console.log('Active wallet address:', address);
    return address;
    
  } catch (error) {
    console.error('Error retrieving active address:', error);
  }

  console.log('Test function completed');
}

export async function test() {
  console.log('Starting test function');

  const data = { key: 'value' };

  if (!window.arweaveWallet) {
    console.error('ArConnect is not installed.');
    return;
  }

  try {
    await window.arweaveWallet.connect(['ACCESS_ADDRESS', 'SIGN_TRANSACTION']);
    console.log('ArConnect permissions granted.');
  } catch (error) {
    console.error('Error requesting ArConnect permissions:', error);
    return;
  }

  try {
    const address = await window.arweaveWallet.getActiveAddress();
    console.log('Active wallet address:', address);
    return address;
    
  } catch (error) {
    console.error('Error retrieving active address:', error);
  }

  console.log('Test function completed');
}

export async function GetProcessInfo(processID) { 
  console.log("processID: " + processID);
  
  try {
    const getResult = await message({
      process: processID,
      tags: [
        { name: 'Action', value: 'Info' },
      ],
      signer: createDataItemSigner(window.arweaveWallet),
    });

    const { Messages, Error: AOError } = await result({
      message: getResult,
      process: processID,
    });

    if (AOError) {
      console.log("Error:" + AOError);
      return "Error:" + AOError;
    }
    if (!Messages || Messages.length === 0) {
      console.log("No messages were returned from AO. Please try later.");
      return "No messages were returned from AO. Please try later."; 
    }
    
    console.log('Success:', Messages[0]);
    return Messages[0].Data;
  } catch (error) {
    console.log('There was an error retrieving process info:', error);
    return "Error";
  }
}

export async function SendProcessMessage(processID, action, data) { 
  console.log("processID: " + processID);
  
  try {
    const getResult = await message({
      process: processID,
      tags: [
        { name: 'Action', value: action },
      ],
      data: "" + data,
      signer: createDataItemSigner(window.arweaveWallet),
    });

    const { Messages, Error: AOError } = await result({
      message: getResult,
      process: processID,
    });

    if (AOError) {
      console.log("Error:" + AOError);
      return "Error:" + AOError;
    }
    if (!Messages || Messages.length === 0) {
      console.log("No messages were returned from AO. Please try later.");
      return "No messages were returned from AO. Please try later."; 
    }
    
    console.log('Success:', Messages[0]);
    return Messages[0].Data;
  } catch (error) {
    console.log('There was an error sending process message:', error);
    return "Error";
  }
}

export async function SendProcessDryrun( processID, action, data) {
  try {
    const dryrunResult = await dryrun({
      process: processID,
      tags: [
        { name: 'Action', value: action },
      ],
      data: data,
      signer: createDataItemSigner(window.arweaveWallet),
    });

    if (dryrunResult && dryrunResult.Messages && dryrunResult.Messages.length > 0) {
      const message = dryrunResult.Messages[0];

      // console.log("Dryrun Message: ", message);
      console.log("Dryrun Data: ", message.Data);

      // console.log("Anchor: ", message.Anchor);
      // console.log("Target: ", message.Target);
      // console.log("Timestamp: ", message.Timestamp);

      const tickerTag = message.Tags.find(tag => tag.name === "Ticker");
      const tickerValue = tickerTag ? tickerTag.value : "No Ticker";

      // console.log("Ticker: ", tickerValue);

      return JSON.stringify({
        anchor: message.Anchor,
        target: message.Target,
        ticker: tickerValue,
      });

      // return message.Data;

    } else {
      console.log("No response from dryrun!");
      return "Got no response from dryrun!";
    }

  } catch (error) {
    console.log('There was an error during dryrun: ' + error);
    return "Error";
  }
}

window.UnityAO = {
  dryRunArweave,
  signData,
  test,
  GetProcessInfo,
  SendProcessMessage,
  SendProcessDryrun
};
