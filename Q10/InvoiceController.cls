public with sharing class InvoiceController {
    public List<Invoice_Line__c> lineItems { get; private set; }
    public Invoice__c invoice { get; private set; }

    public InvoiceController() {
        Id oppId = ApexPages.currentPage().getParameters().get('id');
        if (oppId != null) {
            List<Invoice__c> invoices = [SELECT Id, Name, Total_Gross__c FROM Invoice__c WHERE Opportunity__c = :oppId ORDER BY CreatedDate DESC LIMIT 1];
            if(!invoices.isEmpty()) {
                this.invoice = invoices[0];
                this.lineItems = [SELECT Id, Invoice__r.Name, Quantity__c, Unit_Price__c, Product_Name__c, Tax_Rate__c FROM Invoice_Line__c WHERE Invoice__c = :this.invoice.Id];
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Invoice_Line__c> getLineItems(Id opportunityId) {
        List<Invoice__c> invoices = [SELECT Id FROM Invoice__c WHERE Opportunity__c = :opportunityId ORDER BY CreatedDate DESC LIMIT 1];
        if(invoices.isEmpty()) return new List<Invoice_Line__c>();
        return [SELECT Id, Invoice__r.Name, Quantity__c, Unit_Price__c, Product_Name__c, Tax_Rate__c FROM Invoice_Line__c WHERE Invoice__c = :invoices[0].Id];
    }

    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getOpportunityLineItems(Id opportunityId) {
        return [SELECT Id, Quantity, UnitPrice, Name FROM OpportunityLineItem WHERE OpportunityId = :opportunityId];
    }

    @AuraEnabled(cacheable=false)
    public static String generateInvoice(Id opportunityId) {
        if (opportunityId == null) { return null; }
        
        try {
            Opportunity opp = [SELECT Id, Account.BillingCountryCode FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            String countryCode = opp.Account.BillingCountryCode != null ? opp.Account.BillingCountryCode : 'US';
            
            List<OpportunityLineItem> oppLineItems = [SELECT Id, Quantity, UnitPrice, Name FROM OpportunityLineItem WHERE OpportunityId = :opportunityId];
            List<Tax_Config__mdt> taxConfigs = [SELECT Standard_Rate__c FROM Tax_Config__mdt WHERE Country_Code__c = :countryCode LIMIT 1];
            Decimal standardRateField = (!taxConfigs.isEmpty()) ? taxConfigs[0].Standard_Rate__c : 0.0;
            
            Invoice__c newInvoice = new Invoice__c(
                Opportunity__c = opportunityId,
                Status__c = 'Draft'
            );
            insert newInvoice;
            
            List<Invoice_Line__c> linesToInsert = new List<Invoice_Line__c>();
            for (OpportunityLineItem oli : oppLineItems) {
                linesToInsert.add(new Invoice_Line__c(
                    Invoice__c = newInvoice.Id,
                    Product_Name__c = oli.Name,
                    Quantity__c = oli.Quantity,
                    Unit_Price__c = oli.UnitPrice,
                    Tax_Rate__c = standardRateField
                ));
            }
            insert linesToInsert;


            if(linesToInsert.size() <= 50) {
                PageReference pdfPage = Page.InvoiceGenerator; 
                pdfPage.getParameters().put('id', opportunityId);
                
                Blob blobFile;
                if (Test.isRunningTest()) {
                    blobFile = Blob.valueOf('Fake PDF Test Content');
                } else {
                    blobFile = pdfPage.getContent();
                }         
                ContentVersion cv = new ContentVersion(
                    Title = newInvoice.Name,
                    PathOnClient = 'Invoice.pdf',
                    VersionData = blobFile,
                    IsMajorVersion = true,
                    FirstPublishLocationId = opp.Id
                );
                insert cv;
                return pdfPage.getUrl();
            } else {
                System.enqueueJob(new InvoiceQueueable(newInvoice.Name, opportunityId));
                return 'ASYNC_PROCESS_STARTED';
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Could not generate invoice: ' + e.getMessage());
        }
    }
}