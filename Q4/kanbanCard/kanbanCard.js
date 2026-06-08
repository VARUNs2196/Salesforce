import { LightningElement ,api} from 'lwc';
export default class KanbanCard extends LightningElement {
    caseRecord; 
    @api
    set caseRecord(value) {
        this._caseRecord = value;
    }

    get caseRecord() {
        return this._caseRecord;
    }
}