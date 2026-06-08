@isTest
private class RestApiTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Amount = 1000.00
        );
        insert opp;
        System.debug('Inserted Opportunity Id: ' + opp);
        Id pricebookId = Test.getStandardPricebookId();
        
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Quantity = 2,
            UnitPrice = 100.00,
            PricebookEntryId = pbe.Id
        );
        insert oli;
    }

    @isTest
    static void testV1GetByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/v1/Opportunities/';
        req.httpMethod = 'GET';
        req.params.put('AccountId', acc.Id);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi.OpportunityWrapper result = RestApi.doGet();
        Test.stopTest();
        Assert.areEqual(1, result.oppList.size(), 'Should return exactly one opportunity');
    }

    @isTest
    static void testV2GetWithMargin() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        System.debug('Testing with Opportunity Id inside: ' + opp.Id);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/v2/Opportunities/' + opp.Id;
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi.OpportunityWrapper result = RestApiV2.doGet();
        System.debug('Received wrapper in test: ' + result);
        Test.stopTest();

        Assert.isNotNull(result, 'Wrapper should not be null');
        Assert.isNotNull(result.opp, 'Single opportunity should be populated');
        Assert.areEqual('0.00%', result.GrossMargin, 'Gross margin calculation is incorrect');
    }

    @isTest
    static void testPostWithoutPermission403() {
        User standardUser = createNoAccessUser();

        System.runAs(standardUser) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            
            req.requestURI = '/services/apexrest/v1/Opportunities/006000000000000AAA';
            req.httpMethod = 'POST';

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            RestApi.doPost('Test Product', 100.00, 5);
            Test.stopTest();

            Assert.areEqual(403, res.statusCode, 'Should return status 403 when user lacks custom permission');
        }
    }
@isTest
static void testPostRollbackOnFailure() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Integer countBefore = [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
    User privilegedUser = createNoAccessUser();
    insert privilegedUser;
    grantCustomPermission(privilegedUser, 'Partner_Write_Access');

    System.runAs(privilegedUser) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/v1/Opportunities/' + opp.Id;
        req.httpMethod = 'POST';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi.doPost('NON_EXISTENT_PRODUCT_NAME_FOR_TEST', 100.00, 5);
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        Assert.areEqual(countBefore, countAfter, 'The transaction should roll back entirely upon failure');
    }
}
    @isTest
    static void testDeleteOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        User privilegedUser = createNoAccessUser();
        insert privilegedUser;
        grantCustomPermission(privilegedUser, 'Partner_Write_Access');

        System.runAs(privilegedUser) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            
            req.requestURI = '/services/apexrest/v1/Opportunities/' + opp.Id;
            req.httpMethod = 'DELETE';

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            RestApi.doDelete();
            Test.stopTest();

            Opportunity updatedOpp = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
            Assert.areEqual('Closed Lost', updatedOpp.StageName, 'Opportunity stage should update to Closed Lost');
        }
    }
    private static User createNoAccessUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        return new User(
            Alias = 'noacc', 
            Email='noaccessuser@testorg.com',
            EmailEncodingKey='UTF-8', 
            LastName='Testing', 
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', 
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='noaccessuser' + DateTime.now().getTime() + '@testorg.com'
        );
    }
    private static void grantCustomPermission(User targetUser, String customPermissionName) {
        CustomPermission customPerm = [
            SELECT Id FROM CustomPermission 
            WHERE DeveloperName = :customPermissionName 
            LIMIT 1
        ];
        
        PermissionSet ps = new PermissionSet(
            Name = 'Test_API_Assignment_PS', 
            Label = 'Test API Assignment PS'
        );
        insert ps;
        
        SetupEntityAccess sea = new SetupEntityAccess(
            ParentId = ps.Id,
            SetupEntityId = customPerm.Id
        );
        insert sea;
        
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = targetUser.Id,
            PermissionSetId = ps.Id
        );
        insert psa;
    }
}