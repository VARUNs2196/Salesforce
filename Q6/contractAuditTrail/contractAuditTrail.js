import { LightningElement, api, wire } from 'lwc';
import getauditHistory from '@salesforce/apex/ContractAuditController.getAuditHistory';

const COLUMNS = [
    { label: 'Contract ID', fieldName: 'Contract_Id__c' },
    { label: 'Field', fieldName: 'Field_Name__c' },
    { label: 'Old Value', fieldName: 'Old_Value__c' },
    { label: 'New Value', fieldName: 'New_Value__c' },
    { label: 'Changed By', fieldName: 'Changed_By__c' },
    { label: 'Changed Time', fieldName: 'Change_Time__c', type: 'date' },
    { label: 'Sensitive', fieldName: 'Sensitive__c'}
];

export default class ContractAuditTrail extends LightningElement {
    @api recordId;
    auditHistory = [];
    columns = COLUMNS;

    @wire(getauditHistory, { contractId: '$recordId' })
    wiredAuditHistory({ error, data }) {
        if (data) {
            console.log('Audit History: ' + JSON.stringify(data));
            this.auditHistory = data;
        } else if (error) {
            console.error('Error fetching audit history: ' + JSON.stringify(error));
        }
    }
}