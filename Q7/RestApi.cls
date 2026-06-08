@RestResource(urlMapping='/v1/Opportunities/*')
global with sharing class RestApi {

    @HttpGet
    global static OpportunityWrapper doGet() {
        BaseRestApi api = new BaseRestApi();
        return api.handleGet(RestContext.request);
    }

    @HttpPost
    global static void doPost(String ProductName, Decimal UnitPrice, Integer Quantity) {
        Boolean hasAccess = FeatureManagement.checkPermission('Partner_Write_Access');
        if (!hasAccess) {
            RestResponse res = RestContext.response;
            res.statusCode = 403;
            return;
        }
        RestRequest req = RestContext.request;
        String oppId = req.requestURI.substringAfterLast('/');
        Savepoint sp = Database.setSavepoint();
        try {
            OpportunityLineItem oli = new OpportunityLineItem();
            oli.OpportunityId = oppId;
            oli.Quantity = Quantity;
            oli.UnitPrice = UnitPrice;

            Product2 prod = [SELECT Id FROM Product2 WHERE Name = :ProductName LIMIT 1];
            oli.Product2Id = prod.Id;

            insert oli;
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Transaction rolled back due to: ' + e.getMessage());
        }
    }

    @HttpDelete
    global static void doDelete() {
        Boolean hasAccess = FeatureManagement.checkPermission('Partner_Write_Access');
        if (!hasAccess) {
            RestResponse res = RestContext.response;
            res.statusCode = 403;
            System.debug('Unauthorized delete attempt');
            return;
        }
        RestRequest req = RestContext.request;
        String oppId = req.requestURI.substringAfterLast('/');
        Savepoint sp = Database.setSavepoint();
        try {
            Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :oppId LIMIT 1];
            opp.StageName = 'Closed Lost';
            update opp;
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Transaction rolled back due to: ' + e.getMessage());
        }
    }

    global class OpportunityWrapper {
        @AuraEnabled public Opportunity opp { get; set; }
        @AuraEnabled public List<OpportunityLineItem> oppLineItems { get; set; }
        @AuraEnabled public List<Opportunity> oppList { get; set; }
        @AuraEnabled public String GrossMargin { get; set; }
    }

    public virtual class BaseRestApi {
        public virtual OpportunityWrapper handleGet(RestRequest req) {
            String accountId = req.params.get('AccountId');
            String oppId = req.requestURI.substringAfterLast('/');
            Boolean hasOppId = String.isNotBlank(oppId) && !req.requestURI.endsWith('/Opportunities') && !req.requestURI.endsWith('/Opportunities/');
            
            if (String.isNotBlank(accountId)) {
                List<Opportunity> oppList = [SELECT Id, Name, StageName, CloseDate FROM Opportunity WHERE AccountId = :accountId];
                OpportunityWrapper oppWrapper = new OpportunityWrapper();
                oppWrapper.oppList = oppList;
                return oppWrapper;
            }

            if (hasOppId) {
                Opportunity opp = [
                    SELECT Id, Name, StageName, CloseDate, Amount 
                    FROM Opportunity 
                    WHERE Id = :oppId 
                    LIMIT 1
                ];

                List<OpportunityLineItem> oppLineItems = [
                    SELECT Id, OpportunityId, Product2Id, Quantity, UnitPrice 
                    FROM OpportunityLineItem 
                    WHERE OpportunityId = :oppId
                ];

                OpportunityWrapper wrapper = new OpportunityWrapper();
                wrapper.opp = opp;
                wrapper.oppLineItems = oppLineItems;
                return wrapper;
            }

            return null;
        }
    } 
}