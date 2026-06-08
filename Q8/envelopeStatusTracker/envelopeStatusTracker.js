import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import retryEnvelopeProcessing from '@salesforce/apex/DocuSignRetryController.retryEnvelopeProcessing';
import getSplitDocuments from '@salesforce/apex/DocuSignRetryController.getSplitDocuments';
import { refreshApex } from '@salesforce/apex';

export default class EnvelopeStatusTracker extends LightningElement {
    @api recordId;     
    @track status = 'Waiting for Webhook...';
    @track documentCount = 0;
    @track isProcessing = false;
    @track isFailed = false;
    @track isCompleted = false;
    @track splitDocuments = [];
    
    subscription = {};
    channelName = '/event/Envelope_Processed__e';
    wiredDocumentsResult;

    @wire(getSplitDocuments, { opportunityId: '$recordId' })
    wiredDocuments(result) {
        this.wiredDocumentsResult = result;
        if (result.data) {
            this.splitDocuments = result.data.map(doc => {
                return {
                    id: doc.Id,
                    title: doc.Title,
                    downloadUrl: `/sfc/servlet.shepherd/version/download/${doc.Id}`
                };
            });
        } else if (result.error) {
            console.error('Error fetching split documents: ', result.error);
        }
    }
    connectedCallback() {
        this.handleSubscribe();
        this.registerErrorListener();
    }
    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            const eventPayload = response.data.payload;
            this.status = eventPayload.Status__c;
            this.documentCount = eventPayload.Document_Count__c || 0;
            this.isProcessing = (this.status === 'Processing' || this.status === 'Received');
            this.isFailed = (this.status === 'Failed');
            this.isCompleted = (this.status === 'Completed');

            if (this.isCompleted) {
                this.showToast('Success', 'Documents split and attached successfully!', 'success');
                refreshApex(this.wiredDocumentsResult);
            } else if (this.isFailed) {
                this.showToast('Error', 'An issue occurred during background execution.', 'error');
            }
        };
        subscribe(this.channelName, -1, messageCallback).then((response) => {
            this.subscription = response;
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, (response) => {
            console.log('Unsubscribed from streaming channel: ', response);
        });
    }

    handleRetry() {
        this.status = 'Queuing Retry...';
        this.isProcessing = true;
        this.isFailed = false;
        retryEnvelopeProcessing({ opportunityId: this.recordId })
            .then(() => {
                this.showToast('Retrying', 'Processing sequence restarted.', 'info');
            })
            .catch((error) => {
                this.status = 'Failed to Queue Retry';
                this.isProcessing = false;
                this.isFailed = true;
                this.showToast('Execution Error', error.body.message, 'error');
            });
    }

    registerErrorListener() {
        onError((error) => {
            console.error('Streaming API observed an error: ', JSON.stringify(error));
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    get bannerClass() {
        let baseClass = 'slds-scoped-notification slds-media slds-media_center ';
        if (this.isCompleted) return baseClass + 'slds-theme_success';
        if (this.isFailed) return baseClass + 'slds-theme_error';
        if (this.isProcessing) return baseClass + 'slds-theme_warning';
        return baseClass + 'slds-theme_light';
    }
}