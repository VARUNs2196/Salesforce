import { LightningElement, wire } from "lwc";
import getTopOpportunities from "@salesforce/apex/KpiDashBoardController.getTopOpportunities";
import {
  subscribe,
  unsubscribe,
  MessageContext
} from "lightning/messageService";
import REGION_CHANNEL from "@salesforce/messageChannel/RegionChangeChannel__c";
import CARD_CHANNEL from "@salesforce/messageChannel/CardClickChannel__c";
export default class KpiDetailPanel extends LightningElement {
  kpiType = "";
  panelTitle = "";
  region = "None";

  opportunities = [];
  isLoading = false;
  error;
  regionSubscription = null;
  cardSubscription = null;
  @wire(MessageContext)
  messageContext;
  connectedCallback() {
    this.subscribeToMessageChannels();
  }
  disconnectedCallback() {
    this.unsubscribeFromMessageChannels();
  }

  subscribeToMessageChannels() {
    if (!this.regionSubscription) {
      this.regionSubscription = subscribe(
        this.messageContext,
        REGION_CHANNEL,
        (message) => this.handleRegionMessage(message)
      );
    }
    if (!this.cardSubscription) {
      this.cardSubscription = subscribe(
        this.messageContext,
        CARD_CHANNEL,
        (message) => this.handleCardMessage(message)
      );
    }
  }

  unsubscribeFromMessageChannels() {
    unsubscribe(this.regionSubscription);
    this.regionSubscription = null;

    unsubscribe(this.cardSubscription);
    this.cardSubscription = null;
  }
  handleRegionMessage(message) {
    console.log("Detail Panel caught Region LMS Update:", message.region);
    this.region = message.region;
  }
  handleCardMessage(message) {
    console.log("Detail Panel caught Card Click LMS Update:", message.kpiType);
    this.kpiType = message.kpiType;
    this.panelTitle = message.kpiTitle;
  }
  @wire(getTopOpportunities, { kpiType: "$kpiType", region: "$region" })
  wiredOppResults({ error, data }) {
    this.isLoading = true;

    if (data) {
      this.opportunities = data.map((opp) => ({
        ...opp,
        formattedAmount: opp.Amount ? "$" + opp.Amount.toLocaleString() : "$0"
      }));
      this.error = undefined;
      this.isLoading = false;
    } else if (error) {
      this.error = error;
      this.opportunities = [];
      this.isLoading = false;
      console.error("Error fetching detail list from LMS hook:", error);
    } else {
      this.opportunities = [];
      this.isLoading = false;
    }
  }

  get hasRecords() {
    return this.opportunities && this.opportunities.length > 0;
  }
}