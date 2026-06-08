import { LightningElement, api } from 'lwc';

export default class KanbanColumnClosed extends LightningElement {
    @api cases = [];
    @api isLoading = false;
    stageName = 'Closed';
    handleDragStart(event) {
        const caseId = event.target.dataset.id;
        event.dataTransfer.setData('text/plain', caseId);
        event.dataTransfer.setData('sourceStage', this.stageName);
    }
    allowDrop(event) {
        event.preventDefault();
    }
    handleDrop(event) {
        event.preventDefault();
        const caseId = event.dataTransfer.getData('text/plain');
        const sourceStage = event.dataTransfer.getData('sourceStage');
        const targetStage = event.currentTarget.dataset.stage;
        const dropEvent = new CustomEvent('carddropped', {
            detail: { caseId, sourceStage, targetStage },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(dropEvent);
        console.log(`Dropped Case ID: ${caseId} into Stage: ${targetStage}`);
    }
}