import { LightningElement, api, wire, track } from "lwc";
import getOpportunityLineItems from "@salesforce/apex/InvoiceController.getOpportunityLineItems";
import generateInvoice from "@salesforce/apex/InvoiceController.generateInvoice";
import fetchLineItems from "@salesforce/apex/InvoiceController.getLineItems";
import { refreshApex } from "@salesforce/apex";
import { updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe } from "lightning/empApi"; 

const COLUMNS = [
  { label: "Product Name", fieldName: "Name", editable: false },
  { label: "Quantity", fieldName: "Quantity", type: "number", editable: true },
  {
    label: "Unit Price",
    fieldName: "UnitPrice",
    type: "currency",
    editable: true
  }
];

export default class InvoiceGenerator extends LightningElement {
  @api recordId;
  showTable = false;
  loaded = true;
  @track lineItems = [];
  @track oppLineItems = [];
  @track draftValues = [];

  columns = COLUMNS;
  isLoading = false;
  invoiceUrl;

  channelName = "/event/Invoice_Notification__e";
  subscription = {};

  wiredResult;
  oppWiredResult;

  connectedCallback() {
    this.handleSubscribe();
  }

  disconnectedCallback() {
    this.handleUnsubscribe();
  }

  handleSubscribe() {
    const messageCallback = (response) => {
      const eventData = response.data.payload;
      if (eventData.Opportunity_Id__c === this.recordId) {
        if (eventData.Status__c === "Complete") {
          this.invoiceUrl = `/apex/InvoiceGenerator?id=${this.recordId}&t=${new Date().getTime()}`;
          this.showToast(
            "Success",
            "Invoice generated asynchronously",
            "success"
          );
        } else {
          this.showToast("Error", eventData.Status__c, "error");
        }
        this.isLoading = false; 
      }
    };

    subscribe(this.channelName, -1, messageCallback).then((response) => {
      this.subscription = response;
    });
  }

  handleUnsubscribe() {
    unsubscribe(this.subscription, () => {
      console.log("Unsubscribed from platform event channel");
    });
  }

  handleShowTable() {
    this.showTable = !this.showTable;
  }

  @wire(fetchLineItems, { opportunityId: "$recordId" })
  wiredLineItems(result) {
    this.wiredResult = result;
    if (result.data) {
      this.lineItems = result.data.map((item) => ({
        ...item,
        InvoiceName: item.Invoice__r?.Name || "N/A"
      }));
      this.isLoading = false;
    }
  }

  @wire(getOpportunityLineItems, { opportunityId: "$recordId" })
  wiredOpps(result) {
    this.oppWiredResult = result;
    if (result.data) {
      this.oppLineItems = result.data;
    } else if (result.error) {
      this.showToast("Error", "Failed to pull opportunity products", "error");
    }
  }

  handleGenerateInvoice() {
    this.isLoading = true;
    this.invoiceUrl = null;

    generateInvoice({ opportunityId: this.recordId })
      .then((result) => {
        if (result === "ASYNC_PROCESS_STARTED") {
          this.showToast(
            "Processing",
            "Large volume detected. Processing in the background...",
            "info"
          );
        } else {
          this.invoiceUrl = `${result}&t=${new Date().getTime()}`;
          this.showToast("Success", "Invoice generated", "success");
          this.isLoading = false;
        }
      })
      .catch((err) => {
        this.showToast("Error", err.body?.message, "error");
        this.isLoading = false;
      });
  }

  async handleSave(event) {
    this.isLoading = true;
    const recordInputs = event.detail.draftValues.map((draft) => {
      return { fields: { ...draft } };
    });

    try {
      const promises = recordInputs.map((recordInput) =>
        updateRecord(recordInput)
      );
      await Promise.all(promises);

      this.showToast("Success", "Opportunity line items updated", "success");
      this.draftValues = [];
      await refreshApex(this.oppWiredResult);
    } catch (error) {
      let errorMessage = "Unknown error";
      if (error.body && typeof error.body.message === "string") {
        errorMessage = error.body.message;
      } else if (error.body && error.body.output && error.body.output.errors) {
        errorMessage = error.body.output.errors[0].message;
      }
      this.showToast("Error", errorMessage, "error");
    } finally {
      this.isLoading = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}