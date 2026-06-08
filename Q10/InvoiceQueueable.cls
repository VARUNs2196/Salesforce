public with sharing class InvoiceQueueable implements Queueable, Database.AllowsCallouts {
    private String invName;
    private Id oppId;

    public InvoiceQueueable(String invName, Id oppId) {
        this.invName = invName;
        this.oppId = oppId;
    }

    public void execute(QueueableContext context) {
        try {
            PageReference pdfPage = Page.InvoiceGenerator; 
            pdfPage.getParameters().put('id', this.oppId);
            Blob blobFile;
            if (Test.isRunningTest()) {
                blobFile = Blob.valueOf('Fake Async PDF Test Content');
            } else {
                blobFile = pdfPage.getContent();
            }
            ContentVersion cv = new ContentVersion(
                Title = this.invName,
                PathOnClient = 'Invoice_' + this.oppId + '.pdf',
                VersionData = blobFile,
                IsMajorVersion = true,
                FirstPublishLocationId = this.oppId
            );
            insert cv;
            Invoice_Notification__e event = new Invoice_Notification__e(
                Opportunity_Id__c = this.oppId,
                Status__c = 'Complete'
            );
            EventBus.publish(event);

        } catch (Exception e) {
            Invoice_Notification__e event = new Invoice_Notification__e(
                Opportunity_Id__c = this.oppId,
                Status__c = 'Failed: ' + e.getMessage()
            );
            EventBus.publish(event);
        }
    }
}