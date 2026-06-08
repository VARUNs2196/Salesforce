@RestResource(urlMapping='/docusign/webhook')
global without sharing class DocuSignWebhookController {
    private static final String HMAC_SECRET = '8IQGQW3+B2CC+DQt55vxJSgwjNj7nJC6PBxKjxmqd4g=';

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestBodyStr = req.requestBody.toString();
        String receivedSignature = req.headers.get('X-DocuSign-Signature-1');
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(requestBodyStr), Blob.valueOf(HMAC_SECRET));
        String calculatedSignature = EncodingUtil.base64Encode(mac);
        
        if (receivedSignature == null || !receivedSignature.equals(calculatedSignature)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Unauthorized: HMAC validation failed.');
            System.debug('*** SECURITY ALERT: Unauthorized webhook attempt blocked. Signatures do not match.');
            return;
        }
        
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(requestBodyStr);
            String envelopeId = (String) payload.get('envelopeId');
            Id opportunityId = null;
            if (payload.containsKey('customFields')) {
                Map<String, Object> customFields = (Map<String, Object>) payload.get('customFields');
                if (customFields.containsKey('textCustomFields')) {
                    List<Object> textFields = (List<Object>) customFields.get('textCustomFields');
                    for (Object fieldObj : textFields) {
                        Map<String, Object> field = (Map<String, Object>) fieldObj;
                        if ('OpportunityId'.equalsIgnoreCase((String) field.get('name'))) {
                            opportunityId = (Id) field.get('value');
                            break;
                        }
                    }
                }
            }
            Envelope_Event__c event = new Envelope_Event__c();
            event.Envelope_Id__c = envelopeId;
            event.Raw_Payload__c = requestBodyStr;
            event.Status__c = 'Received';
            event.Opportunity__c = opportunityId;
            
            upsert event Envelope_Id__c;
            System.enqueueJob(new DocuSignEnvelopeProcessor(event.Id));
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Webhook received and queued successfully.');
            
        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Internal Server Error: ' + ex.getMessage());
            System.debug('*** ERROR processing DocuSign webhook: ' + ex.getMessage());
        }
    }
}