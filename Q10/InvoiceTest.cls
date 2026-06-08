@isTest
private class InvoiceTest {

    @testSetup
    static void setupData() {
        Account accIn = new Account(Name = 'IN Test Account', BillingCountryCode = 'IN');
        Account accCA = new Account(Name = 'CA Test Account', BillingCountryCode = 'CA');
        insert new List<Account>{accIn, accCA};

        Opportunity oppIn = new Opportunity(
            Name = 'IN Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = accIn.Id
        );
        Opportunity oppCA = new Opportunity(
            Name = 'CA Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = accCA.Id
        );
        insert new List<Opportunity>{oppIn, oppCA};
        Id pricebookId = Test.getStandardPricebookId();
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100.0,
            IsActive = true
        );
        insert pbe;
        OpportunityLineItem oliIn = new OpportunityLineItem(
            OpportunityId = oppIn.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            TotalPrice = 200.0
        );
        OpportunityLineItem oliCA = new OpportunityLineItem(
            OpportunityId = oppCA.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 3,
            TotalPrice = 300.0
        );
        insert new List<OpportunityLineItem>{oliIn, oliCA};
    }

    @isTest
    static void testConstructorAndGetters() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'IN Opp' LIMIT 1];
        PageReference pageRef = Page.InvoiceGenerator;
        pageRef.getParameters().put('id', opp.Id);
        Test.setCurrentPage(pageRef);
        InvoiceController.generateInvoice(opp.Id);

        Test.startTest();
        InvoiceController controller = new InvoiceController();
        List<Invoice_Line__c> lines = InvoiceController.getLineItems(opp.Id);
        List<OpportunityLineItem> oppLines = InvoiceController.getOpportunityLineItems(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, controller.invoice, 'Invoice should be populated in constructor context');
        System.assertEquals(1, lines.size(), 'Should retrieve one invoice line item via wire method');
        System.assertEquals(1, oppLines.size(), 'Should retrieve one opportunity line item via wire method');
    }

    @isTest
    static void testSynchronousGenerationAndTaxIN() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'IN Opp' LIMIT 1];

        PageReference pageRef = Page.InvoiceGenerator;
        pageRef.getParameters().put('id', opp.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        String returnUrl = InvoiceController.generateInvoice(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, returnUrl, 'Should return a string path response');
        System.assert(returnUrl.toLowerCase().contains('invoicegenerator'), 'Should return a valid path containing page signature reference string. Got: ' + returnUrl);

        List<ContentVersion> cvs = [SELECT Id, Title, FirstPublishLocationId FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
        System.assertEquals(1, cvs.size(), 'A ContentVersion document file should be automatically generated and linked');

        List<Invoice_Line__c> generatedLines = [SELECT Id, Tax_Rate__c, Unit_Price__c FROM Invoice_Line__c WHERE Invoice__r.Opportunity__c = :opp.Id];
        System.assertEquals(1, generatedLines.size(), 'One invoice line item should exist');
        System.assertEquals(100.0, generatedLines[0].Unit_Price__c, 'Unit Price should copy over from OpportunityLineItem');
    }

    @isTest
    static void testSynchronousGenerationAndTaxCA() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'CA Opp' LIMIT 1];

        PageReference pageRef = Page.InvoiceGenerator;
        pageRef.getParameters().put('id', opp.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        String returnUrl = InvoiceController.generateInvoice(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, returnUrl, 'Return URL should be generated');
        System.assert(returnUrl.toLowerCase().contains('invoicegenerator'), 'Should safely map target page structure path string. Got: ' + returnUrl);
        
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
        System.assertEquals(1, cvs.size(), 'ContentVersion record creation verified');
    }

    @isTest
    static void testAsynchronousQueueableProcessing() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Name = 'IN Opp' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        List<OpportunityLineItem> bulkLines = new List<OpportunityLineItem>();
        for(Integer i = 0; i < 55; i++) {
            bulkLines.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                TotalPrice = 100.0
            ));
        }
        insert bulkLines;

        PageReference pageRef = Page.InvoiceGenerator;
        pageRef.getParameters().put('id', opp.Id);
        Test.setCurrentPage(pageRef);
        Test.startTest();
        String returnToken = InvoiceController.generateInvoice(opp.Id);
        Test.stopTest(); 

        System.assertEquals('ASYNC_PROCESS_STARTED', returnToken, 'Should route process flow path down asynchronous pipeline channel rules');
        
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
        System.assert(cvs.size() > 0, 'Asynchronous job should execute and insert the target ContentVersion file artifact item context');
    }
}