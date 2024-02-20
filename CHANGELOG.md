#0.0.9
- Update packages.
- Add unauthorizedRequestCodes to be able to handle different unauthorized request status codes returned from the api and fire onUnauthorizedRequestReceived callback.
- Add successRequestCodes to be able to handle different success request status codes returned from the api and fire onUnauthorizedRequestReceived callback.
- Enhance printing non api error messages.

#0.0.8
- Update packages.
- Add `statusCode` to `ApiException` to be able to handle different error status codes returned from the api.


#0.0.7
- Update packages.
- Bug fix, causing `onUnauthorizedRequestReceived` not called when receiving unauthorized request on certain cases.


#0.0.6
- Add ability to not handle unauthorized requests on each request.
- [Breaking Change]! : Each Network Exception now takes errorMessage of type String instead of exceptionMessage

#0.0.5 
- Enhancements for default error model.

#0.0.4
- Make `customHeaders` to be of type function that return a map to be updated correctly.

#0.0.3
- fix some bugs causing error not being reported successfully.

#0.0.2
- update from json to take dynamic json instead of map.

## 0.0.1 
- initial release
