import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import { refreshApex } from '@salesforce/apex';
import getCasesByStatus from '@salesforce/apex/KanbanBoardController.getCasesByStatus';
import updateCaseStatus from '@salesforce/apex/KanbanBoardController.updateCaseStatus';

export default class KanbanBoard extends LightningElement {
    @track allCasesMap = { New: [], Working: [], Escalated: [], Closed: [] };
    wiredCasesResult;
    isNewLoading = false;
    isWorkingLoading = false;
    isEscalatedLoading = false;
    isClosedLoading = false;
    @wire(getCasesByStatus)
    wiredCases(result) {
        this.wiredCasesResult = result;
        if (result.data) {
            this.allCasesMap = {
                New: result.data.New || [],
                Working: result.data.Working || [],
                Escalated: result.data.Escalated || [],
                Closed: result.data.Closed || []
            };
        } else if (result.error) {
            console.error('Error fetching cases:', result.error);
        }
    }
    get newCases() { return this.allCasesMap.New; }
    get workingCases() { return this.allCasesMap.Working; }
    get escalatedCases() { return this.allCasesMap.Escalated; }
    get closedCases() { return this.allCasesMap.Closed; }
    handleCardDropped(event) {
        const { caseId, sourceStage, targetStage } = event.detail;
        if (sourceStage === targetStage) return;
        const snapshot = JSON.parse(JSON.stringify(this.allCasesMap));
        let movedCard = null;
        this.allCasesMap[sourceStage] = this.allCasesMap[sourceStage].filter(c => {
            if (c.Id === caseId) {
                movedCard = { ...c, Status: targetStage };
                return false;
            }
            return true;
        });
        if (movedCard) {
            this.allCasesMap[targetStage] = [...this.allCasesMap[targetStage], movedCard];
        }
        this.setColumnSpinner(targetStage, true);
        updateCaseStatus({ caseId: caseId, newStatus: targetStage ,oldStatus: sourceStage })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Case status updated successfully.',
                        variant: 'success'
                    })
                );
                return refreshApex(this.wiredCasesResult);
            })
            .catch(error => {
                console.error('Apex transaction failed. Reverting to snapshot.', error);
                this.allCasesMap = snapshot;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating case',
                        message: error.body ? error.body.message : 'An error occurred during save.',
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            })
            .finally(() => {
                this.setColumnSpinner(targetStage, false);
            });
    }
    setColumnSpinner(stage, isLoading) {
        if (stage === 'New') this.isNewLoading = isLoading;
        else if (stage === 'Working') this.isWorkingLoading = isLoading;
        else if (stage === 'Escalated') this.isEscalatedLoading = isLoading;
        else if (stage === 'Closed') this.isClosedLoading = isLoading;
    }
}