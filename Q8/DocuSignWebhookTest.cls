@isTest
public class DocuSignWebhookTest {

    private class MockDocuSignCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('Test PDF Content'));
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testValidWebhook() {
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        insert opp;

        String requestBody = '{"envelopeId":"test-env-123","customFields":{"textCustomFields":[{"name":"OpportunityId","value":"' + opp.Id + '"}]}}';
        String hmacSecret = '8IQGQW3+B2CC+DQt55vxJSgwjNj7nJC6PBxKjxmqd4g=';
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(requestBody), Blob.valueOf(hmacSecret));
        String signature = EncodingUtil.base64Encode(mac);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/docusign/webhook';
        req.httpMethod = 'POST';
        req.headers.put('X-DocuSign-Signature-1', signature);
        req.requestBody = Blob.valueOf(requestBody);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.setMock(HttpCalloutMock.class, new MockDocuSignCallout());

        Test.startTest();
        DocuSignWebhookController.doPost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        
        List<Envelope_Event__c> events = [SELECT Id, Envelope_Id__c, Status__c, Opportunity__c FROM Envelope_Event__c];
        System.assertEquals(1, events.size());
        System.assertEquals('test-env-123', events[0].Envelope_Id__c);
        System.assertEquals('Completed', events[0].Status__c);
        System.assertEquals(opp.Id, events[0].Opportunity__c);
    }

    @isTest
    static void testInvalidWebhookSignature() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/docusign/webhook';
        req.httpMethod = 'POST';
        req.headers.put('X-DocuSign-Signature-1', 'invalid-sig');
        req.requestBody = Blob.valueOf('{"envelopeId":"test-env-123"}');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DocuSignWebhookController.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        
        List<Envelope_Event__c> events = [SELECT Id FROM Envelope_Event__c];
        System.assertEquals(0, events.size());
    }

    @isTest
    static void testRetryController() {
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        insert opp;

        Envelope_Event__c event = new Envelope_Event__c(
            Envelope_Id__c = 'test-env-123',
            Status__c = 'Failed',
            Opportunity__c = opp.Id,
            Retry_Count__c = 0
        );
        insert event;

        Test.setMock(HttpCalloutMock.class, new MockDocuSignCallout());

        Test.startTest();
        DocuSignRetryController.retryEnvelopeProcessing(opp.Id);
        Test.stopTest();

        Envelope_Event__c updatedEvent = [SELECT Status__c, Retry_Count__c FROM Envelope_Event__c WHERE Id = :event.Id];
        System.assertEquals('Completed', updatedEvent.Status__c);
        System.assertEquals(1, updatedEvent.Retry_Count__c);
    }

    @isTest
    static void testGetSplitDocuments() {
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        insert opp;

        ContentVersion cv = new ContentVersion(
            Title = 'Signed_DocuSign_Envelope_test-env-123',
            PathOnClient = 'Signed_Agreement.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = opp.Id
        );
        insert cv;

        Test.startTest();
        List<ContentVersion> results = DocuSignRetryController.getSplitDocuments(opp.Id);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Signed_DocuSign_Envelope_test-env-123', results[0].Title);
    }
}