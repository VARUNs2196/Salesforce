public class ContactTriggerHandler {
    public static void q13updateNumberofContacts(List<Contact> conList){
        
        Set<id> accids=New Set<id>();
        FOR(Contact con:ConList){
            if(con.AccountId != null){
                accIds.add(con.AccountId);
            }
        }
        List<AggregateResult> aggList=[SELECT Accountid,count(id) total FROM Contact WHERE Accountid IN :accids GROUP BY Accountid];
        List<Account> accList = new List<Account>();
        For(AggregateResult agg:aggList){
            Id accId = (Id)agg.get('AccountId');
            Integer totalContacts = (Integer)agg.get('total');
            Account acc = new Account(Id = accId);
            acc.Contact_Count__c = totalContacts;
            accList.add(acc);
        }
        if(!accList.isEmpty()){
            Database.SaveResult[] result = Database.update(accList, false);
            FOR(Database.saveResult res: Result){
                if(res.isSuccess()){
                    System.debug('Number of Contacts Field Updated SuccessFully');
                }
                else{
                    FOR(Database.Error err:res.getErrors()){
                        System.debug(err.getMessage());
                    }
                }
            }
        }
    }
    public static void q14updatePhone(List<Contact> conList){
        Set<Id> accid = new Set<Id>();
        for(Contact con : conList){
            if(con.AccountId != null){
                accid.add(con.AccountId);
            }
        }
        Map<Id,Account> accMap = new Map<Id,Account>(
            [SELECT Id, Phone FROM Account WHERE Id IN :accid]
        );
        for(Contact con : conList){
            if(con.AccountId != null){
                con.OtherPhone = accMap.get(con.AccountId).Phone;
            }
        }
    }
    public static void q15UpdateDescription(List<Contact> conList, Map<Id,Contact> oldMap){ 
        Map<Id,Account> accMap = new Map<Id,Account>(); 
        for(Contact con : conList){ 
            if(con.AccountId != null && con.Description != oldMap.get(con.Id).Description){
                accMap.put( con.AccountId, new Account( Id = con.AccountId, Description = con.Description ) );
            }
        }
        if(!accMap.isEmpty()){
            update accMap.values(); 
        }
    }
    public static void q18PreventCreateContact(List<Contact> conList){
        set<id>accids=New Set<id>();
        FOR(Contact con: conList){
            accids.add(con.AccountId);
        }
        Map<Id,Integer> ContactCount = new Map<Id,Integer>();
        for(AggregateResult ar : [
            SELECT AccountId, COUNT(Id) total
            FROM Contact
            WHERE AccountId IN :accIds
            GROUP BY AccountId
        ]){
            ContactCount.put(
                (Id)ar.get('AccountId'),
                (Integer)ar.get('total')
            );
        }
        for(Contact con : conList){
            if(con.AccountId != null){
                Integer count = ContactCount.containsKey(con.AccountId) ? ContactCount.get(con.AccountId): 0;
                if(count >= 2){
                    con.addError('Cannot create Contact. Account already has 2 contacts.');
                }
                else{
                    ContactCount.put(con.AccountId, count + 1);
                }
            }
        }
    }
    public static void q23ContactRelationship(List<Contact> conList){
        List<Contact_Relationship__c> relList=New List<Contact_Relationship__c>();
        FOR(Contact con:conList){
            if(con.Contact_Relationship__c==True){
                Contact_Relationship__c conRel=New Contact_Relationship__c();
                conRel.Contact__c=con.id;
                conRel.Name=con.LastName;
                relList.add(conRel);
            }
        }
        if(!relList.isEmpty()){
            insert relList;
        }
    }
    public static void q35CreateAccount(List<Contact> conList){
        List<Account> accList=New List<Account>();
        FOR(Contact con:conList){
            if(con.AccountId==NULL){
                Account acc=New Account();
                acc.Name=con.LastName;
                accList.add(acc);
            }
        }
        Database.saveResult[] res=Database.Insert(accList,False);
    }
    public static void q95UpdateContinentCount(List<Contact> conList, Map<Id,Contact> oldMap){
        Set<id> accid=New Set<id>();
        FOR(Contact con:conList){
            if(con.AccountId!=NULL){
                if(Trigger.isInsert){
                    accid.add(con.accountid);
                }
                else{
                    if(con.Continent__c!=oldMap.get(con.id).Continent__c){
                        accid.add(con.accountid);
                    }
                }
            }
        }
        Map<id,Integer> countMap=New Map<id,Integer>();
        FOR(AggregateResult agg:[SELECT Accountid accid,Count(id) total FROM Contact WHERE ACCOUNTID IN :accid AND Continent__c='Asia' GROUP BY Accountid]){
            countMap.put((id)agg.get('accid'),(Integer)agg.get('total'));
        }
        List<Account> updatedaccList=New List<Account>();
        FOR(id aid: accid){
            Account acc=New Account();
            acc.id=aid;
            acc.Contact_Count_From_Asia__c=countMap.get(acc.id);
            updatedaccList.add(acc);
        }
        if(!updatedaccList.isEmpty()){
            Database.saveResult[] res=Database.update(updatedaccList, False);
        }
        
    }
    public static void q87UpdateAccountDesc(List<Contact> conList){
        Set<id> accid=New Set<id>();
        FOR(Contact con:conList){
            accid.add(con.Accountid);
        }
        List<Account> accList=[SELECT id,Description FROM Account WHERE ID IN :accid];
        FOR(Account acc:accList){
            acc.Description='Contact Updated';
        }
        if(!accList.isEmpty()){
            Database.saveResult[] res=Database.update(accList, False);
        }
    }
    public static void q85PreventNotPrimary(List<Contact> conList){
        FOR(Contact con:conList){
            if(con.primary__c==False){
                con.AddError('Please Mark Contact As Primary');
            }
        }
    }
    public static void q82ParentContact(List<Contact> conList){
        Set<id> accid=New Set<id>();
        FOR(Contact con:conList){
            if(con.AddParentContact__c==True && con.AccountId!=NULL){
                accid.add(con.AccountId);
            }
        }
        Set<id> selectedaccid=New Set<id>();
        For(AggregateResult agg:[SELECT Accountid selaccid FROM Contact WHERE AccountID IN :accid GROUP BY Accountid HAVING count(id)=1]){
            selectedaccid.add((id)agg.get('selaccid'));
        }
        List<Account>accList=New List<Account>();
        FOR(Contact con:conList){
            if(selectedaccid.contains(con.AccountId)){
                Account acc=New Account();
                acc.id=con.AccountId;
                acc.ParentContact__c=con.id;
                accList.add(acc);
            }
        }
        if(!accList.isEmpty()){
            Database.saveResult[] res=Database.update(accList, False);
        }        
    }
    public static void q78UpdateContinentCount(List<Contact> conList){
        Account accid=[SELECT id FROM ACCOUNT WHERE NAME='Testing Accoun Trigger' LIMIT 1];
        List<Contact> conToUpdate = new List<Contact>();
        FOR(Contact con:conList){
            Contact updatecon=New Contact();
            updatecon.id=con.id;
            updatecon.AccountId=accid.id;
            conToUpdate.add(updatecon);
        }
        if(!conToUpdate.isEmpty()){
            Database.saveResult[] res=Database.update(conToUpdate, False);
        }
    }
    public static void q75PreventDuplicate(List<Contact> conList){
        Set<String> emails=New Set<String>();
        FOR(Contact con: conlist){
            if(con.Email!=NULL){
                emails.add(con.email);
            }
            
        }
        Set<String> oldemails=New Set<String>();
        FOR(Contact con:[Select email from Contact WHERE EMAIL IN :emails]){
            oldemails.add(con.email);
        }
        FOR(Contact con: conList){
            if(oldEmails.contains(con.email)){
                con.addError('Duplicate Email Found');
            }
            else{
                oldemails.add(con.email);
            }
        }
    }
    public static void q83PreventDuplicatechangeName(List<Contact> conList){
        Set<String> emails = new Set<String>();
        for (Contact con : conList) {
            if (con.Email != null) {
                emails.add(con.Email);
            }
        }
        Map<String, Id> emailMap = new Map<String, Id>();
        for (Contact con : [
            SELECT Id, Email FROM Contact WHERE Email IN :emails
        ]) {
            emailMap.put(con.Email, con.Id);
        }
        
        Set<String> oldEmails = new Set<String>(emailMap.keySet());
        List<id> updateconerr = new List<id>();
        List<Contact> updatecon = new List<Contact>();
        for (Contact con : conList) {
            if (con.Email != null && oldEmails.contains(con.Email)) {
                Contact tempcon = new Contact(
                    Id = emailMap.get(con.Email),
                    FirstName = 'New First name',
                    LastName  = 'New Last Name'
                );
                updatecon.add(tempcon);
                updateconerr.add(con.id);
            }
        }
        System.debug(updatecon);
        update updatecon;
        addDuplicateError(updateconerr);
    }
    @Future
    public static void addDuplicateError(List<id>conList){
        FOR(Contact con:[Select id FROM Contact WHERE id IN :conList]){
            
            con.addError('Duplicate Email Found');
            
        }
    }
    public static void q72Dead(List<Contact> conList, Map<Id,Contact> oldMap){
        Set<id> accids=New Set<id>();
        FOR(Contact con:ConList){
            if(con.Dead__c!=oldMap.get(con.id).Dead__c && con.AccountId!=NULL){
                accids.add(con.AccountId);
            }
        }
        Map<id,Integer> deadCount=New Map<id,Integer>();
        FOR(AggregateResult agg:[SELECT Accountid,Count(id) total FROM Contact WHERE Dead__c=True AND Accountid IN :accids GROUP BY Accountid]){
            deadCount.put((id)agg.get('Accountid'),(Integer)agg.get('total'));
        }
        Map<id,Integer> totalCount=New Map<id,Integer>();
        FOR(AggregateResult agg:[SELECT Accountid,Count(id) total FROM Contact WHERE Accountid IN :accids GROUP BY Accountid]){
            totalCount.put((id)agg.get('Accountid'),(Integer)agg.get('total'));
        }
        List<Account> accList=New List<Account>();
        FOR(Contact con:ConList){
            Decimal deadtotal=deadCount.get(con.AccountId);
            Decimal all=totalCount.get(con.AccountId);
            Account acc=New Account();
            acc.id=con.AccountId;
            if((Decimal)(deadtotal/all)>=0.7){
                
                acc.need_intel__c=True;
                accList.add(acc);
            }
            else{
                acc.need_intel__c=False;
                accList.add(acc);
            }
        }
        System.debug(accList);
        if(!accList.isEmpty()){
            update accList;
        }
    }
    public static void q69createCaseForPremiumAccount(List<Contact> newList,Map<Id, Contact> oldMap) {
        Set<Id> accIds = new Set<Id>();
        for (Contact con : newList) {
            if (con.AccountId != null) {
                if (oldMap == null || con.AccountId != oldMap.get(con.Id).AccountId) {
                    accIds.add(con.AccountId);
                }
            }
        }
        if (accIds.isEmpty()) return;
        Map<Id, Account> accMap = new Map<Id, Account>(
            [SELECT Id, Type, OwnerId FROM Account WHERE Id IN :accIds]
        );
        List<Case> caseList = new List<Case>();
        for (Contact con : newList) {
            Account acc = accMap.get(con.AccountId);
            if (acc.Type == 'Premium') {
                Case c = new Case();
                c.AccountId = acc.Id;
                c.ContactId=con.id;
                c.OwnerId   = acc.OwnerId;
                c.Origin   = 'Web';
                c.Description = con.FirstName + ' ' + con.LastName;
                caseList.add(c);
            }
        }
        System.debug(caseList);
        if (!caseList.isEmpty()) {
            insert caseList;
        }
    }
    public static void q62ContactCreated(List<Contact> conList){
        Set<id>accids=New Set<id>();
        FOR(Contact con:conList){
            if(con.Accountid!=NULL){
                accids.add(con.AccountId);
            }
        }
        List<Account> acctoUpdate=New List<Account>();
        FOR(Account acc:[SELECT id,Contact_Created__c FROM Account WHERE ID IN :accids]){
            acc.Contact_Created__c=True;
            acctoUpdate.add(acc);
        }
        if(!acctoUpdate.isEmpty()){
            update acctoUpdate;
        }
    }
    public static void q61createRelatedContact(List<Contact> conList,Map<Id, Contact> oldMap){
        Set<id> accids=New Set<id>();
        FOR(Contact con:conList){
            if(con.AccountId!=NULL){
                if(oldMap==NULL || con.Accountid!=oldMap.get(con.id).Accountid){
                    accids.add(con.AccountId);
                }
            }
        }
        List<Account> acctoupdate=New List<Account>();
        fOR(AggregateResult agg:[SELECT Accountid FROM CONTACT WHERE ACCOUNTID IN :accIds GROUP BY Accountid HAVING Count(id)>1]){
            acctoupdate.add(New Account(id=(id)agg.get('Accountid'),Only_Default_Contact__c=False));
        }
        update acctoUpdate;
    }
    public static void q51UpdateOppAmount(List<Contact> conList){
        Set<Id> accIds = new Set<Id>();
        for(Contact con : conList){
            if(con.AccountId != null){
                accIds.add(con.AccountId);
            }
        }
        Map<id,Decimal> oppcountMap=New Map<id,Decimal>();
        FOR(AggregateResult agg:[Select Accountid,SUM(Amount) totalamt FROM OPPORTUNITY WHERE Accountid IN :accIds GROUP BY Accountid]){
            oppcountMap.put((id)agg.get('Accountid'),(Decimal)agg.get('totalamt'));
        }
        List<Account>updateList=New List<Account>();
        FOR(id accid:oppcountMap.keySet()){
            updateList.add(New Account(id=accid,Total_Opportunity_Amount__c=oppcountMap.get(accid)));
        }
        if(!updateList.isEmpty()){
            update updateList;
        }
    }
    public static void q33PreventDuplicate(List<Contact> conList) {
        Set<String> primary = new Set<String>();
        
        for (Contact con : conList) {
            if (con.Email != null && con.Phone != null) {
                primary.add(con.Email + '|' + con.Phone);
            }
        }
        Set<String> existingKeys = new Set<String>();
        for (Contact con : [
            SELECT Email, Phone
            FROM Contact
            WHERE Email != null
            AND Phone != null
        ]) {
            String key = con.Email + '|' + con.Phone;
            if (primary.contains(key)) {
                existingKeys.add(key);
            }
        }
        Set<String> processedKeys = new Set<String>();
        for (Contact con : conList) {
            if (con.Email != null && con.Phone != null) {
                String key = con.Email + '|' + con.Phone;
                if (existingKeys.contains(key) || processedKeys.contains(key)) {
                    con.addError('Duplicate Contact: Email + Phone must be unique');
                } else {
                    processedKeys.add(key);
                }
            }
        }
    }
    public static void q36sendEmail(List<Contact> conList){
        EmailTemplate et = [
            SELECT Id 
            FROM EmailTemplate 
            WHERE DeveloperName = 'ContactEmail'
            LIMIT 1
        ];
        
        List<Messaging.SingleEmailMessage> emailList =
            new List<Messaging.SingleEmailMessage>();
        
        for(Contact con : conList){
            if(con.Email != null){
                
                Messaging.SingleEmailMessage mail =
                    new Messaging.SingleEmailMessage();
                
                mail.setTargetObjectId(con.Id);
                mail.setTemplateId(et.Id);
                mail.setSaveAsActivity(false);
                
                emailList.add(mail);
            }
        }
        
        if(!emailList.isEmpty()){
            Messaging.sendEmail(emailList);
        }
    }
    public static void tryingfuture(List<Contact> conList){
        List<id> upcon=New List<id>();
        FOR(contact con:conList){
            upcon.add(con.id);
        }
        futureMethod(upcon);
    }
    @Future
    public static void futureMethod(List<id> oldconList){
        List<contact> conList=New List<Contact>();
        FOR(id conid:oldconList){
            conList.add(New Contact(Email='hello@gmail.com',id=conid));
            
        }
        update conList;
    }
    public static void q13againupdateNumberofContacts(System.TriggerOperation op,List<Contact> newList,List<Contact> oldList,Map<id,Contact>oldMap){
        switch on op{
            when AFTER_INSERT,AFTER_UPDATE,AFTER_UNDELETE,AFTER_DELETE{
                Set<id> accids=New Set<id>();
                For(Contact con:op!=System.TriggerOperation.AFTER_DELETE?newList:oldList){
                    if(con.AccountId!=NULL){
                        accids.add(con.Accountid);
                    }
                    if(op == System.TriggerOperation.AFTER_UPDATE){
                        Contact oldCon = oldMap.get(con.Id);
                        if(oldCon.AccountId != null && oldCon.AccountId != con.AccountId){
                            accids.add(oldCon.AccountId);
                        }
                    }
                }
                Map<id,Account> accMap=New Map<id,Account>();
                for(Id accId : accids){
                    accMap.put(accId, new Account(
                        Id = accId,
                        Contact_Count__c = 0
                    ));
                }
                FOR(AggregateResult agg:[Select Accountid, Count(id) total FROM Contact WHERE Accountid IN :accids GROUP BY Accountid])
                {
                    accMap.put((id)agg.get('Accountid'),new Account(id=(id)agg.get('Accountid'),Contact_Count__c=(Integer)agg.get('total')));
                }
                if(!accMap.Values().isEmpty()){
                    update accMap.Values();
                }
            }
            
        }
    }
}