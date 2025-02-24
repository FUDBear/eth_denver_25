mergeInto(LibraryManager.library, {
  dryRunArweave: function (dataPtr, dataLength, callbackPtr, callbackArg) {
    var data = UTF8ToString(dataPtr, dataLength);

    UnityAO.dryRunArweave(data)
      .then(function (result) {
        var length = lengthBytesUTF8(result) + 1;
        var resultPtr = _malloc(length);
        stringToUTF8(result, resultPtr, length);
        dynCall_vi(callbackPtr, resultPtr); // Call Unity callback with result
      })
      .catch(function (error) {
        console.error("Error in dryRunArweave:", error);
        var errorMsg = "Error: " + error;
        var length = lengthBytesUTF8(errorMsg) + 1;
        var errorPtr = _malloc(length);
        stringToUTF8(errorMsg, errorPtr, length);
        dynCall_vi(callbackPtr, errorPtr); // Send error back to Unity
      });
  },

  signData: function (dataPtr, dataLength, callbackPtr, callbackArg) {
    var data = UTF8ToString(dataPtr, dataLength);

    UnityAO.signData(data)
      .then(function (signedData) {
        var length = lengthBytesUTF8(signedData) + 1;
        var dataPtr = _malloc(length);
        stringToUTF8(signedData, dataPtr, length);
        dynCall_vi(callbackPtr, dataPtr); // Pass signed data back to Unity
      })
      .catch(function (error) {
        console.error("Error in signData:", error);
        var errorMsg = "Error: " + error;
        var length = lengthBytesUTF8(errorMsg) + 1;
        var errorPtr = _malloc(length);
        stringToUTF8(errorMsg, errorPtr, length);
        dynCall_vi(callbackPtr, errorPtr); // Pass error to Unity
      });
  },

  test: function (callbackPtr, callbackArg) {
    UnityAO.test()
      .then(function (address) {
        var length = lengthBytesUTF8(address) + 1;
        var addressPtr = _malloc(length);
        stringToUTF8(address, addressPtr, length);
        dynCall_vi(callbackPtr, addressPtr); // Pass address to Unity
      })
      .catch(function (error) {
        console.error("Error in test:", error);
        var errorMsg = "Error: " + error;
        var length = lengthBytesUTF8(errorMsg) + 1;
        var errorPtr = _malloc(length);
        stringToUTF8(errorMsg, errorPtr, length);
        dynCall_vi(callbackPtr, errorPtr); // Pass error to Unity
      });
  },

  GetProcessInfo: function (processIDPtr, callbackPtr, callbackArg) {
    var processID = UTF8ToString(processIDPtr);

    UnityAO.GetProcessInfo(processID)
      .then(function (info) {
        var length = lengthBytesUTF8(info) + 1;
        var infoPtr = _malloc(length);
        stringToUTF8(info, infoPtr, length);
        dynCall_vi(callbackPtr, infoPtr); // Pass info back to Unity
      })
      .catch(function (error) {
        console.error("Error in GetProcessInfo:", error);
        var errorMsg = "Error: " + error;
        var length = lengthBytesUTF8(errorMsg) + 1;
        var errorPtr = _malloc(length);
        stringToUTF8(errorMsg, errorPtr, length);
        dynCall_vi(callbackPtr, errorPtr); // Pass error to Unity
      });
  },

  SendProcessMessage: function (processIDPtr, actionPtr, dataPtr, callbackPtr, callbackArg) {
    var processID = UTF8ToString(processIDPtr);
    var action = UTF8ToString(actionPtr);
    var data = UTF8ToString(dataPtr);

    UnityAO.SendProcessMessage(processID, action, data)
      .then(function (response) {
        var length = lengthBytesUTF8(response) + 1;
        var responsePtr = _malloc(length);
        stringToUTF8(response, responsePtr, length);
        dynCall_vi(callbackPtr, responsePtr); // Pass response to Unity
      })
      .catch(function (error) {
        console.error("Error in SendProcessMessage:", error);
        var errorMsg = "Error: " + error;
        var length = lengthBytesUTF8(errorMsg) + 1;
        var errorPtr = _malloc(length);
        stringToUTF8(errorMsg, errorPtr, length);
        dynCall_vi(callbackPtr, errorPtr); // Pass error to Unity
      });
  },

  SendProcessDryrun: function (processIDPtr, actionPtr, dataPtr, callbackPtr, callbackArg) {
    var processID = UTF8ToString(processIDPtr);
    var action = UTF8ToString(actionPtr);
    var data = UTF8ToString(dataPtr);

    UnityAO.SendProcessDryrun(processID, action, data)
      .then(function (result) {
        var length = lengthBytesUTF8(result) + 1;
        var resultPtr = _malloc(length);
        stringToUTF8(result, resultPtr, length);
        dynCall_vi(callbackPtr, resultPtr); // Pass result to Unity
      })
      .catch(function (error) {
        console.error("Error in SendProcessDryrun:", error);
        var errorMsg = "Error: " + error;
        var length = lengthBytesUTF8(errorMsg) + 1;
        var errorPtr = _malloc(length);
        stringToUTF8(errorMsg, errorPtr, length);
        dynCall_vi(callbackPtr, errorPtr); // Pass error to Unity
      });
  },

  FreeMemory: function (ptr) {
    _free(ptr); // Free allocated memory on the WASM heap
  }
});
