public with sharing class RevenueLineTriggerHandler {
    public static Boolean isFirstRun = true;

    public static void handleRevenueLine(List<Revenue_Line__c> revenueLineList) {
        Set<Id> oppIds = new Set<Id>();
        for (Revenue_Line__c rlObj : revenueLineList) {
            if (rlObj.Opportunity__c != null) {
                oppIds.add(rlObj.Opportunity__c);
            }
        }
        Map<Id,Map<String,Object>> opprevMap = new Map<Id,Map<String,Object>>();
        if(!oppIds.isEmpty()) {
            for(AggregateResult agg : [SELECT Opportunity__c, Stage__c,SUM(Amount__c) totalAmount, MAX(Month__c) latestMonth FROM Revenue_Line__c WHERE Opportunity__c IN :oppIds GROUP BY Opportunity__c, Stage__c]) {
                Id oppId = (Id) agg.get('Opportunity__c');
                String stage = (String) agg.get('Stage__c');
                if (!opprevMap.containsKey(oppId)) {
                    opprevMap.put(oppId, new Map<String,Object>());
                }
                opprevMap.get(oppId).put(stage, agg.get('totalAmount'));
                if(stage == 'Active') {
                    opprevMap.get(oppId).put('latestMonth', agg.get('latestMonth'));
                }
            }
        }
        List<Opportunity> oppUpList = new List<Opportunity>();
        for (Id oppId : oppIds) {
            Opportunity opp = new Opportunity(Id = oppId);
            Map<String,Object> stageAmountMap = opprevMap.get(oppId);
            if (stageAmountMap == null) {
                stageAmountMap = new Map<String, Object>();
            }
            opp.Total_Revenue__c = stageAmountMap.containsKey('Active') ? (Decimal) stageAmountMap.get('Active') : 0;
            opp.Cancelled_Revenue__c = stageAmountMap.containsKey('Cancelled') ? (Decimal) stageAmountMap.get('Cancelled') : 0;
            opp.Projected_Close_Month__c = stageAmountMap.containsKey('latestMonth') ? (Date) stageAmountMap.get('latestMonth') : null;
            // if(opp.Cancelled_Revenue__c>0.20*opp.Total_Revenue__c) {
                
            // }
            oppUpList.add(opp);
        }
        if (!oppUpList.isEmpty()) {
            isFirstRun = false;
            Database.update(oppUpList, false);
            isFirstRun = true;
        }
    }
}