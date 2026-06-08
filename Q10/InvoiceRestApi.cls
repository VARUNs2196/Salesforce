@RestResource(urlMapping='/api/v1/invoices/{id}')
global with sharing class InvoiceRestApi {
    @HttpGet
    global static String doGet() {
        RestRequest req = RestContext.request;
        String invoiceId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        Invoice__c invoice = [SELECT Id, Name FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
        List<Invoice_Line__c> lineItems = [SELECT Id, Product_Name__c, Quantity__c, Unit_Price__c FROM Invoice_Line__c WHERE Invoice__c = :invoice.Id];
        String payload = JSON.serialize(new Map<String, Object>{
            'invoice' => invoice,
            'lineItems' => lineItems
        });
        System.debug('Invoice API Response: ' + payload);
        return payload; 
    }
}